const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializePricing } = require('../lib/serialize');

const router = express.Router();

function pricingDataFromBody(body, existing) {
  return {
    name: body.name ?? existing?.name ?? '',
    price: body.price ?? existing?.price ?? '0',
    days: body.days ?? existing?.days ?? 7,
    note: body.note ?? existing?.note ?? '',
    active: body.active ?? existing?.active ?? true,
  };
}

async function subscriberCounts() {
  const grouped = await prisma.subscriptionRecord.groupBy({
    by: ['packageName'],
    _count: { packageName: true },
  });
  const map = {};
  for (const g of grouped) map[g.packageName] = g._count.packageName;
  return map;
}

router.get(
  '/pricing',
  asyncRoute(async (req, res) => {
    const rows = await prisma.pricingPlan.findMany({ where: { active: true }, orderBy: { createdAt: 'asc' } });
    res.json(rows.map((r) => serializePricing(r, 0)));
  })
);

router.get(
  '/admin/pricing',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const [rows, counts] = await Promise.all([
      prisma.pricingPlan.findMany({ orderBy: { createdAt: 'asc' } }),
      subscriberCounts(),
    ]);
    res.json(rows.map((r) => serializePricing(r, counts[r.name] || 0)));
  })
);

router.post(
  '/admin/pricing',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    if (!req.body || !req.body.name || !req.body.name.trim()) {
      return res.status(400).json({ error: 'name is required' });
    }
    const row = await prisma.pricingPlan.create({ data: pricingDataFromBody(req.body, null) });
    if (req.body.popular) {
      await prisma.pricingPlan.updateMany({ where: { id: { not: row.id } }, data: { popular: false } });
      await prisma.pricingPlan.update({ where: { id: row.id }, data: { popular: true } });
    }
    const fresh = await prisma.pricingPlan.findUnique({ where: { id: row.id } });
    res.status(201).json(serializePricing(fresh, 0));
  })
);

router.put(
  '/admin/pricing/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.pricingPlan.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Plan not found' });
    const row = await prisma.pricingPlan.update({
      where: { id: req.params.id },
      data: pricingDataFromBody(req.body || {}, existing),
    });
    if (req.body && req.body.popular) {
      await prisma.pricingPlan.updateMany({ where: { id: { not: row.id } }, data: { popular: false } });
      await prisma.pricingPlan.update({ where: { id: row.id }, data: { popular: true } });
    }
    const counts = await subscriberCounts();
    const fresh = await prisma.pricingPlan.findUnique({ where: { id: row.id } });
    res.json(serializePricing(fresh, counts[fresh.name] || 0));
  })
);

router.patch(
  '/admin/pricing/:id/active',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.pricingPlan.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Plan not found' });
    const row = await prisma.pricingPlan.update({
      where: { id: req.params.id },
      data: { active: !existing.active },
    });
    res.json(serializePricing(row, 0));
  })
);

router.patch(
  '/admin/pricing/:id/popular',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.pricingPlan.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Plan not found' });
    await prisma.$transaction([
      prisma.pricingPlan.updateMany({ where: { id: { not: existing.id } }, data: { popular: false } }),
      prisma.pricingPlan.update({ where: { id: existing.id }, data: { popular: true } }),
    ]);
    const rows = await prisma.pricingPlan.findMany({ orderBy: { createdAt: 'asc' } });
    res.json(rows.map((r) => serializePricing(r, 0)));
  })
);

router.delete(
  '/admin/pricing/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.pricingPlan.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

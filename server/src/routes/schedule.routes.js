const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeSchedule, gradientFieldsFromBody } = require('../lib/serialize');

const router = express.Router();

function scheduleDataFromBody(body, existing) {
  return {
    dateTime: body.dateTime ? new Date(body.dateTime) : existing?.dateTime ?? new Date(),
    title: body.title ?? existing?.title ?? '',
    subtitle: body.subtitle ?? existing?.subtitle ?? '',
    channel: body.channel ?? existing?.channel ?? '',
    team1: body.team1 ?? existing?.team1 ?? '',
    team2: body.team2 ?? existing?.team2 ?? '',
    icon: body.icon ?? existing?.icon ?? 'live_tv_rounded',
    live: body.live ?? existing?.live ?? false,
    active: body.active ?? existing?.active ?? true,
    ...gradientFieldsFromBody(body, existing?.gradientStart || '1D4A82', existing?.gradientEnd || '2C6DB5'),
  };
}

router.get(
  '/schedule',
  asyncRoute(async (req, res) => {
    const rows = await prisma.scheduleItem.findMany({ where: { active: true }, orderBy: { dateTime: 'asc' } });
    res.json(rows.map(serializeSchedule));
  })
);

router.get(
  '/admin/schedule',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const rows = await prisma.scheduleItem.findMany({ orderBy: { dateTime: 'asc' } });
    res.json(rows.map(serializeSchedule));
  })
);

router.post(
  '/admin/schedule',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    if (!req.body || !req.body.title || !req.body.title.trim()) {
      return res.status(400).json({ error: 'title is required' });
    }
    const row = await prisma.scheduleItem.create({ data: scheduleDataFromBody(req.body, null) });
    res.status(201).json(serializeSchedule(row));
  })
);

router.put(
  '/admin/schedule/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.scheduleItem.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Schedule item not found' });
    const row = await prisma.scheduleItem.update({
      where: { id: req.params.id },
      data: scheduleDataFromBody(req.body || {}, existing),
    });
    res.json(serializeSchedule(row));
  })
);

router.patch(
  '/admin/schedule/:id/live',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.scheduleItem.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Schedule item not found' });
    const row = await prisma.scheduleItem.update({ where: { id: req.params.id }, data: { live: !existing.live } });
    res.json(serializeSchedule(row));
  })
);

router.patch(
  '/admin/schedule/:id/active',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.scheduleItem.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Schedule item not found' });
    const row = await prisma.scheduleItem.update({
      where: { id: req.params.id },
      data: { active: !existing.active },
    });
    res.json(serializeSchedule(row));
  })
);

router.delete(
  '/admin/schedule/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.scheduleItem.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

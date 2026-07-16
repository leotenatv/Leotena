const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeSlide, gradientFieldsFromBody } = require('../lib/serialize');

const router = express.Router();

function slideDataFromBody(body, existing) {
  return {
    title: body.title ?? existing?.title ?? '',
    imageUrl: body.imageUrl ?? existing?.imageUrl ?? '',
    active: body.active ?? existing?.active ?? true,
    ...gradientFieldsFromBody(body, existing?.gradientStart || '0F2748', existing?.gradientEnd || '19B26B'),
  };
}

router.get(
  '/carousel',
  asyncRoute(async (req, res) => {
    const rows = await prisma.carouselSlide.findMany({ where: { active: true }, orderBy: { order: 'asc' } });
    res.json(rows.map(serializeSlide));
  })
);

router.get(
  '/admin/carousel',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const rows = await prisma.carouselSlide.findMany({ orderBy: { order: 'asc' } });
    res.json(rows.map(serializeSlide));
  })
);

router.post(
  '/admin/carousel',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    if (!req.body || !req.body.title || !req.body.title.trim()) {
      return res.status(400).json({ error: 'title is required' });
    }
    const count = await prisma.carouselSlide.count();
    const row = await prisma.carouselSlide.create({
      data: { ...slideDataFromBody(req.body, null), order: count },
    });
    res.status(201).json(serializeSlide(row));
  })
);

router.put(
  '/admin/carousel/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.carouselSlide.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Slide not found' });
    const row = await prisma.carouselSlide.update({
      where: { id: req.params.id },
      data: slideDataFromBody(req.body || {}, existing),
    });
    res.json(serializeSlide(row));
  })
);

router.patch(
  '/admin/carousel/:id/active',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.carouselSlide.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Slide not found' });
    const row = await prisma.carouselSlide.update({
      where: { id: req.params.id },
      data: { active: !existing.active },
    });
    res.json(serializeSlide(row));
  })
);

router.patch(
  '/admin/carousel/reorder',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { orderedIds } = req.body || {};
    if (!Array.isArray(orderedIds) || orderedIds.length === 0) {
      return res.status(400).json({ error: 'orderedIds must be a non-empty array' });
    }
    await prisma.$transaction(
      orderedIds.map((id, index) => prisma.carouselSlide.update({ where: { id }, data: { order: index } }))
    );
    const rows = await prisma.carouselSlide.findMany({ orderBy: { order: 'asc' } });
    res.json(rows.map(serializeSlide));
  })
);

router.delete(
  '/admin/carousel/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.carouselSlide.delete({ where: { id: req.params.id } });
    const remaining = await prisma.carouselSlide.findMany({ orderBy: { order: 'asc' } });
    await prisma.$transaction(
      remaining.map((row, index) => prisma.carouselSlide.update({ where: { id: row.id }, data: { order: index } }))
    );
    res.status(204).end();
  })
);

module.exports = router;

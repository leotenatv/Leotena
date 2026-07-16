const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeChannel, gradientFieldsFromBody } = require('../lib/serialize');

const router = express.Router();

const DRM_VALUES = ['NONE', 'WIDEVINE', 'CLEARKEY'];

function channelDataFromBody(body, existing) {
  const drm = DRM_VALUES.includes(body.drm) ? body.drm : existing ? existing.drm : 'NONE';
  return {
    name: body.name ?? existing?.name ?? '',
    category: body.category ?? existing?.category ?? 'football',
    url: body.url ?? existing?.url ?? '',
    drm,
    clearKey: drm === 'CLEARKEY' ? body.clearKey ?? existing?.clearKey ?? '' : '',
    premium: body.premium ?? existing?.premium ?? true,
    viewers: body.viewers ?? existing?.viewers ?? 0,
    live: body.live ?? existing?.live ?? false,
    active: body.active ?? existing?.active ?? true,
    imageUrl: body.imageUrl ?? existing?.imageUrl ?? '',
    ...gradientFieldsFromBody(body, existing?.gradientStart || '1D4A82', existing?.gradientEnd || '2C6DB5'),
    genre: body.genre ?? existing?.genre ?? null,
    year: body.year ?? existing?.year ?? null,
    rating: body.rating ?? existing?.rating ?? null,
    duration: body.duration ?? existing?.duration ?? null,
    resolution: body.resolution ?? existing?.resolution ?? null,
    language: body.language ?? existing?.language ?? null,
    director: body.director ?? existing?.director ?? null,
    description: body.description ?? existing?.description ?? null,
    genres: Array.isArray(body.genres) ? body.genres : existing?.genres ?? [],
  };
}

// Public: active channels, optional ?category= filter.
router.get(
  '/channels',
  asyncRoute(async (req, res) => {
    const where = { active: true };
    if (req.query.category) where.category = req.query.category;
    const rows = await prisma.channel.findMany({ where, orderBy: { sortOrder: 'asc' } });
    res.json(rows.map(serializeChannel));
  })
);

// Admin: full list (active + inactive).
router.get(
  '/admin/channels',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const rows = await prisma.channel.findMany({ orderBy: { sortOrder: 'asc' } });
    res.json(rows.map(serializeChannel));
  })
);

router.post(
  '/admin/channels',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    if (!req.body || !req.body.name || !req.body.name.trim()) {
      return res.status(400).json({ error: 'name is required' });
    }
    const count = await prisma.channel.count();
    const row = await prisma.channel.create({
      data: { ...channelDataFromBody(req.body, null), sortOrder: count },
    });
    res.status(201).json(serializeChannel(row));
  })
);

router.put(
  '/admin/channels/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.channel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Channel not found' });
    const row = await prisma.channel.update({
      where: { id: req.params.id },
      data: channelDataFromBody(req.body || {}, existing),
    });
    res.json(serializeChannel(row));
  })
);

router.patch(
  '/admin/channels/:id/live',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.channel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Channel not found' });
    const row = await prisma.channel.update({ where: { id: req.params.id }, data: { live: !existing.live } });
    res.json(serializeChannel(row));
  })
);

router.patch(
  '/admin/channels/:id/premium',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.channel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Channel not found' });
    const row = await prisma.channel.update({ where: { id: req.params.id }, data: { premium: !existing.premium } });
    res.json(serializeChannel(row));
  })
);

router.patch(
  '/admin/channels/:id/active',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.channel.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Channel not found' });
    const row = await prisma.channel.update({ where: { id: req.params.id }, data: { active: !existing.active } });
    res.json(serializeChannel(row));
  })
);

router.patch(
  '/admin/channels/reorder',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { orderedIds } = req.body || {};
    if (!Array.isArray(orderedIds) || orderedIds.length === 0) {
      return res.status(400).json({ error: 'orderedIds must be a non-empty array' });
    }
    await prisma.$transaction(
      orderedIds.map((id, index) => prisma.channel.update({ where: { id }, data: { sortOrder: index } }))
    );
    const rows = await prisma.channel.findMany({ orderBy: { sortOrder: 'asc' } });
    res.json(rows.map(serializeChannel));
  })
);

router.delete(
  '/admin/channels/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.channel.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

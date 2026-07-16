const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeSubscription } = require('../lib/serialize');

const router = express.Router();

router.get(
  '/admin/subscriptions',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const rows = await prisma.subscriptionRecord.findMany({ orderBy: { createdAt: 'desc' } });
    res.json(rows.map(serializeSubscription));
  })
);

router.delete(
  '/admin/subscriptions/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.subscriptionRecord.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

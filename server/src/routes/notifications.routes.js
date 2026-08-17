const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeNotificationLog } = require('../lib/serialize');
const { broadcastPush } = require('../lib/push');

const router = express.Router();

router.get(
  '/admin/notifications',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const rows = await prisma.notificationLog.findMany({ orderBy: { createdAt: 'desc' } });
    res.json(rows.map(serializeNotificationLog));
  })
);

router.post(
  '/admin/notifications/send',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { title, body } = req.body || {};
    if (!title || !title.trim() || !body || !body.trim()) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    const result = await broadcastPush({
      title: title.trim(),
      body: body.trim(),
      target: 'all',
      source: 'leotena',
    });
    res.status(201).json(serializeNotificationLog(result.log));
  })
);

router.delete(
  '/admin/notifications/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.notificationLog.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

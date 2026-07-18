const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { messaging } = require('../lib/firebase');
const { serializeNotificationLog } = require('../lib/serialize');

const router = express.Router();

// FCM's multicast send accepts at most 500 tokens per call.
function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

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

    const devices = await prisma.device.findMany({
      where: { fcmToken: { not: null } },
      select: { id: true, fcmToken: true },
    });

    let successCount = 0;
    let failureCount = 0;
    const deadTokenDeviceIds = [];

    if (devices.length > 0) {
      const batches = chunk(devices, 500);
      for (const batch of batches) {
        const response = await messaging().sendEachForMulticast({
          tokens: batch.map((d) => d.fcmToken),
          notification: { title: title.trim(), body: body.trim() },
        });
        successCount += response.successCount;
        failureCount += response.failureCount;
        response.responses.forEach((r, i) => {
          if (!r.success && r.error && r.error.code === 'messaging/registration-token-not-registered') {
            deadTokenDeviceIds.push(batch[i].id);
          }
        });
      }
    }

    if (deadTokenDeviceIds.length > 0) {
      await prisma.device.updateMany({
        where: { id: { in: deadTokenDeviceIds } },
        data: { fcmToken: null },
      });
    }

    const log = await prisma.notificationLog.create({
      data: { title: title.trim(), body: body.trim(), successCount, failureCount },
    });
    res.status(201).json(serializeNotificationLog(log));
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

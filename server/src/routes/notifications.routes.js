const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { messaging } = require('../lib/firebase');
const { serializeNotificationLog } = require('../lib/serialize');

const router = express.Router();

/** Must match the Android channel created in the Flutter app. */
const ANDROID_ALERT_CHANNEL = 'leotena_alerts';

/** FCM errors that mean the token can never receive again — clear it. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

// FCM's multicast send accepts at most 500 tokens per call.
function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

/** Unique tokens only — duplicate FCM tokens waste quota and inflate failures. */
function uniqueTokenDevices(devices) {
  const seen = new Set();
  const out = [];
  for (const d of devices) {
    const token = (d.fcmToken || '').trim();
    if (!token || seen.has(token)) continue;
    seen.add(token);
    out.push({ id: d.id, fcmToken: token });
  }
  return out;
}

function buildMulticastMessage(tokens, title, body) {
  return {
    tokens,
    notification: { title, body },
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_ALERT_CHANNEL,
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
        priority: 'high',
        visibility: 'public',
      },
    },
    apns: {
      headers: { 'apns-priority': '10' },
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'content-available': 0,
        },
      },
    },
  };
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

    const trimmedTitle = title.trim();
    const trimmedBody = body.trim();

    // All active devices that can receive pushes.
    const devices = await prisma.device.findMany({
      where: {
        active: true,
        fcmToken: { not: null },
      },
      select: { id: true, fcmToken: true },
    });

    const targets = uniqueTokenDevices(devices);

    let successCount = 0;
    let failureCount = 0;
    const deadTokenDeviceIds = [];

    if (targets.length > 0) {
      const batches = chunk(targets, 500);
      for (const batch of batches) {
        const response = await messaging().sendEachForMulticast(
          buildMulticastMessage(
            batch.map((d) => d.fcmToken),
            trimmedTitle,
            trimmedBody
          )
        );
        successCount += response.successCount;
        failureCount += response.failureCount;
        response.responses.forEach((r, i) => {
          if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) {
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
      data: {
        title: trimmedTitle,
        body: trimmedBody,
        successCount,
        failureCount,
      },
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

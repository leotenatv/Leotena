const prisma = require('../db');
const { messaging } = require('./firebase');
const { hasPremiumAccess } = require('./serialize');

/** Must match the Android channel created in the Flutter app. */
const ANDROID_ALERT_CHANNEL = 'leotena_alerts';

/** FCM errors that mean the token can never receive again — clear it. */
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

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

function normalizeTarget(target) {
  const t = String(target || 'all').trim().toLowerCase();
  if (t === 'premium') return 'premium';
  if (t === 'free') return 'free';
  return 'all';
}

function matchesAudience(device, target) {
  if (target === 'all') return true;
  const premium = hasPremiumAccess(device);
  if (target === 'premium') return premium;
  if (target === 'free') return !premium;
  return true;
}

function buildMulticastMessage(tokens, title, body, source) {
  const data = {
    title: String(title),
    body: String(body),
    message: String(body),
    source: String(source || 'leotena'),
    click_action: 'FLUTTER_NOTIFICATION_CLICK',
  };
  return {
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: {
        channelId: ANDROID_ALERT_CHANNEL,
        sound: 'default',
        defaultSound: true,
        defaultVibrateTimings: true,
        priority: 'high',
        visibility: 'public',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
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

/**
 * Send a high-priority FCM notification to active Leotena devices.
 * @param {{ title: string, body: string, target?: string, source?: string }} input
 */
async function broadcastPush(input) {
  const title = String(input.title || '').trim();
  const body = String(input.body || '').trim();
  const target = normalizeTarget(input.target);
  const source = String(input.source || 'leotena').trim() || 'leotena';
  if (!title || !body) {
    const err = new Error('title and body are required');
    err.status = 400;
    throw err;
  }

  const devices = await prisma.device.findMany({
    where: {
      active: true,
      fcmToken: { not: null },
    },
    select: { id: true, fcmToken: true, plan: true, premiumUntil: true },
  });

  const targets = uniqueTokenDevices(devices.filter((d) => matchesAudience(d, target)));

  let successCount = 0;
  let failureCount = 0;
  const deadTokenDeviceIds = [];

  if (targets.length > 0) {
    const batches = chunk(targets, 500);
    for (const batch of batches) {
      const response = await messaging().sendEachForMulticast(
        buildMulticastMessage(
          batch.map((d) => d.fcmToken),
          title,
          body,
          source
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
      title,
      body,
      successCount,
      failureCount,
    },
  });

  return { log, successCount, failureCount, target };
}

module.exports = {
  ANDROID_ALERT_CHANNEL,
  broadcastPush,
  normalizeTarget,
};

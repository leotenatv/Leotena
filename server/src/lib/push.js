const prisma = require('../db');
const { messaging } = require('./firebase');
const { hasPremiumAccess } = require('./serialize');

/** Must match the Android channel created in the Flutter app. */
const ANDROID_ALERT_CHANNEL = 'leotena_alerts';

/** Leotena-only topics — never reuse shared-project `all_users`. */
const TOPIC_ALL = 'leotena_all_users';
const TOPIC_PREMIUM = 'leotena_premium_users';
const TOPIC_FREE = 'leotena_free_users';

const FCM_TTL_MS = 28 * 24 * 60 * 60 * 1000;

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

function topicForTarget(target) {
  const t = normalizeTarget(target);
  if (t === 'premium') return TOPIC_PREMIUM;
  if (t === 'free') return TOPIC_FREE;
  return TOPIC_ALL;
}

function matchesAudience(device, target) {
  if (target === 'all') return true;
  const premium = hasPremiumAccess(device);
  if (target === 'premium') return premium;
  if (target === 'free') return !premium;
  return true;
}

function androidConfig() {
  return {
    priority: 'high',
    ttl: FCM_TTL_MS,
    notification: {
      channelId: ANDROID_ALERT_CHANNEL,
      clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      sound: 'default',
      defaultSound: true,
      defaultVibrateTimings: true,
      priority: 'high',
      visibility: 'public',
    },
  };
}

function dataPayload(title, body, source, target) {
  return {
    title: String(title),
    body: String(body),
    message: String(body),
    source: String(source || 'leotena'),
    target: String(target || 'all'),
    kind: 'broadcast',
    scope: 'broadcast',
  };
}

function buildMulticastMessage(tokens, title, body, source, target) {
  return {
    tokens,
    notification: { title, body },
    data: dataPayload(title, body, source, target),
    android: androidConfig(),
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

async function sendToTopic(title, body, target, source) {
  const topic = topicForTarget(target);
  const messageId = await messaging().send({
    topic,
    notification: { title, body },
    data: dataPayload(title, body, source, target),
    android: androidConfig(),
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
  });
  return { topic, messageId };
}

/**
 * Send a high-priority FCM notification to Leotena devices.
 * Topics reach every subscribed install even if no token is stored.
 * Token multicast covers older installs that never subscribed to topics.
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

  let topic = topicForTarget(target);
  let messageId = null;
  try {
    const sent = await sendToTopic(title, body, target, source);
    topic = sent.topic;
    messageId = sent.messageId;
  } catch (err) {
    console.error('[push] topic send failed:', err && err.message ? err.message : err);
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
    try {
      const batches = chunk(targets, 500);
      for (const batch of batches) {
        const response = await messaging().sendEachForMulticast(
          buildMulticastMessage(
            batch.map((d) => d.fcmToken),
            title,
            body,
            source,
            target
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
    } catch (err) {
      console.error('[push] token multicast failed:', err && err.message ? err.message : err);
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

  return {
    log,
    successCount,
    failureCount,
    target,
    topic,
    messageId,
    delivered: Boolean(messageId) || successCount > 0,
  };
}

module.exports = {
  ANDROID_ALERT_CHANNEL,
  TOPIC_ALL,
  TOPIC_PREMIUM,
  TOPIC_FREE,
  broadcastPush,
  normalizeTarget,
  topicForTarget,
};

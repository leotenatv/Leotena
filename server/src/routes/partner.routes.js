const crypto = require('crypto');
const express = require('express');
const { asyncRoute } = require('../middleware/errorHandler');
const { broadcastPush, normalizeTarget, TOPIC_ALL, TOPIC_PREMIUM, TOPIC_FREE } = require('../lib/push');
const { fcmReady } = require('../lib/firebase');

const router = express.Router();

function secretsEqual(provided, expected) {
  if (!expected) return false;
  const a = Buffer.from(String(provided || ''), 'utf8');
  const b = Buffer.from(String(expected), 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function partnerSecret() {
  return (process.env.SUPA_LEOTENA_BRIDGE_SECRET || process.env.LEOTENA_BRIDGE_SECRET || '').trim();
}

function verifyPartnerSecret(req, res, next) {
  const expected = partnerSecret();
  if (!expected) {
    return res.status(503).json({
      ok: false,
      error: 'Push partner is not configured. Set SUPA_LEOTENA_BRIDGE_SECRET.',
    });
  }
  const provided = (req.get('X-Partner-Secret') || '').trim();
  if (!secretsEqual(provided, expected)) {
    return res.status(401).json({ ok: false, error: 'Unauthorized partner' });
  }
  return next();
}

const EXPIRED_REMINDER_MARKERS = [
  'kifurushi chako kimeisha',
  'kifurushi chako kimeisha muda wake',
  'mpendwa mteja, kifurushi chako kimeisha',
];

function isExpiredPaymentReminder(title, message) {
  const haystack = `${title} ${message}`.toLowerCase();
  return EXPIRED_REMINDER_MARKERS.some((m) => haystack.includes(m));
}

/**
 * Mounted at /api/partner (same contract as JamboPlus / EaMax).
 * POST /api/partner/supa-push
 * Header: X-Partner-Secret
 */
router.get('/supa-push/health', verifyPartnerSecret, (_req, res) => {
  res.json({
    ok: true,
    fcm: fcmReady(),
    service: 'leotena-partner',
    accepts: ['broadcast'],
    topics: [TOPIC_ALL, TOPIC_PREMIUM, TOPIC_FREE],
  });
});

router.post(
  '/supa-push',
  verifyPartnerSecret,
  asyncRoute(async (req, res) => {
    const b = req.body || {};
    const title = String(b.title || '').trim();
    const message = String(b.message || b.body || '').trim();
    const scope = String(b.scope || 'broadcast').trim().toLowerCase() || 'broadcast';
    const kind = String(b.kind || b.type || (scope === 'user' ? 'reminder' : 'broadcast'))
      .trim()
      .toLowerCase();
    const target = normalizeTarget(b.target);

    if (!title || !message) {
      return res.status(400).json({ ok: false, error: 'title and message required' });
    }

    if (scope !== 'broadcast') {
      return res.json({
        ok: true,
        skipped: true,
        delivered: false,
        scope,
        reason: 'user_scope_not_mirrored',
      });
    }
    if (kind === 'reminder' || kind === 'payment_reminder' || kind === 'expired_reminder') {
      return res.json({
        ok: true,
        skipped: true,
        delivered: false,
        scope,
        kind,
        reason: 'reminder_not_mirrored',
      });
    }
    if (isExpiredPaymentReminder(title, message)) {
      return res.json({
        ok: true,
        skipped: true,
        delivered: false,
        scope,
        reason: 'expired_reminder_not_mirrored',
      });
    }

    if (!fcmReady()) {
      return res.status(503).json({
        ok: false,
        error: 'Push is not configured on Leotena. Set FIREBASE_* env vars.',
      });
    }

    const result = await broadcastPush({
      title,
      body: message,
      target,
      source: 'supasoka',
    });
    res.json({
      ok: true,
      scope: 'broadcast',
      target,
      topic: result.topic,
      delivered: result.delivered,
      messageId: result.messageId || result.log.id,
      successCount: result.successCount,
      failureCount: result.failureCount,
    });
  })
);

module.exports = router;
module.exports.secretsEqual = secretsEqual;

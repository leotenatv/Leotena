const crypto = require('crypto');
const express = require('express');
const { asyncRoute } = require('../middleware/errorHandler');
const { broadcastPush, normalizeTarget } = require('../lib/push');

const router = express.Router();

function secretsEqual(provided, expected) {
  if (!expected) return false;
  const a = Buffer.from(String(provided || ''), 'utf8');
  const b = Buffer.from(String(expected), 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

/**
 * SupaAdmin (Supasoka) mirrors broadcasts here. Same contract as EaMax/JamboPlus:
 * POST /api/partner/supa-push
 * Header: X-Partner-Secret
 * Body: { title, message, scope, target, kind, externalId? }
 */
router.post(
  '/api/partner/supa-push',
  asyncRoute(async (req, res) => {
    const expected = (
      process.env.SUPA_LEOTENA_BRIDGE_SECRET ||
      process.env.LEOTENA_BRIDGE_SECRET ||
      ''
    ).trim();
    if (!expected) {
      return res.status(503).json({
        error: 'Push partner is not configured. Set SUPA_LEOTENA_BRIDGE_SECRET.',
      });
    }
    const provided = (req.get('X-Partner-Secret') || '').trim();
    if (!secretsEqual(provided, expected)) {
      return res.status(401).json({ error: 'Unauthorized partner' });
    }

    const b = req.body || {};
    const title = String(b.title || '').trim();
    const message = String(b.message || b.body || '').trim();
    const scope = String(b.scope || 'broadcast').trim().toLowerCase() || 'broadcast';
    const kind = String(b.kind || (scope === 'user' ? 'reminder' : 'broadcast'))
      .trim()
      .toLowerCase();
    const target = normalizeTarget(b.target);

    // User/expired reminders use Supasoka public IDs and must never fan out
    // to every Leotena device.
    if (scope === 'user' || kind === 'reminder') {
      return res.json({
        ok: true,
        scope,
        delivered: false,
        reason: scope === 'user' ? 'user_scope_not_mirrored' : 'reminder_not_mirrored',
      });
    }

    if (!title || !message) {
      return res.status(400).json({ error: 'title and body are required' });
    }

    try {
      const result = await broadcastPush({
        title,
        body: message,
        target,
        source: 'supasoka',
      });
      res.json({
        ok: true,
        scope: 'broadcast',
        delivered: result.successCount > 0,
        messageId: result.log.id,
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    } catch (err) {
      const msg = err && err.message ? String(err.message) : 'Push send failed';
      if (/FIREBASE_|FCM credentials|must be set/i.test(msg)) {
        return res.status(503).json({ error: 'Push is not configured on Leotena. Set FIREBASE_* env vars.' });
      }
      throw err;
    }
  })
);

module.exports = router;
module.exports.secretsEqual = secretsEqual;

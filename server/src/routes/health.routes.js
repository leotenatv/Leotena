const express = require('express');

const { fcmReady } = require('../lib/firebase');

const router = express.Router();

router.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    commit: process.env.RAILWAY_GIT_COMMIT_SHA || null,
  });
});

router.get('/health/push', (_req, res) => {
  const secret = Boolean(
    (process.env.SUPA_LEOTENA_BRIDGE_SECRET || process.env.LEOTENA_BRIDGE_SECRET || '').trim()
  );
  const firebase = Boolean(
    (process.env.FIREBASE_PROJECT_ID || process.env.FCM_PROJECT_ID || '').trim() &&
      (process.env.FIREBASE_CLIENT_EMAIL || process.env.FCM_CLIENT_EMAIL || '').trim() &&
      (process.env.FIREBASE_PRIVATE_KEY || process.env.FCM_PRIVATE_KEY || '').trim()
  );
  res.json({
    status: 'ok',
    partnerSecret: secret,
    firebase,
    fcm: firebase ? fcmReady() : false,
    partnerPath: '/api/partner/supa-push',
    commit: process.env.RAILWAY_GIT_COMMIT_SHA || null,
  });
});

module.exports = router;

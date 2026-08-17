const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeSettings, DEFAULT_PLAY_STORE_URL } = require('../lib/serialize');

const router = express.Router();

async function getOrCreateSettings() {
  return prisma.setting.upsert({
    where: { id: 'singleton' },
    update: {},
    create: { id: 'singleton' },
  });
}

function asBool(v, fallback) {
  if (v === true || v === 'true' || v === 1 || v === '1') return true;
  if (v === false || v === 'false' || v === 0 || v === '0') return false;
  return fallback;
}

router.get(
  '/settings',
  asyncRoute(async (req, res) => {
    const settings = await getOrCreateSettings();
    res.json(serializeSettings(settings));
  })
);

router.put(
  '/admin/settings',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const b = req.body || {};
    const existing = await getOrCreateSettings();

    const supportWhatsApp = String(b.supportWhatsApp ?? existing.supportWhatsApp ?? '').trim();
    if (!supportWhatsApp) {
      return res.status(400).json({ error: 'supportWhatsApp is required' });
    }

    const forceUpdateEnabled = asBool(b.forceUpdateEnabled, existing.forceUpdateEnabled);
    const minCodeVersion = Number.isFinite(Number(b.minCodeVersion))
      ? Math.max(0, Math.floor(Number(b.minCodeVersion)))
      : existing.minCodeVersion;
    const minAppVersion = b.minAppVersion != null ? String(b.minAppVersion).trim() : existing.minAppVersion;
    if (forceUpdateEnabled && minCodeVersion <= 0 && !minAppVersion) {
      return res.status(400).json({
        error: 'Weka code version au app version kabla ya kuwasha lazima ku update.',
      });
    }

    const playStoreUrl = String(b.playStoreUrl ?? existing.playStoreUrl ?? '')
      .trim() || DEFAULT_PLAY_STORE_URL;

    const settings = await prisma.setting.update({
      where: { id: 'singleton' },
      data: {
        supportWhatsApp,
        maintenanceMode: asBool(b.maintenanceMode, existing.maintenanceMode),
        maintenanceMessage:
          b.maintenanceMessage != null ? String(b.maintenanceMessage).trim() : existing.maintenanceMessage,
        forceUpdateEnabled,
        minCodeVersion,
        minAppVersion,
        forceUpdateMessage:
          b.forceUpdateMessage != null ? String(b.forceUpdateMessage).trim() : existing.forceUpdateMessage,
        playStoreUrl,
      },
    });
    res.json(serializeSettings(settings));
  })
);

module.exports = router;

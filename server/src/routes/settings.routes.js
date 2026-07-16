const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');

const router = express.Router();

async function getOrCreateSettings() {
  return prisma.setting.upsert({
    where: { id: 'singleton' },
    update: {},
    create: { id: 'singleton' },
  });
}

router.get(
  '/settings',
  asyncRoute(async (req, res) => {
    const settings = await getOrCreateSettings();
    res.json({ supportWhatsApp: settings.supportWhatsApp });
  })
);

router.put(
  '/admin/settings',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { supportWhatsApp } = req.body || {};
    if (!supportWhatsApp || !supportWhatsApp.trim()) {
      return res.status(400).json({ error: 'supportWhatsApp is required' });
    }
    const settings = await prisma.setting.upsert({
      where: { id: 'singleton' },
      update: { supportWhatsApp: supportWhatsApp.trim() },
      create: { id: 'singleton', supportWhatsApp: supportWhatsApp.trim() },
    });
    res.json({ supportWhatsApp: settings.supportWhatsApp });
  })
);

module.exports = router;

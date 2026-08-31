const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');
const { serializeDevice } = require('../lib/serialize');
const { reconcileDevicePremium } = require('../lib/premiumPayment');

const router = express.Router();

function withTimeout(promise, ms) {
  return Promise.race([promise, new Promise((resolve) => setTimeout(() => resolve(null), ms))]);
}

const UNIT_MS = {
  minutes: 60 * 1000,
  hours: 60 * 60 * 1000,
  days: 24 * 60 * 60 * 1000,
  weeks: 7 * 24 * 60 * 60 * 1000,
};

const UNIT_LABEL_SW = {
  minutes: 'Dakika',
  hours: 'Saa',
  days: 'Siku',
  weeks: 'Wiki',
};

// Public: idempotent upsert by client-generated deviceId. Called on app boot.
router.post(
  '/devices/register',
  asyncRoute(async (req, res) => {
    const { deviceId, name, phone } = req.body || {};
    if (!deviceId || !deviceId.trim()) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    const row = await prisma.device.upsert({
      where: { deviceId: deviceId.trim() },
      update: {
        ...(name != null && String(name).trim() ? { name: String(name).trim() } : {}),
        ...(phone != null && String(phone).trim() ? { phone: String(phone).trim() } : {}),
      },
      create: { deviceId: deviceId.trim(), name: name || '', phone: phone || '' },
    });
    await withTimeout(reconcileDevicePremium(row.deviceId), 10000);
    const fresh = await prisma.device.findUnique({ where: { id: row.id } });
    res.json(serializeDevice(fresh || row));
  })
);

router.get(
  '/devices/:deviceId',
  asyncRoute(async (req, res) => {
    await withTimeout(reconcileDevicePremium(req.params.deviceId), 10000);
    const row = await prisma.device.findUnique({ where: { deviceId: req.params.deviceId } });
    if (!row) return res.status(404).json({ error: 'Device not found' });
    res.json(serializeDevice(row));
  })
);

router.put(
  '/devices/:deviceId/profile',
  asyncRoute(async (req, res) => {
    const { name, phone } = req.body || {};
    const row = await prisma.device.update({
      where: { deviceId: req.params.deviceId },
      data: { name: name ?? undefined, phone: phone ?? undefined },
    });
    res.json(serializeDevice(row));
  })
);

// Public: called after the app obtains/refreshes its FCM registration token.
router.put(
  '/devices/:deviceId/fcm-token',
  asyncRoute(async (req, res) => {
    const { fcmToken } = req.body || {};
    if (!fcmToken || !fcmToken.trim()) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }
    const row = await prisma.device.update({
      where: { deviceId: req.params.deviceId },
      data: { fcmToken: fcmToken.trim() },
    });
    res.json(serializeDevice(row));
  })
);

// Admin: manage devices/users.
router.get(
  '/admin/devices',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const q = (req.query.query || '').toLowerCase();
    const rows = await prisma.device.findMany({ orderBy: { createdAt: 'desc' } });
    const filtered = q
      ? rows.filter(
          (d) =>
            d.name.toLowerCase().includes(q) || d.phone.toLowerCase().includes(q) || d.deviceId.toLowerCase().includes(q)
        )
      : rows;
    res.json(filtered.map(serializeDevice));
  })
);

router.post(
  '/admin/devices',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { deviceId, name, phone } = req.body || {};
    if (!deviceId || !deviceId.trim()) {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    const row = await prisma.device.create({
      data: { deviceId: deviceId.trim(), name: name || '', phone: phone || '' },
    });
    res.status(201).json(serializeDevice(row));
  })
);

router.put(
  '/admin/devices/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.device.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Device not found' });
    const { name, phone, active } = req.body || {};
    const row = await prisma.device.update({
      where: { id: req.params.id },
      data: {
        name: name ?? existing.name,
        phone: phone ?? existing.phone,
        active: active ?? existing.active,
      },
    });
    res.json(serializeDevice(row));
  })
);

router.patch(
  '/admin/devices/:id/active',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.device.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Device not found' });
    const row = await prisma.device.update({ where: { id: req.params.id }, data: { active: !existing.active } });
    res.json(serializeDevice(row));
  })
);

router.post(
  '/admin/devices/:id/grant-premium',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const { amount, unit } = req.body || {};
    const n = Number(amount);
    if (!n || n <= 0 || !UNIT_MS[unit]) {
      return res.status(400).json({ error: 'amount (>0) and a valid unit are required' });
    }
    const existing = await prisma.device.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Device not found' });

    const now = Date.now();
    const base =
      existing.premiumUntil && new Date(existing.premiumUntil).getTime() > now
        ? new Date(existing.premiumUntil).getTime()
        : now;
    const premiumUntil = new Date(base + n * UNIT_MS[unit]);

    const [device] = await prisma.$transaction([
      prisma.device.update({ where: { id: existing.id }, data: { plan: 'PREMIUM', premiumUntil } }),
      prisma.subscriptionRecord.create({
        data: {
          deviceRecordId: existing.id,
          userName: existing.name || existing.deviceId,
          packageName: `Manual: ${n} ${UNIT_LABEL_SW[unit]}`,
          amount: 'Manual',
          success: true,
        },
      }),
    ]);
    res.json(serializeDevice(device));
  })
);

router.post(
  '/admin/devices/:id/revoke-premium',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const existing = await prisma.device.findUnique({ where: { id: req.params.id } });
    if (!existing) return res.status(404).json({ error: 'Device not found' });
    const row = await prisma.device.update({
      where: { id: req.params.id },
      data: { plan: 'FREE', premiumUntil: null },
    });
    res.json(serializeDevice(row));
  })
);

router.delete(
  '/admin/devices/:id',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    await prisma.device.delete({ where: { id: req.params.id } });
    res.status(204).end();
  })
);

module.exports = router;

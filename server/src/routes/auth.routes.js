const express = require('express');
const prisma = require('../db');
const { comparePassword } = require('../lib/password');
const { signAdminToken } = require('../lib/jwt');
const { asyncRoute } = require('../middleware/errorHandler');
const requireAdminAuth = require('../middleware/requireAdminAuth');

const router = express.Router();

router.post(
  '/auth/login',
  asyncRoute(async (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required' });
    }

    const admin = await prisma.adminUser.findUnique({ where: { email: email.toLowerCase().trim() } });
    if (!admin) return res.status(401).json({ error: 'Invalid credentials' });

    const ok = await comparePassword(password, admin.passwordHash);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    const token = signAdminToken(admin);
    res.json({ token, admin: { id: admin.id, email: admin.email } });
  })
);

router.get(
  '/auth/me',
  requireAdminAuth,
  asyncRoute(async (req, res) => {
    const admin = await prisma.adminUser.findUnique({ where: { id: req.admin.sub } });
    if (!admin) return res.status(401).json({ error: 'Invalid session' });
    res.json({ id: admin.id, email: admin.email });
  })
);

module.exports = router;

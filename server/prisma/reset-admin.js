// Sync AdminUser from ADMIN_EMAIL / ADMIN_PASSWORD env vars.
// Safe to re-run anytime (does not touch content tables).
require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function main() {
  const email = (process.env.ADMIN_EMAIL || 'admin@leotena.com').toLowerCase().trim();
  const password = process.env.ADMIN_PASSWORD || 'admin123';
  if (!password) {
    throw new Error('ADMIN_PASSWORD is empty');
  }

  const passwordHash = await bcrypt.hash(password, 10);

  await prisma.adminUser.upsert({
    where: { email },
    update: { passwordHash },
    create: { email, passwordHash },
  });

  // Drop any other admin rows so a previous email can't still log in.
  const removed = await prisma.adminUser.deleteMany({
    where: { email: { not: email } },
  });

  console.log(`Admin ready: ${email} (removed ${removed.count} other admin(s))`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

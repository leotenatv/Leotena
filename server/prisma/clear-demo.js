// Wipe seeded demo content so admin starts from real data only.
// Keeps AdminUser + Setting. Safe to re-run.
require('dotenv').config();

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const subs = await prisma.subscriptionRecord.deleteMany();
  const devices = await prisma.device.deleteMany();
  const schedule = await prisma.scheduleItem.deleteMany();
  const slides = await prisma.carouselSlide.deleteMany();
  const channels = await prisma.channel.deleteMany();
  const plans = await prisma.pricingPlan.deleteMany();

  console.log(
    `Cleared demo data: ${channels.count} channels, ${schedule.count} schedule, ` +
      `${slides.count} slides, ${plans.count} plans, ${devices.count} devices, ${subs.count} subscriptions`
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

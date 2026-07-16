// One-time migration of the existing mock/admin dummy data into real rows.
// Safe to run once against a fresh database (see README "Phase A" gate).
require('dotenv').config();

const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

function aiImage(prompt, seed, width = 960, height = 540) {
  return `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}?width=${width}&height=${height}&nologo=true&seed=${seed}`;
}

// 16 channels transcribed verbatim from leoadmin/lib/data/admin_repository.dart.
const CHANNELS = [
  {
    name: 'Leotena TV', category: 'burudani',
    url: 'https://stream.leotena.com/live/leotena-tv/index.m3u8',
    premium: true, viewers: 8420, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/cinematic%20African%20evening%20news%20TV%20studio?width=960&height=540&nologo=true&seed=101',
    gradientStart: '1D4A82', gradientEnd: '2C6DB5',
  },
  {
    name: 'Pwani Sports', category: 'football',
    url: 'https://stream.leotena.com/live/pwani-sports/index.mpd',
    drm: 'WIDEVINE',
    premium: true, viewers: 23100, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20football%20stadium%20night%20match?width=960&height=540&nologo=true&seed=102',
    gradientStart: '0A7D4A', gradientEnd: '19B26B',
  },
  {
    name: 'Bongo Movies', category: 'movies',
    url: 'https://stream.leotena.com/live/bongo-movies/index.m3u8',
    premium: true, viewers: 15600, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20cinema%20movie%20premiere?width=960&height=540&nologo=true&seed=103',
    gradientStart: '0F2748', gradientEnd: '3A86C9',
  },
  {
    name: 'Drama One', category: 'tamthilia',
    url: 'https://stream.leotena.com/live/drama-one/index.mpd',
    drm: 'CLEARKEY', clearKey: '9eb4050deb18485bbba2e9358c988e39:6dc75f6d1d3e4cf7a1eeaf4e15e6c1a3',
    premium: true, viewers: 9200, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20drama%20television%20series?width=960&height=540&nologo=true&seed=104',
    gradientStart: '143A6B', gradientEnd: '1D4A82',
  },
  {
    name: 'Nyota Kids', category: 'katuni',
    url: 'https://stream.leotena.com/live/nyota-kids/index.m3u8',
    premium: true, viewers: 3800, live: false, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/colorful%20kids%20cartoon%20TV%20channel?width=960&height=540&nologo=true&seed=105',
    gradientStart: '2C6DB5', gradientEnd: '7FC6F0',
  },
  {
    name: 'Anga Sports 2', category: 'football',
    url: 'https://stream.leotena.com/live/anga-sports-2/index.m3u8',
    premium: true, viewers: 11400, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/champions%20league%20football%20night?width=960&height=540&nologo=true&seed=106',
    gradientStart: '19B26B', gradientEnd: '0A7D4A',
  },
  {
    name: 'Wildlife HD', category: 'wanyama',
    url: 'https://stream.leotena.com/live/wildlife-hd/index.m3u8',
    premium: true, viewers: 6400, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/african%20wildlife%20documentary%20lions?width=960&height=540&nologo=true&seed=107',
    gradientStart: '0B5B45', gradientEnd: '34A872',
  },
  {
    name: 'Comedy Plus', category: 'burudani',
    url: 'https://stream.leotena.com/live/comedy-plus/index.m3u8',
    premium: true, viewers: 5100, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/african%20comedy%20stage%20show%20night?width=960&height=540&nologo=true&seed=108',
    gradientStart: '5B2A86', gradientEnd: '9B59B6',
  },
  {
    name: 'Kivuli cha Mwisho', category: 'movies',
    url: 'https://stream.leotena.com/vod/kivuli-cha-mwisho/index.m3u8',
    premium: true, viewers: 145200, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20cinema%20action%20movie%20poster?width=960&height=540&nologo=true&seed=201',
    gradientStart: '0F2748', gradientEnd: '19B26B',
  },
  {
    name: 'Jiji la Dhahabu', category: 'movies',
    url: 'https://stream.leotena.com/vod/jiji-la-dhahabu/index.m3u8',
    premium: false, viewers: 98700, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20drama%20movie%20poster%20golden%20city?width=960&height=540&nologo=true&seed=202',
    gradientStart: '143A6B', gradientEnd: '3A86C9',
  },
  {
    name: 'Pwani ya Giza', category: 'movies',
    url: 'https://stream.leotena.com/vod/pwani-ya-giza/index.mpd',
    drm: 'WIDEVINE',
    premium: true, viewers: 87300, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20thriller%20movie%20poster%20dark%20coast?width=960&height=540&nologo=true&seed=203',
    gradientStart: '0A1C36', gradientEnd: '1D4A82',
  },
  {
    name: 'Safari ya Nyota', category: 'katuni',
    url: 'https://stream.leotena.com/vod/safari-ya-nyota/index.m3u8',
    premium: false, viewers: 65400, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/colorful%20kids%20cartoon%20movie%20poster%20stars?width=960&height=540&nologo=true&seed=204',
    gradientStart: '2C6DB5', gradientEnd: '7FC6F0',
  },
  {
    name: 'Moto wa Usiku', category: 'movies',
    url: 'https://stream.leotena.com/vod/moto-wa-usiku/index.m3u8',
    premium: true, viewers: 76800, live: false, active: false,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20suspense%20movie%20poster%20night%20fire?width=960&height=540&nologo=true&seed=205',
    gradientStart: '5B2A86', gradientEnd: '9B59B6',
  },
  {
    name: 'Mbingu na Ardhi', category: 'movies',
    url: 'https://stream.leotena.com/vod/mbingu-na-ardhi/index.m3u8',
    premium: false, viewers: 42100, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20drama%20movie%20poster%20sky%20and%20earth?width=960&height=540&nologo=true&seed=206',
    gradientStart: '143A6B', gradientEnd: '1D4A82',
  },
  {
    name: 'Simba wa Serengeti', category: 'wanyama',
    url: 'https://stream.leotena.com/vod/simba-wa-serengeti/index.m3u8',
    premium: true, viewers: 112400, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/lion%20documentary%20movie%20poster%20serengeti?width=960&height=540&nologo=true&seed=207',
    gradientStart: '0B5B45', gradientEnd: '34A872',
  },
  {
    name: 'Ndoto za Mjini', category: 'burudani',
    url: 'https://stream.leotena.com/vod/ndoto-za-mjini/index.m3u8',
    premium: false, viewers: 38900, live: true, active: true,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20comedy%20movie%20poster%20city%20dreams?width=960&height=540&nologo=true&seed=208',
    gradientStart: '5B2A86', gradientEnd: '9B59B6',
  },
];

// VOD metadata patched onto the 8 name-matching rows above (from
// leotena/lib/data/mock_repository.dart's Movie list). Category is left
// untouched — admin stays the source of truth for it.
const MOVIE_METADATA = {
  'Kivuli cha Mwisho': {
    genre: 'Vitendo', year: '2026', rating: '8.9', duration: '2h 14m', resolution: '4K', language: 'Kiswahili',
    director: 'N. Mwakalinga', genres: ['Vitendo', 'Msisimko', 'Uhalifu'],
    description: 'Afisa wa zamani wa usalama anarudi mjini kufuatilia siri iliyozikwa kwa miaka mingi, lakini kila hatua inamfichua zaidi kwa hatari isiyotarajiwa.',
  },
  'Jiji la Dhahabu': {
    genre: 'Drama', year: '2025', rating: '8.4', duration: '1h 58m', resolution: 'HD', language: 'Kiswahili',
    director: 'A. Salehe', genres: ['Drama', 'Familia'],
    description: 'Familia moja inapambana kulinda urithi wao katikati ya jiji linalokua kwa kasi na tamaa za biashara.',
  },
  'Pwani ya Giza': {
    genre: 'Maandishi', year: '2026', rating: '9.1', duration: '1h 42m', resolution: '4K', language: 'Kiswahili',
    director: 'J. Komba', genres: ['Maandishi', 'Asili'],
    description: 'Safari ya kuvutia kando ya pwani ya Afrika Mashariki ikifichua maajabu ya bahari na maisha ya wavuvi.',
  },
  'Safari ya Nyota': {
    genre: 'Watoto', year: '2025', rating: '8.0', duration: '1h 30m', resolution: 'HD', language: 'Kiswahili',
    director: 'R. Mushi', genres: ['Watoto', 'Hadithi'],
    description: 'Watoto wawili wanagundua ramani ya ajabu inayowapeleka kwenye safari ya kichawi miongoni mwa nyota.',
  },
  'Moto wa Usiku': {
    genre: 'Msisimko', year: '2026', rating: '8.7', duration: '2h 05m', resolution: '4K', language: 'Kiswahili',
    director: 'F. Mbwana', genres: ['Msisimko', 'Uhalifu'],
    description: 'Mpelelezi mahiri anafuatilia mtandao wa uhalifu unaojificha nyuma ya taa za jiji wakati wa usiku.',
  },
  'Mbingu na Ardhi': {
    genre: 'Drama', year: '2024', rating: '7.9', duration: '2h 20m', resolution: 'HD', language: 'Kiswahili',
    director: 'L. Kessy', genres: ['Drama', 'Mapenzi'],
    description: 'Hadithi ya mapenzi inayovuka tabaka na tamaduni katika kijiji cha milimani.',
  },
  'Simba wa Serengeti': {
    genre: 'Maandishi', year: '2025', rating: '9.3', duration: '1h 15m', resolution: '4K', language: 'Kiswahili',
    director: 'Asili Studios', genres: ['Maandishi', 'Wanyama'],
    description: 'Maisha ya kundi la simba katika tambarare za Serengeti yakinaswa kwa picha za kuvutia.',
  },
  'Ndoto za Mjini': {
    genre: 'Vichekesho', year: '2026', rating: '7.6', duration: '1h 48m', resolution: 'HD', language: 'Kiswahili',
    director: 'P. Nyerere', genres: ['Vichekesho', 'Drama'],
    description: 'Kijana kutoka kijijini anafika mjini akiwa na ndoto kubwa lakini ukweli wa maisha ni tofauti.',
  },
};

// 6 channel names that exist only in leotena/lib/data/mock_repository.dart.
const MOCK_ONLY_CHANNELS = [
  {
    name: 'Serengeti Live', category: 'wanyama', gradientStart: '1A5C3A', gradientEnd: '4CAF78',
    imageUrl: aiImage('serengeti sunrise wildlife, elephants and giraffes, nature documentary channel, cinematic', 109),
  },
  {
    name: 'Ngoro Ngoro', category: 'wanyama', gradientStart: '0F4A38', gradientEnd: '2E8B57',
    imageUrl: aiImage('ngorongoro crater wildlife, zebras wildebeest herd, african nature TV broadcast cinematic', 110),
  },
  {
    name: 'Bahari Blue', category: 'wanyama', gradientStart: '0A4A6B', gradientEnd: '2A8FBF',
    imageUrl: aiImage('underwater ocean wildlife documentary, colorful fish coral reef, cinematic nature broadcast', 111),
  },
  {
    name: 'Katuni Fun', category: 'katuni', gradientStart: 'E67E22', gradientEnd: 'F39C12',
    imageUrl: aiImage('bright kids cartoon characters adventure, colorful animated TV show, playful sunny style', 112),
  },
  {
    name: 'Ulimwengu Kids', category: 'katuni', gradientStart: '8E44AD', gradientEnd: '3498DB',
    imageUrl: aiImage('cute animated animal friends cartoon, rainbow sky playground, kids TV channel poster style', 113),
  },
  {
    name: 'Jua Animation', category: 'katuni', gradientStart: '2980B9', gradientEnd: '1ABC9C',
    imageUrl: aiImage('magical kids space adventure cartoon, stars rockets colorful animation, TV channel art', 114),
  },
];

// dateTime numbers are Tanzania (EAT) wall-clock values used as-is (Z is a
// label, not a real UTC conversion — matches leoadmin's tzIsoString()
// convention). Date.UTC() is required here: the plain `new Date(y,m,d,h,min)`
// constructor applies the *running machine's* local timezone, which would
// silently shift these hours if the seed script ever runs somewhere that
// isn't UTC+0.
const SCHEDULE = [
  {
    dateTime: new Date(Date.UTC(2026, 6, 16, 10, 0)), title: 'Katuni za Asubuhi', subtitle: 'Vipindi vya watoto',
    channel: 'Nyota Kids', icon: 'child_care_rounded', live: false,
    gradientStart: '2C6DB5', gradientEnd: '7FC6F0',
  },
  {
    dateTime: new Date(Date.UTC(2026, 6, 16, 13, 0)), title: 'Simba vs Yanga', subtitle: 'Ligi Kuu',
    channel: 'Pwani Sports', team1: 'Simba', team2: 'Yanga', icon: 'sports_soccer_rounded', live: true,
    gradientStart: '0A7D4A', gradientEnd: '19B26B',
  },
  {
    dateTime: new Date(Date.UTC(2026, 6, 16, 16, 0)), title: 'Kivuli cha Mwisho', subtitle: 'Filamu',
    channel: 'Bongo Movies', icon: 'movie_outlined', live: false,
    gradientStart: '0F2748', gradientEnd: '3A86C9',
  },
  {
    dateTime: new Date(Date.UTC(2026, 6, 16, 20, 0)), title: 'Habari za Jioni', subtitle: '',
    channel: 'Leotena TV', icon: 'newspaper_rounded', live: true,
    gradientStart: '1D4A82', gradientEnd: '2C6DB5',
  },
  {
    dateTime: new Date(Date.UTC(2026, 6, 17, 22, 0)), title: 'Pwani ya Giza', subtitle: 'Filamu',
    channel: 'Bongo Movies', icon: 'waves_rounded', live: false,
    gradientStart: '0A1C36', gradientEnd: '1D4A82',
  },
];

const CAROUSEL = [
  {
    title: 'Kivuli cha Mwisho', order: 0,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20cinema%20action%20movie%20poster?width=960&height=540&nologo=true&seed=201',
    gradientStart: '0F2748', gradientEnd: '19B26B',
  },
  {
    title: 'Jiji la Dhahabu', order: 1,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20drama%20movie%20poster%20golden%20city?width=960&height=540&nologo=true&seed=202',
    gradientStart: '143A6B', gradientEnd: '3A86C9',
  },
  {
    title: 'Pwani ya Giza', order: 2,
    imageUrl: 'https://image.pollinations.ai/prompt/African%20thriller%20movie%20poster%20dark%20coast?width=960&height=540&nologo=true&seed=203',
    gradientStart: '0A1C36', gradientEnd: '1D4A82',
  },
];

const PRICING = [
  { name: 'Wiki 1', price: '2,000', days: 7, note: 'Ufikiaji kamili kwa siku 7', popular: false },
  { name: 'Mwezi 1', price: '5,000', days: 30, note: 'Bora zaidi kwa mwezi mzima', popular: true },
  { name: 'Miezi 3 na Wiki 2', price: '12,000', days: 104, note: 'Okoa zaidi — siku 104', popular: false },
];

const DEVICES = [
  { key: 'u1', name: 'Amani Joseph', phone: '0712345678', deviceId: 'LT-4A7F-9C2E', plan: 'PREMIUM', active: true, premiumUntil: null },
  { key: 'u2', name: 'Neema Hassan', phone: '0755123456', deviceId: 'LT-8B2C-1D4F', plan: 'FREE', active: true, premiumUntil: null },
  { key: 'u3', name: 'Juma Mkumbo', phone: '0788123456', deviceId: 'LT-3E9A-7F1B', plan: 'PREMIUM', active: true, premiumUntil: null },
  { key: 'u4', name: 'Fatma Saidi', phone: '0622123456', deviceId: 'LT-5C6D-2E8A', plan: 'FREE', active: false, premiumUntil: null },
  { key: 'u5', name: 'Peter Mwangi', phone: '0744123456', deviceId: 'LT-1F2G-9H3J', plan: 'PREMIUM', active: true, premiumUntil: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000) },
  { key: 'u6', name: 'Grace Kimaro', phone: '0766123456', deviceId: 'LT-6K7L-4M5N', plan: 'FREE', active: true, premiumUntil: null },
];

const SUBSCRIPTIONS = [
  { deviceKey: 'u1', userName: 'Amani Joseph', packageName: 'Mwezi 1', amount: 'TZS 5,000', success: true, createdAt: new Date(Date.UTC(2026, 5, 28)) },
  { deviceKey: 'u5', userName: 'Peter Mwangi', packageName: 'Wiki 1', amount: 'TZS 2,000', success: true, createdAt: new Date(Date.UTC(2026, 5, 28)) },
  { deviceKey: 'u2', userName: 'Neema Hassan', packageName: 'Mwezi 1', amount: 'TZS 5,000', success: false, createdAt: new Date(Date.UTC(2026, 5, 27)) },
  { deviceKey: 'u3', userName: 'Juma Mkumbo', packageName: 'Miezi 3 na Wiki 2', amount: 'TZS 12,000', success: true, createdAt: new Date(Date.UTC(2026, 5, 27)) },
  { deviceKey: 'u6', userName: 'Grace Kimaro', packageName: 'Wiki 1', amount: 'TZS 2,000', success: true, createdAt: new Date(Date.UTC(2026, 5, 26)) },
];

async function main() {
  await prisma.setting.upsert({
    where: { id: 'singleton' },
    update: {},
    create: { id: 'singleton', supportWhatsApp: '255712345678' },
  });

  const adminEmail = (process.env.ADMIN_EMAIL || 'admin@leotena.com').toLowerCase().trim();
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
  const passwordHash = await bcrypt.hash(adminPassword, 10);
  await prisma.adminUser.upsert({
    where: { email: adminEmail },
    update: { passwordHash },
    create: { email: adminEmail, passwordHash },
  });

  for (let i = 0; i < CHANNELS.length; i++) {
    const c = CHANNELS[i];
    const meta = MOVIE_METADATA[c.name] || {};
    await prisma.channel.create({ data: { ...c, sortOrder: i, ...meta } });
  }
  for (let i = 0; i < MOCK_ONLY_CHANNELS.length; i++) {
    await prisma.channel.create({ data: { ...MOCK_ONLY_CHANNELS[i], sortOrder: CHANNELS.length + i, premium: true, viewers: 0, live: true, active: true } });
  }

  for (const s of SCHEDULE) {
    await prisma.scheduleItem.create({ data: s });
  }

  for (const s of CAROUSEL) {
    await prisma.carouselSlide.create({ data: s });
  }

  const createdPlans = [];
  for (const p of PRICING) {
    createdPlans.push(await prisma.pricingPlan.create({ data: p }));
  }

  const deviceByKey = {};
  for (const d of DEVICES) {
    const row = await prisma.device.create({
      data: {
        deviceId: d.deviceId,
        name: d.name,
        phone: d.phone,
        plan: d.plan,
        active: d.active,
        premiumUntil: d.premiumUntil,
      },
    });
    deviceByKey[d.key] = row;
  }

  for (const s of SUBSCRIPTIONS) {
    await prisma.subscriptionRecord.create({
      data: {
        deviceRecordId: deviceByKey[s.deviceKey].id,
        userName: s.userName,
        packageName: s.packageName,
        amount: s.amount,
        success: s.success,
        createdAt: s.createdAt,
      },
    });
  }

  console.log(`Seeded: ${CHANNELS.length + MOCK_ONLY_CHANNELS.length} channels, ${SCHEDULE.length} schedule items, ${CAROUSEL.length} carousel slides, ${createdPlans.length} pricing plans, ${DEVICES.length} devices, ${SUBSCRIPTIONS.length} subscriptions.`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

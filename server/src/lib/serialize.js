// Wire-format helpers. Every model with gradientStart/gradientEnd columns
// serializes as gradient: ["1D4A82", "2C6DB5"] — a 1:1 mirror of Dart's
// `List<Color> gradient` fields on both Flutter clients.

function gradientOf(row) {
  return [row.gradientStart, row.gradientEnd];
}

function gradientFieldsFromBody(body, fallbackStart, fallbackEnd) {
  const g = Array.isArray(body.gradient) ? body.gradient : null;
  return {
    gradientStart: (g && g[0]) || fallbackStart,
    gradientEnd: (g && g[1]) || fallbackEnd,
  };
}

function serializeChannel(row) {
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    url: row.url,
    drm: row.drm,
    clearKey: row.clearKey,
    premium: row.premium,
    viewers: row.viewers,
    live: row.live,
    active: row.active,
    imageUrl: row.imageUrl,
    gradient: gradientOf(row),
    sortOrder: row.sortOrder,
    genre: row.genre,
    year: row.year,
    rating: row.rating,
    duration: row.duration,
    resolution: row.resolution,
    language: row.language,
    director: row.director,
    description: row.description,
    genres: row.genres,
  };
}

function serializeSchedule(row) {
  return {
    id: row.id,
    dateTime: row.dateTime.toISOString(),
    title: row.title,
    subtitle: row.subtitle,
    channel: row.channel,
    team1: row.team1,
    team2: row.team2,
    icon: row.icon,
    live: row.live,
    active: row.active,
    gradient: gradientOf(row),
  };
}

function serializeSlide(row) {
  return {
    id: row.id,
    title: row.title,
    imageUrl: row.imageUrl,
    order: row.order,
    active: row.active,
    gradient: gradientOf(row),
  };
}

function serializePricing(row, subscribers = 0) {
  return {
    id: row.id,
    name: row.name,
    price: row.price,
    days: row.days,
    note: row.note,
    popular: row.popular,
    active: row.active,
    subscribers,
  };
}

function hasPremiumAccess(device) {
  if (device.premiumUntil) return new Date(device.premiumUntil).getTime() > Date.now();
  return device.plan === 'PREMIUM';
}

function serializeDevice(row) {
  return {
    id: row.id,
    deviceId: row.deviceId,
    name: row.name,
    phone: row.phone,
    plan: row.plan,
    active: row.active,
    premiumUntil: row.premiumUntil ? row.premiumUntil.toISOString() : null,
    hasPremiumAccess: hasPremiumAccess(row),
    createdAt: row.createdAt.toISOString(),
  };
}

function serializeSubscription(row) {
  return {
    id: row.id,
    deviceRecordId: row.deviceRecordId,
    user: row.userName,
    packageName: row.packageName,
    amount: row.amount,
    success: row.success,
    date: row.createdAt.toISOString(),
  };
}

module.exports = {
  gradientOf,
  gradientFieldsFromBody,
  serializeChannel,
  serializeSchedule,
  serializeSlide,
  serializePricing,
  serializeDevice,
  serializeSubscription,
  hasPremiumAccess,
};

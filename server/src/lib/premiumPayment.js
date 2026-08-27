const prisma = require('../db');
const {
  sonicpesaConfigured,
  normalizeTzPhone,
  toLocalTzPhone,
  normalizePaymentStatus,
  isSonicpesaSuccess,
  isSonicpesaFailure,
  isSonicpesaRateLimited,
  sonicpesaOrderStatus,
} = require('./sonicpesa');
const { hasPremiumAccess } = require('./serialize');

/** USSD push windows are short; abandoned rows must leave the poll queue. */
const PENDING_ACTIVE_MS = 45 * 60 * 1000;
/** Still try to settle paid-but-stuck rows for this long before hard-expire. */
const PENDING_REPAIR_MS = 14 * 24 * 60 * 60 * 1000;
const SWEEP_BATCH = 8;
const SWEEP_GAP_MS = 500;

async function withDbRetry(fn, attempts = 3, delayMs = 400) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      lastErr = e;
      if (i < attempts - 1) {
        await new Promise((resolve) => setTimeout(resolve, delayMs * (i + 1)));
      }
    }
  }
  throw lastErr;
}

function parseAmountTzs(price) {
  const n = Number(String(price ?? '').replace(/[^\d]/g, ''));
  return Number.isFinite(n) ? n : 0;
}

/**
 * Upsert a pending SonicPesa payment row after create_order succeeds.
 * Ensures the Device row exists so webhook/status can grant premium later.
 */
async function upsertPendingSonicpesaTransaction(input) {
  const deviceId = input.deviceId.trim();
  const userName = (input.userName || '').trim() || 'Mtumiaji';
  const phone = (input.phone || '').trim();
  const orderId = input.orderId.trim();

  await prisma.device.upsert({
    where: { deviceId },
    update: {
      name: userName,
      phone: phone || undefined,
    },
    create: {
      deviceId,
      name: userName,
      phone: phone || '',
    },
  });

  return prisma.paymentTransaction.upsert({
    where: { orderId },
    update: {
      deviceId,
      userName,
      phone,
      planId: input.planId,
      planName: input.planName || '',
      amount: input.amount,
      method: input.method || 'Mobile Money',
      status: 'pending',
      metadata: input.metadata || undefined,
    },
    create: {
      orderId,
      deviceId,
      userName,
      phone,
      planId: input.planId,
      planName: input.planName || '',
      amount: input.amount,
      method: input.method || 'Mobile Money',
      status: 'pending',
      metadata: input.metadata || undefined,
    },
  });
}

/**
 * True when a completed payment never produced an active premium window.
 * Do NOT re-extend after a legitimate expiry: a proper grant sets
 * premiumUntil = completedAt + duration, so completedAt < premiumUntil
 * always holds even after the window ends.
 */
function needsPremiumRepair(existingTx, device) {
  if (!existingTx || existingTx.status !== 'completed') return false;
  if (!device?.premiumUntil) return true;
  const until = new Date(device.premiumUntil).getTime();
  if (until > Date.now()) return false;
  const completedAt = existingTx.updatedAt || existingTx.createdAt;
  if (!completedAt) return false;
  return new Date(completedAt).getTime() >= until;
}

/**
 * Grant/extend premium on Device + mark payment completed + write SubscriptionRecord.
 * Idempotent on orderId (provider_ref). Repairs completed rows that never applied premium.
 */
async function grantPremiumFromPayment(input) {
  const deviceId = input.deviceId.trim();
  const orderId = input.providerRef.trim();
  const amount = Number(input.amount);
  if (!deviceId || !orderId || !(amount >= 0) || Number.isNaN(amount)) {
    throw new Error('device_id, provider_ref and non-negative amount are required');
  }

  const existingTx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
  const devicePreview = await prisma.device.findUnique({ where: { deviceId } });
  if (existingTx?.status === 'completed' && !needsPremiumRepair(existingTx, devicePreview)) {
    return {
      ok: true,
      premium_until: devicePreview?.premiumUntil ? devicePreview.premiumUntil.toISOString() : null,
      already_completed: true,
    };
  }
  const repairing = existingTx?.status === 'completed';

  const plan = await prisma.pricingPlan.findUnique({ where: { id: input.planId || existingTx?.planId || '' } });
  const meta =
    existingTx?.metadata && typeof existingTx.metadata === 'object' && !Array.isArray(existingTx.metadata)
      ? existingTx.metadata
      : {};
  const metaDays = Number(meta.planDays);
  const durationDays = plan?.days || (Number.isFinite(metaDays) && metaDays > 0 ? metaDays : 0) || 30;
  const planName = plan?.name || existingTx?.planName || input.planName || 'Premium';
  const userName = (input.userName || existingTx?.userName || '').trim() || 'Mtumiaji';
  const phone = (input.phone || existingTx?.phone || '').trim();
  const method = (input.method || existingTx?.method || 'Mobile Money').trim();

  const result = await prisma.$transaction(async (tx) => {
    const device = await tx.device.upsert({
      where: { deviceId },
      update: {
        name: userName,
        phone: phone || undefined,
      },
      create: {
        deviceId,
        name: userName,
        phone: phone || '',
      },
    });

    const now = Date.now();
    const base =
      device.premiumUntil && new Date(device.premiumUntil).getTime() > now
        ? new Date(device.premiumUntil).getTime()
        : now;
    const premiumUntil = new Date(base + durationDays * 24 * 60 * 60 * 1000);

    const updated = await tx.device.update({
      where: { id: device.id },
      data: { plan: 'PREMIUM', premiumUntil },
    });

    await tx.paymentTransaction.upsert({
      where: { orderId },
      update: {
        status: 'completed',
        userName,
        phone,
        method,
        metadata: input.metadata || undefined,
      },
      create: {
        orderId,
        deviceId,
        userName,
        phone,
        planId: input.planId || existingTx?.planId || '',
        planName,
        amount,
        method,
        status: 'completed',
        metadata: input.metadata || undefined,
      },
    });

    if (!repairing) {
      await tx.subscriptionRecord.create({
        data: {
          deviceRecordId: device.id,
          userName,
          packageName: planName,
          amount: `TZS ${amount.toLocaleString('en-US')}`,
          success: true,
        },
      });
    }

    return updated;
  });

  return {
    ok: true,
    premium_until: result.premiumUntil ? result.premiumUntil.toISOString() : null,
  };
}

async function markPaymentFailed(orderId, metadata) {
  await prisma.paymentTransaction.updateMany({
    where: { orderId, status: { not: 'completed' } },
    data: {
      status: 'failed',
      metadata: metadata || undefined,
    },
  });
}

/**
 * Local / zero-amount premium grant (no SonicPesa). Used when Sonic is not
 * configured or ALLOW_LOCAL_PAYMENTS=true. Records amount as 0.
 */
async function completeLocalZeroPayment(input) {
  const deviceId = String(input.deviceId || '').trim();
  const planId = String(input.planId || '').trim();
  const userName = String(input.userName || '').trim() || 'Mtumiaji';
  const phone = String(input.phone || '').trim();
  if (!deviceId || !planId) throw new Error('deviceId and planId are required');

  const plan = await prisma.pricingPlan.findUnique({ where: { id: planId } });
  if (!plan) {
    const err = new Error('plan not found');
    err.status = 404;
    throw err;
  }
  if (!plan.active) {
    const err = new Error('plan is not available');
    err.status = 400;
    throw err;
  }

  const orderId = `local-${deviceId.slice(0, 24)}-${Date.now()}`;
  await upsertPendingSonicpesaTransaction({
    deviceId,
    userName,
    phone,
    amount: 0,
    planId: plan.id,
    planName: plan.name,
    orderId,
    method: 'Local',
    metadata: { source: 'local-zero', planDays: plan.days },
  });

  const granted = await grantPremiumFromPayment({
    deviceId,
    userName,
    phone,
    amount: 0,
    method: 'Local',
    planId: plan.id,
    planName: plan.name,
    providerRef: orderId,
    metadata: { source: 'local-zero', planDays: plan.days },
  });

  const device = await prisma.device.findUnique({ where: { deviceId } });
  return {
    orderId,
    amount: 0,
    planId: plan.id,
    planName: plan.name,
    premium_until: granted.premium_until,
    device,
  };
}

function localPaymentsAllowed() {
  // Explicit opt-in only. Never auto-complete checkout just because Sonic keys are missing —
  // Lipia sasa must send a real USSD push and wait for PIN success.
  const flag = String(process.env.ALLOW_LOCAL_PAYMENTS || '')
    .trim()
    .toLowerCase();
  return flag === '1' || flag === 'true' || flag === 'yes';
}

async function findDeviceIdByPhone(phoneRaw) {
  const local = toLocalTzPhone(phoneRaw);
  const intl = normalizeTzPhone(phoneRaw);
  const candidates = [local, intl, local ? local.slice(1) : null].filter(Boolean);
  if (!candidates.length) return null;
  const row = await prisma.device.findFirst({
    where: { phone: { in: candidates } },
    orderBy: { updatedAt: 'desc' },
  });
  return row?.deviceId?.trim() || null;
}

async function resolvePlanByAmount(amount) {
  const amt = Math.round(Number(amount));
  if (!(amt > 0)) return null;
  const plans = await prisma.pricingPlan.findMany();
  const scored = plans
    .map((p) => ({ p, price: parseAmountTzs(p.price), diff: Math.abs(parseAmountTzs(p.price) - amt) }))
    .filter((x) => x.price > 0);
  const exact = scored.find((x) => x.price === amt);
  if (exact) return exact.p;
  const near = scored.filter((x) => x.diff <= 100).sort((a, b) => a.diff - b.diff || (b.p.active ? 1 : 0) - (a.p.active ? 1 : 0));
  return near[0]?.p ?? null;
}

async function grantFromTx(tx, source) {
  return grantPremiumFromPayment({
    deviceId: tx.deviceId,
    userName: tx.userName || 'Mtumiaji',
    phone: tx.phone || '',
    amount: Number(tx.amount),
    method: tx.method || 'Mobile Money',
    planId: tx.planId,
    planName: tx.planName,
    providerRef: tx.orderId,
    metadata: { source, sonicpesa_status: tx.status },
  });
}

/**
 * Settle one pending row against SonicPesa.
 * @returns {{ granted?: object, rate_limited?: boolean, expired?: boolean, failed?: boolean }}
 */
async function settlePendingTxFromSonicpesa(tx, source, { expireIfStillPending = false } = {}) {
  const remote = await sonicpesaOrderStatus(tx.orderId);
  if (!remote.ok) {
    if (remote.rate_limited || isSonicpesaRateLimited(remote.error)) {
      return { rate_limited: true };
    }
    return {};
  }
  const status = normalizePaymentStatus(remote.payment_status ?? remote.status ?? 'PENDING');
  if (isSonicpesaFailure(status)) {
    await markPaymentFailed(tx.orderId, { sonicpesa_status: status, closed_at: source });
    return { failed: true };
  }
  if (isSonicpesaSuccess(status)) {
    const granted = await grantPremiumFromPayment({
      deviceId: tx.deviceId,
      userName: tx.userName || 'Mtumiaji',
      phone: tx.phone || '',
      amount: Number(tx.amount) || Number(remote.amount ?? 0),
      method: tx.method || 'Mobile Money',
      planId: tx.planId,
      planName: tx.planName,
      providerRef: tx.orderId,
      metadata: {
        source,
        sonicpesa_status: status,
        reference: remote.reference || undefined,
      },
    });
    return { granted };
  }
  if (expireIfStillPending) {
    await markPaymentFailed(tx.orderId, {
      sonicpesa_status: status || 'PENDING',
      closed_at: source,
      reason: 'stale_pending_expired',
    });
    return { expired: true };
  }
  return {};
}

/**
 * If this device paid but never received premium (missed webhook / poll), grant now.
 * Cheap no-op when the account is already premium — still settles recent pending
 * SUCCESS rows so Malipo history stays accurate.
 */
async function reconcileDevicePremium(deviceId) {
  const id = String(deviceId || '').trim();
  if (!id) return null;

  try {
    const device = await prisma.device.findUnique({ where: { deviceId: id } });
    const alreadyPremium = device && hasPremiumAccess(device);
    const since = new Date(Date.now() - PENDING_REPAIR_MS);

    const stuck = await prisma.paymentTransaction.findMany({
      where: { deviceId: id, status: 'completed', amount: { gt: 0 } },
      orderBy: { updatedAt: 'desc' },
      take: 5,
    });
    for (const tx of stuck) {
      if (!needsPremiumRepair(tx, device)) continue;
      const granted = await withDbRetry(() => grantFromTx(tx, 'stuck-completed-repair'));
      if (granted.premium_until && Date.parse(granted.premium_until) > Date.now()) {
        return granted.premium_until;
      }
    }

    if (!sonicpesaConfigured()) {
      return alreadyPremium && device.premiumUntil ? device.premiumUntil.toISOString() : null;
    }

    const pending = await prisma.paymentTransaction.findMany({
      where: {
        deviceId: id,
        status: 'pending',
        amount: { gt: 0 },
        createdAt: { gt: since },
      },
      orderBy: { createdAt: 'desc' },
      take: 6,
    });
    for (const tx of pending) {
      try {
        const ageMs = Date.now() - new Date(tx.createdAt).getTime();
        const result = await withDbRetry(() =>
          settlePendingTxFromSonicpesa(tx, 'device-reconcile', {
            expireIfStillPending: ageMs > PENDING_ACTIVE_MS,
          })
        );
        if (result?.rate_limited) break;
        if (result?.granted?.premium_until && Date.parse(result.granted.premium_until) > Date.now()) {
          return result.granted.premium_until;
        }
      } catch (e) {
        console.warn('reconcile pending payment failed', tx.orderId, e.message || e);
      }
    }

    if (alreadyPremium && device.premiumUntil) return device.premiumUntil.toISOString();
  } catch (e) {
    console.warn('reconcileDevicePremium failed', id, e.message || e);
  }
  return null;
}

const _sweepInFlight = new Set();
let _sweepTimer = null;
let _sweepBackoffUntil = 0;

async function sweepPendingSonicpesaPayments() {
  if (!sonicpesaConfigured()) return;
  if (Date.now() < _sweepBackoffUntil) return;

  const now = Date.now();
  const activeSince = new Date(now - PENDING_ACTIVE_MS);
  const repairSince = new Date(now - PENDING_REPAIR_MS);

  // 1) Active USSD window first — users waiting in the app.
  const active = await prisma.paymentTransaction.findMany({
    where: { status: 'pending', amount: { gt: 0 }, createdAt: { gt: activeSince } },
    orderBy: { createdAt: 'asc' },
    take: SWEEP_BATCH,
  });

  // 2) Older pending that may already be SUCCESS on Sonic (admin used to fix these).
  const stale = await prisma.paymentTransaction.findMany({
    where: {
      status: 'pending',
      amount: { gt: 0 },
      createdAt: { gt: repairSince, lte: activeSince },
    },
    orderBy: { createdAt: 'desc' },
    take: Math.max(2, SWEEP_BATCH - active.length),
  });

  const queue = [...active, ...stale];
  for (const tx of queue) {
    if (_sweepInFlight.has(tx.orderId)) continue;
    _sweepInFlight.add(tx.orderId);
    try {
      const ageMs = now - new Date(tx.createdAt).getTime();
      const result = await settlePendingTxFromSonicpesa(tx, 'pending-sweeper', {
        expireIfStillPending: ageMs > PENDING_ACTIVE_MS,
      });
      if (result?.rate_limited) {
        // Back off so we do not keep burning the Sonic quota with abandoned pendings.
        _sweepBackoffUntil = Date.now() + 90_000;
        console.warn('payment sweeper: Sonic rate limited — backing off 90s');
        break;
      }
    } catch (e) {
      console.error('pending payment sweep failed', tx.orderId, e);
    } finally {
      _sweepInFlight.delete(tx.orderId);
    }
    await new Promise((r) => setTimeout(r, SWEEP_GAP_MS));
  }
}

function startPendingPaymentSweeper() {
  if (_sweepTimer) return;
  const tick = () => {
    sweepPendingSonicpesaPayments().catch((e) => console.error('payment sweeper', e));
  };
  setTimeout(tick, 8_000);
  _sweepTimer = setInterval(tick, 45_000);
  if (typeof _sweepTimer.unref === 'function') _sweepTimer.unref();
}

module.exports = {
  withDbRetry,
  parseAmountTzs,
  upsertPendingSonicpesaTransaction,
  grantPremiumFromPayment,
  markPaymentFailed,
  completeLocalZeroPayment,
  localPaymentsAllowed,
  findDeviceIdByPhone,
  resolvePlanByAmount,
  reconcileDevicePremium,
  startPendingPaymentSweeper,
};

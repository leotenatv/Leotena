const prisma = require('../db');

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
 * Grant/extend premium on Device + mark payment completed + write SubscriptionRecord.
 * Idempotent on orderId (provider_ref).
 */
async function grantPremiumFromPayment(input) {
  const deviceId = input.deviceId.trim();
  const orderId = input.providerRef.trim();
  const amount = Number(input.amount);
  if (!deviceId || !orderId || !(amount >= 0) || Number.isNaN(amount)) {
    throw new Error('device_id, provider_ref and non-negative amount are required');
  }

  const existingTx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
  if (existingTx?.status === 'completed') {
    const device = await prisma.device.findUnique({ where: { deviceId } });
    return {
      ok: true,
      premium_until: device?.premiumUntil ? device.premiumUntil.toISOString() : null,
      already_completed: true,
    };
  }

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

    await tx.subscriptionRecord.create({
      data: {
        deviceRecordId: device.id,
        userName,
        packageName: planName,
        amount: `TZS ${amount.toLocaleString('en-US')}`,
        success: true,
      },
    });

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
  const flag = String(process.env.ALLOW_LOCAL_PAYMENTS || process.env.LOCAL_PAYMENTS_ONLY || '')
    .trim()
    .toLowerCase();
  if (flag === '1' || flag === 'true' || flag === 'yes') return true;
  // Until Sonic keys are set, keep checkout working with amount 0 (no gateway errors).
  return !String(process.env.SONICPESA_API_KEY || '').trim();
}

module.exports = {
  withDbRetry,
  parseAmountTzs,
  upsertPendingSonicpesaTransaction,
  grantPremiumFromPayment,
  markPaymentFailed,
  completeLocalZeroPayment,
  localPaymentsAllowed,
};

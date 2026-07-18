const express = require('express');
const prisma = require('../db');
const { asyncRoute } = require('../middleware/errorHandler');
const {
  sonicpesaConfigured,
  normalizeTzPhone,
  toLocalTzPhone,
  normalizePaymentStatus,
  isSonicpesaSuccess,
  isSonicpesaFailure,
  sonicpesaCreateOrder,
  sonicpesaOrderStatus,
} = require('../lib/sonicpesa');
const {
  detectTzMobileNetwork,
  mobileMoneyMethodLabel,
  paymentPromptForPhone,
} = require('../lib/mobileMoney');
const {
  withDbRetry,
  parseAmountTzs,
  upsertPendingSonicpesaTransaction,
  grantPremiumFromPayment,
  markPaymentFailed,
  completeLocalZeroPayment,
  localPaymentsAllowed,
} = require('../lib/premiumPayment');
const { serializeDevice } = require('../lib/serialize');

const router = express.Router();

async function respondLocalComplete(req, res, { deviceId, planId, userName, localPhone }) {
  try {
    const result = await withDbRetry(() =>
      completeLocalZeroPayment({
        deviceId,
        planId,
        userName,
        phone: localPhone || '',
      })
    );
    return res.status(201).json({
      ok: true,
      local: true,
      completed: true,
      amount: 0,
      orderId: result.orderId,
      order_id: result.orderId,
      planId: result.planId,
      paymentStatus: 'SUCCESS',
      payment_status: 'SUCCESS',
      message: 'Malipo ya majaribio yamefanikiwa (TSh 0).',
      premiumUntil: result.premium_until,
      premium_until: result.premium_until,
      device: result.device ? serializeDevice(result.device) : null,
    });
  } catch (e) {
    const status = e.status || 500;
    return res.status(status).json({ error: e.message || 'Local payment failed' });
  }
}

/** Start SonicPesa USSD push — or local TSh 0 grant when Sonic is not configured. */
router.post(
  '/payments/sonicpesa/initiate',
  asyncRoute(async (req, res) => {
    const b = req.body || {};
    const deviceId = String(b.deviceId || b.device_id || '').trim();
    const planId = String(b.planId || b.plan_id || b.plan_key || '').trim();
    const userName = String(b.userName || b.user_name || '').trim() || 'Mtumiaji';
    const phoneRaw = String(b.phone || '').trim();
    const buyerPhone = normalizeTzPhone(phoneRaw);
    const localPhone = toLocalTzPhone(phoneRaw);

    if (!deviceId || !planId) {
      return res.status(400).json({ error: 'deviceId and planId are required' });
    }
    if (!buyerPhone || !localPhone) {
      return res.status(400).json({
        error:
          'Namba ya simu si sahihi. Tumia 07…, 06… (Halotel 061/062/063/069), tarakimu 9 bila 0, au 255…',
      });
    }

    // Local-only zero-amount path: no Sonic errors, instant premium for plan days.
    if (localPaymentsAllowed() || !sonicpesaConfigured()) {
      return respondLocalComplete(req, res, { deviceId, planId, userName, localPhone });
    }

    const plan = await prisma.pricingPlan.findUnique({ where: { id: planId } });
    if (!plan) return res.status(404).json({ error: 'plan not found' });
    if (!plan.active) return res.status(400).json({ error: 'plan is not available' });

    const amount = parseAmountTzs(plan.price);
    if (amount <= 0) return res.status(400).json({ error: 'invalid plan price' });

    const emailBase = deviceId.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 40) || 'viewer';
    const buyerEmail = String(b.buyerEmail || b.buyer_email || '').trim() || `${emailBase}@leotena.app`;

    let order;
    try {
      order = await sonicpesaCreateOrder({
        buyer_email: buyerEmail,
        buyer_name: userName,
        buyer_phone: buyerPhone,
        amount,
        currency: 'TZS',
      });
    } catch (e) {
      console.error('sonicpesaCreateOrder threw', e);
      // Soft fallback — never leave the user stuck if gateway errors.
      if (localPaymentsAllowed()) {
        return respondLocalComplete(req, res, { deviceId, planId, userName, localPhone });
      }
      return res.status(503).json({
        error: 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.',
      });
    }

    if (!order.ok || !order.order_id) {
      if (localPaymentsAllowed()) {
        return respondLocalComplete(req, res, { deviceId, planId, userName, localPhone });
      }
      const unreachable =
        order.error?.toLowerCase().includes('unreachable') ||
        order.error?.toLowerCase().includes('timed out');
      return res.status(unreachable ? 503 : 502).json({
        error: 'Imeshindikana kuanzisha malipo. Hakikisha namba ya simu ni sahihi na jaribu tena.',
      });
    }

    const network = detectTzMobileNetwork(localPhone);
    const payMethod = mobileMoneyMethodLabel(network);
    const orderId = order.order_id;

    try {
      await withDbRetry(() =>
        upsertPendingSonicpesaTransaction({
          deviceId,
          userName,
          phone: localPhone,
          amount,
          planId: plan.id,
          planName: plan.name,
          orderId,
          method: payMethod,
          metadata: {
            reference: order.reference,
            initial_status: order.payment_status,
            network,
            planDays: plan.days,
          },
        })
      );
    } catch (dbErr) {
      console.error('upsertPendingSonicpesaTransaction failed', dbErr);
      return res.status(502).json({
        error:
          'Malipo yameanzishwa lakini seva haikuweza kuyahifadhi. Jaribu tena — usirudie malipo kwenye simu ikiwa umepokea ombi.',
        orderId,
        order_id: orderId,
      });
    }

    res.status(201).json({
      ok: true,
      orderId,
      order_id: orderId,
      reference: order.reference ?? null,
      amount,
      currency: 'TZS',
      planId: plan.id,
      paymentStatus: order.payment_status ?? 'PENDING',
      payment_status: order.payment_status ?? 'PENDING',
      message: paymentPromptForPhone(localPhone),
      network,
      payMethod,
      completed: false,
      local: false,
    });
  })
);

/** Explicit local TSh 0 complete (same rules as initiate fallback). */
router.post(
  '/payments/local/complete',
  asyncRoute(async (req, res) => {
    if (!localPaymentsAllowed() && sonicpesaConfigured()) {
      return res.status(403).json({ error: 'Local payments are disabled' });
    }
    const b = req.body || {};
    const deviceId = String(b.deviceId || b.device_id || '').trim();
    const planId = String(b.planId || b.plan_id || '').trim();
    const userName = String(b.userName || b.user_name || '').trim() || 'Mtumiaji';
    const phoneRaw = String(b.phone || '').trim();
    const localPhone = toLocalTzPhone(phoneRaw) || phoneRaw;
    if (!deviceId || !planId) {
      return res.status(400).json({ error: 'deviceId and planId are required' });
    }
    return respondLocalComplete(req, res, { deviceId, planId, userName, localPhone });
  })
);

/** Poll SonicPesa order — completes premium when payment succeeds. */
router.post(
  '/payments/sonicpesa/status',
  asyncRoute(async (req, res) => {
    const b = req.body || {};
    const deviceId = String(b.deviceId || b.device_id || '').trim();
    const orderId = String(b.orderId || b.order_id || '').trim();
    if (!deviceId || !orderId) {
      return res.status(400).json({ error: 'deviceId and orderId are required' });
    }

    const tx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
    if (!tx) return res.status(404).json({ error: 'payment session not found' });
    if (tx.deviceId !== deviceId) {
      return res.status(403).json({ error: 'device mismatch' });
    }

    if (tx.status === 'completed' || orderId.startsWith('local-')) {
      const device = await prisma.device.findUnique({ where: { deviceId } });
      return res.json({
        ok: true,
        paymentStatus: 'SUCCESS',
        payment_status: 'SUCCESS',
        completed: true,
        failed: false,
        pending: false,
        local: orderId.startsWith('local-'),
        premiumUntil: device?.premiumUntil ? device.premiumUntil.toISOString() : null,
        premium_until: device?.premiumUntil ? device.premiumUntil.toISOString() : null,
        device: device ? serializeDevice(device) : null,
      });
    }

    if (!sonicpesaConfigured()) {
      // Soft: no gateway yet — treat as still pending without error noise.
      return res.json({
        ok: true,
        paymentStatus: 'PENDING',
        payment_status: 'PENDING',
        completed: false,
        failed: false,
        pending: true,
        local: true,
      });
    }

    const remote = await sonicpesaOrderStatus(orderId);
    if (!remote.ok) {
      const unreachable =
        remote.error?.toLowerCase().includes('unreachable') ||
        remote.error?.toLowerCase().includes('timed out');
      return res.status(unreachable ? 503 : 502).json({
        error: 'Imeshindikana kuangalia hali ya malipo. Jaribu tena.',
      });
    }

    const paymentStatus = normalizePaymentStatus(remote.payment_status ?? remote.status ?? 'PENDING');

    if (isSonicpesaSuccess(paymentStatus)) {
      const grantPhone = String(b.phone || tx.phone || '').trim();
      const localGrantPhone = toLocalTzPhone(grantPhone) || grantPhone;
      const payMethod = mobileMoneyMethodLabel(detectTzMobileNetwork(localGrantPhone));
      try {
        const granted = await withDbRetry(() =>
          grantPremiumFromPayment({
            deviceId,
            userName: String(b.userName || b.user_name || tx.userName || 'Mtumiaji').trim(),
            phone: localGrantPhone,
            amount: Number(tx.amount),
            method: payMethod,
            planId: tx.planId,
            planName: tx.planName,
            providerRef: orderId,
            metadata: { sonicpesa_status: paymentStatus, reference: remote.reference },
          })
        );
        const device = await prisma.device.findUnique({ where: { deviceId } });
        return res.json({
          ok: true,
          paymentStatus,
          payment_status: paymentStatus,
          completed: true,
          failed: false,
          pending: false,
          premiumUntil: granted.premium_until,
          premium_until: granted.premium_until,
          device: device ? serializeDevice(device) : null,
        });
      } catch (e) {
        console.error('grantPremiumFromPayment failed after SonicPesa success', e);
        return res
          .status(500)
          .json({ error: 'Payment received but premium activation failed. Contact support.' });
      }
    }

    if (isSonicpesaFailure(paymentStatus)) {
      await markPaymentFailed(orderId, { sonicpesa_status: paymentStatus });
      return res.json({
        ok: true,
        paymentStatus,
        payment_status: paymentStatus,
        completed: false,
        failed: true,
        pending: false,
        message: 'Malipo hayajakamilika. Jaribu tena.',
      });
    }

    res.json({
      ok: true,
      paymentStatus,
      payment_status: paymentStatus,
      completed: false,
      failed: false,
      pending: true,
    });
  })
);

/**
 * SonicPesa webhook — paste this URL in SonicPesa dashboard → Webhook System.
 * https://leotena-api-production.up.railway.app/webhooks/sonicpesa
 */
router.post(
  '/webhooks/sonicpesa',
  asyncRoute(async (req, res) => {
    const b = req.body || {};
    const orderId = String(b.order_id ?? b.orderId ?? '').trim();
    const status = normalizePaymentStatus(b.status ?? b.payment_status);
    const event = String(b.event ?? '')
      .trim()
      .toLowerCase();
    const transid = String(b.transid ?? b.transaction_id ?? '').trim();

    const webhookSecret = (process.env.SONICPESA_WEBHOOK_SECRET || '').trim();
    if (webhookSecret) {
      const headerSecret = String(
        req.headers['x-webhook-secret'] ?? req.headers['x-sonicpesa-secret'] ?? ''
      ).trim();
      if (headerSecret !== webhookSecret) {
        return res.status(401).json({ error: 'invalid webhook secret' });
      }
    }

    if (!orderId) return res.status(400).json({ error: 'order_id is required' });

    const tx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
    if (!tx) {
      console.warn('SonicPesa webhook: unknown order_id', orderId, event);
      return res.json({ ok: true, ignored: true, reason: 'order_not_found' });
    }

    const completedEvent = event === 'payment.completed' || event === 'payment.success';
    const success = completedEvent || isSonicpesaSuccess(status);
    const failed = isSonicpesaFailure(status);

    if (tx.status === 'completed') {
      return res.json({ ok: true, already_completed: true, order_id: orderId });
    }

    if (success) {
      const payMethod = mobileMoneyMethodLabel(detectTzMobileNetwork(tx.phone));
      try {
        await withDbRetry(() =>
          grantPremiumFromPayment({
            deviceId: tx.deviceId,
            userName: tx.userName || 'Mtumiaji',
            phone: tx.phone,
            amount: Number(tx.amount),
            method: payMethod,
            planId: tx.planId,
            planName: tx.planName,
            providerRef: orderId,
            metadata: {
              source: 'sonicpesa-webhook',
              sonicpesa_status: status,
              sonicpesa_event: event,
              transid: transid || undefined,
            },
          })
        );
      } catch (e) {
        console.error('SonicPesa webhook: grantPremiumFromPayment failed', e);
        return res.status(500).json({ error: 'premium grant failed, will retry' });
      }
      return res.json({ ok: true, completed: true, order_id: orderId });
    }

    if (failed) {
      await markPaymentFailed(orderId, {
        sonicpesa_status: status,
        sonicpesa_event: event,
        transid: transid || undefined,
      });
      return res.json({ ok: true, failed: true, order_id: orderId });
    }

    res.json({ ok: true, pending: true, order_id: orderId, payment_status: status });
  })
);

module.exports = router;

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
  sonicpesaOrderStatus,
  readWebhookPaymentFields,
} = require('../lib/sonicpesa');
const {
  detectTzMobileNetwork,
  mobileMoneyMethodLabel,
  mapSonicInitiateError,
} = require('../lib/mobileMoney');
const {
  acceptPaymentPush,
  findPaymentByOrderRef,
  attachInflightSonicOrder,
  providerOrderId,
  queuedMessage,
  shouldDeferStatus,
  noteStatusCheck,
} = require('../lib/paymentDispatch');
const {
  withDbRetry,
  parseAmountTzs,
  upsertPendingSonicpesaTransaction,
  grantPremiumFromPayment,
  markPaymentFailed,
  completeLocalZeroPayment,
  localPaymentsAllowed,
  findDeviceIdByPhone,
  resolvePlanByAmount,
} = require('../lib/premiumPayment');
const { serializeDevice, hasPremiumAccess } = require('../lib/serialize');

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
          'Namba ya simu si sahihi. Tumia 07…, 06… (Halotel 061/062/063), tarakimu 9 bila 0, au 255…',
      });
    }

    // Dev-only zero-amount path (ALLOW_LOCAL_PAYMENTS=true). Production always uses SonicPesa.
    if (localPaymentsAllowed()) {
      return respondLocalComplete(req, res, { deviceId, planId, userName, localPhone });
    }

    if (!sonicpesaConfigured()) {
      return res.status(503).json({
        error: 'Malipo hayajasanidi kwenye seva. Wasiliana na msaada.',
      });
    }

    const plan = await prisma.pricingPlan.findUnique({ where: { id: planId } });
    if (!plan) return res.status(404).json({ error: 'plan not found' });
    if (!plan.active) return res.status(400).json({ error: 'plan is not available' });

    const amount = parseAmountTzs(plan.price);
    if (amount <= 0) return res.status(400).json({ error: 'invalid plan price' });

    const emailBase = deviceId.replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 40) || 'viewer';
    const buyerEmail = String(b.buyerEmail || b.buyer_email || '').trim() || `${emailBase}@leotena.app`;
    const network = detectTzMobileNetwork(localPhone);

    // Queued so a rush cannot stampede SonicPesa. Every accepted checkout
    // gets one PIN push; repeats of the same phone join that push.
    const body = await acceptPaymentPush({
      deviceId,
      userName,
      phone: localPhone,
      buyerPhone,
      buyerEmail,
      amount,
      planId: plan.id,
      planName: plan.name,
      planDays: plan.days,
      network,
      method: mobileMoneyMethodLabel(network),
    });
    res.status(201).json(body);
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
    const planIdHint = String(b.planId || b.plan_id || b.plan_key || '').trim();
    if (!deviceId || !orderId) {
      return res.status(400).json({ error: 'deviceId and orderId are required' });
    }

    let tx = await findPaymentByOrderRef(orderId);

    // Recover initiate-time DB failure: client has a Sonic order id but no local row yet.
    // Queued ids (q_…) are ours — never ask Sonic about them.
    if (!tx && sonicpesaConfigured() && !orderId.startsWith('local-') && !orderId.startsWith('q_')) {
      try {
        const remote = await sonicpesaOrderStatus(orderId);
        if (remote.ok) {
          const grantPhone = String(b.phone || remote.buyer_phone || '').trim();
          const localGrantPhone = toLocalTzPhone(grantPhone) || grantPhone;
          const amount = Number(remote.amount) || parseAmountTzs(b.amount);
          const plan =
            (planIdHint ? await prisma.pricingPlan.findUnique({ where: { id: planIdHint } }) : null) ||
            (amount > 0 ? await resolvePlanByAmount(amount, planIdHint) : null);
          if (plan?.active && localGrantPhone) {
            const payMethod = mobileMoneyMethodLabel(detectTzMobileNetwork(localGrantPhone));
            await withDbRetry(() =>
              upsertPendingSonicpesaTransaction({
                deviceId,
                userName: String(b.userName || b.user_name || 'Mtumiaji').trim(),
                phone: localGrantPhone,
                amount: amount > 0 ? amount : parseAmountTzs(plan.price),
                planId: plan.id,
                planName: plan.name,
                orderId,
                method: payMethod,
                metadata: {
                  source: 'status-poll-recovery',
                  reference: remote.reference,
                  planDays: plan.days,
                },
              })
            );
            tx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
          }
        }
      } catch (e) {
        console.warn('status poll recovery for missing tx failed', orderId, e.message || e);
      }
    }

    if (!tx) return res.status(404).json({ error: 'payment session not found' });
    if (tx.deviceId !== deviceId) {
      return res.status(403).json({ error: 'device mismatch' });
    }

    if ((tx.status === 'queued' || tx.status === 'dispatching') && !providerOrderId(tx)) {
      return res.json({
        ok: true,
        paymentStatus: 'QUEUED',
        payment_status: 'QUEUED',
        completed: false,
        failed: false,
        pending: true,
        queued: true,
        message: queuedMessage(tx.status),
      });
    }

    if (tx.status === 'failed' && !providerOrderId(tx)) {
      const meta = tx.metadata && typeof tx.metadata === 'object' && !Array.isArray(tx.metadata) ? tx.metadata : {};
      return res.json({
        ok: true,
        paymentStatus: 'FAILED',
        payment_status: 'FAILED',
        completed: false,
        failed: true,
        pending: false,
        queued: false,
        message: mapSonicInitiateError(meta.last_error, tx.phone),
      });
    }

    if (tx.status === 'completed' || orderId.startsWith('local-')) {
      if (tx.status === 'completed' && !orderId.startsWith('local-')) {
        try {
          await withDbRetry(() =>
            grantPremiumFromPayment({
              deviceId,
              userName: String(b.userName || b.user_name || tx.userName || 'Mtumiaji').trim(),
              phone: toLocalTzPhone(String(b.phone || tx.phone || '').trim()) || tx.phone,
              amount: Number(tx.amount),
              method: tx.method || 'Mobile Money',
              planId: tx.planId,
              planName: tx.planName,
              providerRef: tx.orderId,
              metadata: { source: 'status-completed-repair' },
            })
          );
        } catch (e) {
          console.error('repair completed payment on status poll', e);
        }
      }
      const device = await prisma.device.findUnique({ where: { deviceId } });
      const premiumActive = device && hasPremiumAccess(device);
      if (tx.status === 'completed' && !orderId.startsWith('local-') && !premiumActive) {
        return res.status(500).json({
          error: 'Malipo yamepokelewa lakini ufikiaji wa Premium haujawashwa. Tunajaribu tena…',
          pending: true,
          completed: false,
        });
      }
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

    const providerId = providerOrderId(tx);
    if (!providerId) {
      return res.json({
        ok: true,
        paymentStatus: 'QUEUED',
        payment_status: 'QUEUED',
        completed: false,
        failed: false,
        pending: true,
        queued: true,
        message: queuedMessage('queued'),
      });
    }

    // While many PIN pushes are waiting, don't spend the gateway quota on polls.
    // The webhook (or a later poll) still completes the payment.
    if (shouldDeferStatus()) {
      return res.json({
        ok: true,
        paymentStatus: 'PENDING',
        payment_status: 'PENDING',
        completed: false,
        failed: false,
        pending: true,
        queued: false,
        message: 'Tunasubiri uthibitisho wa malipo…',
      });
    }

    noteStatusCheck();
    const remote = await sonicpesaOrderStatus(providerId);
    if (!remote.ok) {
      const rateLimited =
        remote.rate_limited ||
        String(remote.error || '')
          .toLowerCase()
          .includes('too many');
      if (rateLimited) {
        // Soft: keep the client waiting without treating rate limits as hard failures.
        return res.json({
          ok: true,
          paymentStatus: 'PENDING',
          payment_status: 'PENDING',
          completed: false,
          failed: false,
          pending: true,
          rate_limited: true,
          message: 'Tunasubiri uthibitisho wa malipo…',
        });
      }
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
            providerRef: tx.orderId,
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
        return res.status(500).json({
          error: 'Malipo yamepokelewa lakini ufikiaji wa Premium haujawashwa. Tunajaribu tena…',
          pending: true,
          completed: false,
        });
      }
    }

    if (isSonicpesaFailure(paymentStatus)) {
      await markPaymentFailed(tx.orderId, { sonicpesa_status: paymentStatus });
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
    const parsed = readWebhookPaymentFields(b);
    const orderId = parsed.orderId;
    const status = parsed.status;
    const event = parsed.event;
    const transid = parsed.transid;
    const webhookPhone = parsed.phone;

    const webhookSecret = (process.env.SONICPESA_WEBHOOK_SECRET || '').trim();
    if (webhookSecret) {
      const headerSecret = String(
        req.headers['x-webhook-secret'] ?? req.headers['x-sonicpesa-secret'] ?? ''
      ).trim();
      if (headerSecret !== webhookSecret) {
        return res.status(401).json({ error: 'invalid webhook secret' });
      }
    } else if (process.env.NODE_ENV === 'production') {
      console.warn('SONICPESA_WEBHOOK_SECRET is not set — webhook endpoint is unauthenticated');
    }

    if (!orderId) return res.status(400).json({ error: 'order_id is required' });

    const completedEvent = event === 'payment.completed' || event === 'payment.success';
    const success = completedEvent || isSonicpesaSuccess(status);
    const failed = isSonicpesaFailure(status);

    let tx = await findPaymentByOrderRef(orderId);
    if (!tx) {
      tx = await attachInflightSonicOrder({
        sonicOrderId: orderId,
        phone: webhookPhone,
        amount: parsed.amount,
      });
    }

    // Orphan recovery: paid webhook for an order we never stored (initiate DB failure).
    if (!tx && success) {
      let buyerPhone = webhookPhone;
      let amount = parsed.amount;
      try {
        const remote = await sonicpesaOrderStatus(orderId);
        if (remote.ok) {
          if (!buyerPhone && remote.buyer_phone) buyerPhone = remote.buyer_phone;
          if (!(amount > 0) && remote.amount != null) amount = Number(remote.amount);
        }
      } catch (e) {
        console.warn('SonicPesa webhook: order_status lookup failed for orphan', e);
      }

      const deviceId = buyerPhone ? await findDeviceIdByPhone(buyerPhone, orderId) : null;
      const plan = amount > 0 ? await resolvePlanByAmount(amount) : null;
      if (!deviceId || !plan) {
        console.warn('SonicPesa webhook: unknown order_id and cannot recover', orderId, {
          hasPhone: Boolean(buyerPhone),
          amount,
        });
        return res.status(500).json({ error: 'order_not_found_retry' });
      }

      const localPhone = toLocalTzPhone(buyerPhone) || buyerPhone;
      try {
        await withDbRetry(() =>
          upsertPendingSonicpesaTransaction({
            deviceId,
            userName: 'Mtumiaji',
            phone: localPhone,
            amount: Math.round(amount),
            planId: plan.id,
            planName: plan.name,
            orderId,
            method: mobileMoneyMethodLabel(detectTzMobileNetwork(localPhone)),
            metadata: { source: 'sonicpesa-webhook-orphan', sonicpesa_event: event, planDays: plan.days },
          })
        );
        tx = await prisma.paymentTransaction.findUnique({ where: { orderId } });
      } catch (e) {
        console.error('SonicPesa webhook: orphan pending upsert failed', e);
        return res.status(500).json({ error: 'orphan recovery failed, will retry' });
      }
    }

    if (!tx) {
      console.warn('SonicPesa webhook: unknown order_id', orderId, event);
      if (success) return res.status(500).json({ error: 'order_not_found_retry' });
      return res.json({ ok: true, ignored: true, reason: 'order_not_found' });
    }

    if (success) {
      const payMethod = mobileMoneyMethodLabel(detectTzMobileNetwork(tx.phone));
      try {
        const granted = await withDbRetry(() =>
          grantPremiumFromPayment({
            deviceId: tx.deviceId,
            userName: tx.userName || 'Mtumiaji',
            phone: tx.phone,
            amount: Number(tx.amount),
            method: payMethod,
            planId: tx.planId,
            planName: tx.planName,
            providerRef: tx.orderId,
            metadata: {
              source: tx.status === 'completed' ? 'sonicpesa-webhook-repair' : 'sonicpesa-webhook',
              sonicpesa_status: status,
              sonicpesa_event: event,
              transid: transid || undefined,
            },
          })
        );
        if (!granted.premium_until) {
          return res.status(500).json({ error: 'premium grant missing until, will retry' });
        }
      } catch (e) {
        console.error('SonicPesa webhook: grantPremiumFromPayment failed', e);
        return res.status(500).json({ error: 'premium grant failed, will retry' });
      }
      return res.json({ ok: true, completed: true, order_id: orderId });
    }

    if (tx.status === 'completed') {
      return res.json({ ok: true, already_completed: true, order_id: orderId });
    }

    if (failed) {
      await markPaymentFailed(tx.orderId, {
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

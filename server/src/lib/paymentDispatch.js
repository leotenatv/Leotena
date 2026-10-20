/**
 * Fair queue for SonicPesa PIN pushes (create_order).
 *
 * A rush of checkouts used to fire create_order and order_status at the same
 * time. Sonic answered with "too many attempts", and those phones never got a
 * USSD PIN — on every network, because the push never left our server.
 *
 * Pushes run a few at a time with a gap and are retried when the gateway is
 * busy. Status polls slow down while pushes are waiting so they cannot steal
 * the quota. The HTTP handler returns as soon as the wait would hold the
 * connection too long; the push still goes out.
 */

const { randomUUID } = require('crypto');
const {
  sonicpesaCreateOrder,
  isSonicpesaRateLimited,
  toLocalTzPhone,
} = require('./sonicpesa');
const {
  detectTzMobileNetwork,
  mobileMoneyMethodLabel,
  paymentPromptForPhone,
  mapSonicInitiateError,
} = require('./mobileMoney');

const REUSE_PUSHED_MS = 90 * 1000;
const REUSE_QUEUED_MS = 3 * 60 * 1000;
const MAX_WAITING = 2000;

function clampInt(raw, fallback, min, max) {
  const n = Number(raw);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function mergeMeta(existing, patch) {
  const base = existing && typeof existing === 'object' && !Array.isArray(existing) ? existing : {};
  const extra = patch && typeof patch === 'object' && !Array.isArray(patch) ? patch : {};
  return { ...base, ...extra };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function db() {
  return require('../db');
}

/**
 * How many times a failed push may be tried again.
 * Rate limits and "unreachable" did not send a PIN. A timeout might have.
 */
function retryBudget(error, rateLimited) {
  if (rateLimited || isSonicpesaRateLimited(error)) return 8;
  const s = String(error || '').toLowerCase();
  if (s.includes('timed out') || s.includes('abort')) return 2;
  if (s.includes('unreachable') || s.includes('econnreset') || s.includes('socket')) return 4;
  return 0;
}

function retryDelayMs(attempt, rateLimited) {
  if (rateLimited) return Math.min(20_000, 1500 * attempt);
  return Math.min(8_000, 700 * attempt);
}

function createPaymentDispatcher(options = {}) {
  const minConcurrency = 1;
  const maxConcurrency = options.maxConcurrency || 3;
  const gapMs = options.gapMs ?? 280;
  const rateLimitPauseMs = options.rateLimitPauseMs ?? 5_000;
  const log = options.log || (() => {});

  const queue = [];
  const ids = new Set();
  const waiters = new Map();
  const results = new Map();
  let active = 0;
  let concurrency = options.concurrency || 2;
  let pauseUntil = 0;
  let notBefore = 0;
  let successStreak = 0;
  let rateStrikes = 0;
  let statusNotBefore = 0;
  let completed = 0;

  function paused() {
    return Date.now() < pauseUntil;
  }

  function onRateLimit() {
    successStreak = 0;
    concurrency = minConcurrency;
    rateStrikes = Math.min(rateStrikes + 1, 5);
    const pause = Math.min(20_000, rateLimitPauseMs * rateStrikes);
    pauseUntil = Math.max(pauseUntil, Date.now() + pause);
    log(`payment dispatch: gateway busy, pausing ${pause}ms (concurrency 1)`);
  }

  function onSuccess() {
    rateStrikes = 0;
    successStreak += 1;
    if (successStreak >= 10 && concurrency < maxConcurrency) {
      concurrency += 1;
      successStreak = 0;
      log(`payment dispatch: raising concurrency to ${concurrency}`);
    }
  }

  function finish(id, result) {
    ids.delete(id);
    results.set(id, result);
    setTimeout(() => {
      if (results.get(id) === result) results.delete(id);
    }, 10 * 60 * 1000).unref?.();
    const list = waiters.get(id) || [];
    waiters.delete(id);
    for (const waiter of list) {
      clearTimeout(waiter.timer);
      waiter.resolve(result);
    }
    completed += 1;
    if (queue.length >= 10 && completed % 25 === 0) {
      log(`payment dispatch: sent=${completed} waiting=${queue.length} active=${active}`);
    }
  }

  function pump() {
    while (queue.length > 0 && active < concurrency && !paused()) {
      const job = queue.shift();
      if (!job) break;
      const delay = Math.max(0, notBefore - Date.now());
      notBefore = Date.now() + delay + gapMs;
      active += 1;
      setTimeout(() => {
        run(job).catch((err) => log('payment dispatch run failed', err));
      }, delay);
    }
  }

  function schedulePump(ms) {
    setTimeout(pump, Math.max(0, ms)).unref?.();
  }

  async function run(job) {
    try {
      const result = await job.execute();
      if (result?.skipped) return;
      if (result?.retry) {
        if (result.rateLimited) onRateLimit();
        const delay = Number(result.delayMs) > 0 ? Number(result.delayMs) : 1000;
        setTimeout(() => {
          queue.push(job);
          pump();
        }, delay);
        return;
      }
      if (result?.ok) onSuccess();
      finish(job.id, result || { ok: true });
    } catch (err) {
      const error = err instanceof Error ? err.message : String(err);
      finish(job.id, { failed: true, error });
    } finally {
      active -= 1;
      if (paused()) schedulePump(pauseUntil - Date.now() + 30);
      else pump();
    }
  }

  function enqueue(job) {
    if (!job?.id || ids.has(job.id)) return false;
    ids.add(job.id);
    queue.push(job);
    pump();
    return true;
  }

  function waitFor(id, ms) {
    const existing = results.get(id);
    if (existing) return Promise.resolve(existing);
    return new Promise((resolve) => {
      const waiter = { resolve, timer: null };
      const list = waiters.get(id) || [];
      list.push(waiter);
      waiters.set(id, list);
      const raced = results.get(id);
      if (raced) {
        waiters.set(
          id,
          (waiters.get(id) || []).filter((item) => item !== waiter)
        );
        resolve(raced);
        return;
      }
      waiter.timer = setTimeout(() => {
        const pending = waiters.get(id) || [];
        waiters.set(
          id,
          pending.filter((item) => item !== waiter)
        );
        resolve({ pending: true, queued: true });
      }, ms);
    });
  }

  function shouldDeferStatus() {
    if (paused()) return true;
    if (queue.length >= 4) return true;
    if ((queue.length > 0 || active > 0) && Date.now() < statusNotBefore) return true;
    return false;
  }

  function noteStatusCheck() {
    if (queue.length > 0 || active > 0) statusNotBefore = Date.now() + 2_000;
  }

  return {
    enqueue,
    waitFor,
    shouldDeferStatus,
    noteStatusCheck,
    onRateLimit,
    get waiting() {
      return queue.length;
    },
    get active() {
      return active;
    },
    get paused() {
      return paused();
    },
  };
}

const dispatcher = createPaymentDispatcher({
  concurrency: clampInt(process.env.PAYMENT_PUSH_CONCURRENCY, 2, 1, 4),
  maxConcurrency: clampInt(process.env.PAYMENT_PUSH_MAX_CONCURRENCY, 3, 1, 4),
  gapMs: clampInt(process.env.PAYMENT_PUSH_GAP_MS, 280, 80, 2_000),
  rateLimitPauseMs: clampInt(process.env.PAYMENT_PUSH_PAUSE_MS, 5_000, 1_000, 30_000),
  log: (...args) => console.log(...args),
});

/** local order id -> Sonic order id, if the DB write lagged behind the push. */
const sonicByLocal = new Map();
const localBySonic = new Map();

function rememberSonicLink(localOrderId, sonicOrderId) {
  const local = String(localOrderId || '').trim();
  const sonic = String(sonicOrderId || '').trim();
  if (!local || !sonic) return;
  sonicByLocal.set(local, sonic);
  localBySonic.set(sonic, local);
  if (sonicByLocal.size > 2000) {
    const first = sonicByLocal.keys().next().value;
    const linked = first ? sonicByLocal.get(first) : '';
    if (first) sonicByLocal.delete(first);
    if (linked) localBySonic.delete(linked);
  }
}

function providerOrderId(tx) {
  if (!tx) return '';
  const meta = tx.metadata && typeof tx.metadata === 'object' && !Array.isArray(tx.metadata) ? tx.metadata : {};
  const sonic = String(meta.sonic_order_id || meta.sonicOrderId || '').trim();
  if (sonic) return sonic;
  const remembered = sonicByLocal.get(String(tx.orderId || '').trim());
  if (remembered) return remembered;
  const id = String(tx.orderId || '').trim();
  if (!id || id.startsWith('q_') || id.startsWith('local-')) return '';
  return id;
}

function queuedMessage(status) {
  if (status === 'dispatching') {
    return 'PIN inatumwa sasa. Angalia simu yako na uwe tayari kuthibitisha.';
  }
  return 'Ombi lako la PIN liko kwenye foleni. Subiri ujumbe kwenye simu — usifunge ukurasa huu.';
}

function presentPayment(tx, { queued }) {
  const phone = tx.phone || '';
  return {
    ok: true,
    orderId: tx.orderId,
    order_id: tx.orderId,
    reference: null,
    amount: tx.amount,
    currency: 'TZS',
    planId: tx.planId,
    paymentStatus: queued ? 'QUEUED' : 'PENDING',
    payment_status: queued ? 'QUEUED' : 'PENDING',
    message: queued ? queuedMessage(tx.status) : paymentPromptForPhone(phone),
    network: detectTzMobileNetwork(phone),
    payMethod: tx.method || mobileMoneyMethodLabel(detectTzMobileNetwork(phone)),
    completed: false,
    local: false,
    queued: Boolean(queued),
    dispatched: !queued,
  };
}

async function withDbRetry(fn, attempts = 3) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (err) {
      lastErr = err;
      if (i < attempts - 1) await sleep(250 * (i + 1));
    }
  }
  throw lastErr;
}

async function findReusable(input) {
  const since = new Date(Date.now() - REUSE_QUEUED_MS);
  return db().paymentTransaction.findFirst({
    where: {
      deviceId: input.deviceId,
      phone: input.phone,
      planId: input.planId,
      amount: input.amount,
      status: { in: ['queued', 'dispatching', 'pending'] },
      createdAt: { gt: since },
    },
    orderBy: { createdAt: 'desc' },
  });
}

function reuseDecision(existing) {
  if (!existing) return 'create';
  const age = Date.now() - new Date(existing.createdAt).getTime();
  if ((existing.status === 'queued' || existing.status === 'dispatching') && age < REUSE_QUEUED_MS) {
    return 'join';
  }
  if (existing.status === 'pending' && providerOrderId(existing) && age < REUSE_PUSHED_MS) {
    return 'already_sent';
  }
  return 'create';
}

async function executePush(rowId) {
  const existing = await db().paymentTransaction.findUnique({ where: { id: rowId } });
  if (!existing) return { failed: true, error: 'payment session missing' };
  if (existing.status === 'failed') {
    const meta = mergeMeta(existing.metadata, {});
    return { failed: true, error: meta.last_error || 'Imeshindikana kuanzisha malipo.' };
  }
  if (existing.status === 'completed' || (existing.status === 'pending' && providerOrderId(existing))) {
    return { ok: true, dispatched: true };
  }

  const claimed = await db().paymentTransaction.updateMany({
    where: { id: rowId, status: 'queued' },
    data: { status: 'dispatching' },
  });
  if (claimed.count !== 1) {
    const now = await db().paymentTransaction.findUnique({ where: { id: rowId } });
    if (now?.status === 'completed' || (now?.status === 'pending' && providerOrderId(now))) {
      return { ok: true, dispatched: true };
    }
    // Another worker owns this push. Do not send a second PIN.
    return { skipped: true };
  }

  const meta = mergeMeta(existing.metadata, {});
  const attempts = Number(meta.attempts || 0) + 1;
  let order;
  try {
    order = await sonicpesaCreateOrder({
      buyer_email: meta.buyer_email,
      buyer_name: meta.buyer_name || existing.userName || 'Mtumiaji',
      buyer_phone: meta.buyer_phone,
      amount: existing.amount,
      currency: 'TZS',
    });
  } catch (err) {
    order = { ok: false, error: err instanceof Error ? err.message : 'SonicPesa is unreachable' };
  }

  if (!order.ok || !order.order_id) {
    const error = String(order.error || 'Imeshindikana kuanzisha malipo.');
    const rateLimited = Boolean(order.rate_limited) || isSonicpesaRateLimited(error);
    const budget = retryBudget(error, rateLimited);
    if (attempts < budget) {
      await withDbRetry(() =>
        db().paymentTransaction.update({
          where: { id: rowId },
          data: {
            status: 'queued',
            metadata: mergeMeta(meta, {
              attempts,
              last_error: error,
              nextAttemptAt: new Date(Date.now() + retryDelayMs(attempts, rateLimited)).toISOString(),
            }),
          },
        })
      );
      return {
        retry: true,
        rateLimited,
        delayMs: retryDelayMs(attempts, rateLimited),
        error,
      };
    }
    await withDbRetry(() =>
      db().paymentTransaction.update({
        where: { id: rowId },
        data: {
          status: 'failed',
          metadata: mergeMeta(meta, { attempts, last_error: error }),
        },
      })
    );
    return { failed: true, error };
  }

  rememberSonicLink(existing.orderId, order.order_id);
  const fresh = await db().paymentTransaction.findUnique({ where: { id: rowId } });
  if (fresh?.status === 'completed') return { ok: true, dispatched: true };

  const nextMeta = mergeMeta(fresh?.metadata || meta, {
    attempts,
    sonic_order_id: order.order_id,
    reference: order.reference,
    initial_status: order.payment_status,
    last_error: undefined,
  });
  try {
    await withDbRetry(() =>
      db().paymentTransaction.updateMany({
        where: { id: rowId, status: { not: 'completed' } },
        data: {
          status: 'pending',
          method: existing.method || 'Mobile Money',
          metadata: nextMeta,
        },
      })
    );
  } catch (err) {
    // The PIN was already sent. Keep the in-memory link so status polls can
    // confirm it, and do not tell the user the push failed.
    console.error('payment dispatch: push sent but status update failed', existing.orderId, err);
  }
  return { ok: true, dispatched: true };
}

function scheduleDispatch(row) {
  dispatcher.enqueue({
    id: row.id,
    execute: () => executePush(row.id),
  });
}

/**
 * Accept a checkout. Creates one queued payment, dedupes repeats, and waits
 * only briefly when many pushes are already ahead.
 */
async function enqueuePaymentPush(input) {
  if (dispatcher.waiting >= MAX_WAITING) {
    const error = new Error(
      'Malipo mengi yanaendelea kutumwa. Subiri sekunde chache kisha jaribu tena — PIN yako itatumwa.'
    );
    error.status = 503;
    throw error;
  }

  const reusable = await findReusable(input);
  const decision = reuseDecision(reusable);
  if (reusable && decision === 'already_sent') {
    return presentPayment(reusable, { queued: false });
  }
  if (reusable && decision === 'join') {
    const waiter = dispatcher.waitFor(reusable.id, waitBudget());
    scheduleDispatch(reusable);
    const result = await waiter;
    if (result?.failed) {
      const error = new Error(mapSonicInitiateError(result.error, input.phone));
      error.status = 502;
      throw error;
    }
    const fresh = await db().paymentTransaction.findUnique({ where: { id: reusable.id } });
    const tx = fresh || reusable;
    return presentPayment(tx, { queued: tx.status === 'queued' || tx.status === 'dispatching' || !result?.ok });
  }

  await withDbRetry(() =>
    db().device.upsert({
      where: { deviceId: input.deviceId },
      update: { name: input.userName, phone: input.phone || undefined },
      create: { deviceId: input.deviceId, name: input.userName, phone: input.phone || '' },
    })
  );

  const orderId = `q_${randomUUID().replace(/-/g, '')}`;
  const tx = await withDbRetry(() =>
    db().paymentTransaction.create({
      data: {
        orderId,
        deviceId: input.deviceId,
        userName: input.userName,
        phone: input.phone,
        planId: input.planId,
        planName: input.planName || '',
        amount: input.amount,
        method: input.method || 'Mobile Money',
        status: 'queued',
        metadata: {
          intent: true,
          attempts: 0,
          buyer_email: input.buyerEmail,
          buyer_name: input.userName,
          buyer_phone: input.buyerPhone,
          network: input.network,
          planDays: input.planDays,
        },
      },
    })
  );

  const waiter = dispatcher.waitFor(tx.id, waitBudget());
  scheduleDispatch(tx);
  const result = await waiter;
  if (result?.failed) {
    const error = new Error(mapSonicInitiateError(result.error, input.phone));
    error.status = 502;
    throw error;
  }
  const fresh = await db().paymentTransaction.findUnique({ where: { id: tx.id } });
  const current = fresh || tx;
  const stillQueued = !result?.ok || current.status === 'queued' || current.status === 'dispatching';
  return presentPayment(current, { queued: stillQueued });
}

function waitBudget() {
  const ahead = dispatcher.waiting + dispatcher.active;
  if (ahead <= 2) return 26_000;
  if (ahead <= 8) return 10_000;
  return 1_200;
}

async function findPaymentByOrderRef(orderId) {
  const id = String(orderId || '').trim();
  if (!id) return null;
  const direct = await db().paymentTransaction.findUnique({ where: { orderId: id } });
  if (direct) return direct;
  const local = localBySonic.get(id);
  if (local) {
    const linked = await db().paymentTransaction.findUnique({ where: { orderId: local } });
    if (linked) return linked;
  }
  if (id.startsWith('q_') || id.startsWith('local-')) return null;
  return db().paymentTransaction.findFirst({
    where: { metadata: { path: ['sonic_order_id'], equals: id } },
  });
}

/**
 * Webhook can arrive before we store Sonic's order id. Attach it to the
 * in-flight push for that phone so we do not create a second payment.
 */
async function attachInflightSonicOrder({ sonicOrderId, phone, amount }) {
  const sonic = String(sonicOrderId || '').trim();
  const localPhone = toLocalTzPhone(phone) || String(phone || '').trim();
  if (!sonic || !localPhone) return null;

  const rows = await db().paymentTransaction.findMany({
    where: {
      phone: localPhone,
      status: { in: ['queued', 'dispatching', 'pending'] },
      createdAt: { gt: new Date(Date.now() - 20 * 60 * 1000) },
      ...(Number(amount) > 0 ? { amount: Math.round(Number(amount)) } : {}),
    },
    orderBy: { createdAt: 'asc' },
    take: 6,
  });
  // Only a push already in flight (or this exact Sonic id). A still-queued
  // checkout has not been sent yet, so it must not absorb another payment.
  const target =
    rows.find((row) => providerOrderId(row) === sonic) ||
    rows.find((row) => row.status === 'dispatching' && !providerOrderId(row));
  if (!target) return null;
  if (providerOrderId(target) === sonic) return target;

  rememberSonicLink(target.orderId, sonic);
  return db().paymentTransaction.update({
    where: { id: target.id },
    data: {
      metadata: mergeMeta(target.metadata, {
        sonic_order_id: sonic,
        sonic_attached_by: 'webhook',
      }),
    },
  });
}

let _started = false;

async function resumeQueuedPayments() {
  const rows = await db().paymentTransaction.findMany({
    where: { status: { in: ['queued', 'dispatching'] }, amount: { gt: 0 } },
    orderBy: { createdAt: 'asc' },
    take: 500,
  });
  if (!rows.length) return;
  console.log(`payment dispatch: resuming ${rows.length} PIN push(es)`);
  for (const row of rows) {
    if (row.status === 'dispatching') {
      await db().paymentTransaction.update({
        where: { id: row.id },
        data: { status: 'queued' },
      });
    }
    scheduleDispatch({ ...row, status: 'queued' });
  }
}

const acceptInflight = new Map();

/** One in-flight checkout per device + phone + plan, so a double tap cannot send two PINs. */
function acceptPaymentPush(input) {
  const key = [input.deviceId, input.phone, input.planId, input.amount].join('|');
  const current = acceptInflight.get(key);
  if (current) return current;

  const run = enqueuePaymentPush(input);
  acceptInflight.set(key, run);
  return run.then(
    (value) => {
      setTimeout(() => {
        if (acceptInflight.get(key) === run) acceptInflight.delete(key);
      }, 4_000);
      return value;
    },
    (err) => {
      if (acceptInflight.get(key) === run) acceptInflight.delete(key);
      throw err;
    }
  );
}

function startPaymentDispatcher() {
  if (_started) return;
  _started = true;
  resumeQueuedPayments().catch((err) => console.error('payment dispatch resume failed', err));
  const timer = setInterval(() => {
    if (!dispatcher.paused && dispatcher.waiting > 0 && dispatcher.active === 0) {
      console.warn('payment dispatch: queue was idle with waiters — check pump');
    }
  }, 30_000);
  if (typeof timer.unref === 'function') timer.unref();
}

function shouldDeferStatus() {
  return dispatcher.shouldDeferStatus();
}

function noteStatusCheck() {
  dispatcher.noteStatusCheck();
}

function getDispatchPressure() {
  return {
    waiting: dispatcher.waiting,
    active: dispatcher.active,
    paused: dispatcher.paused,
  };
}

module.exports = {
  createPaymentDispatcher,
  retryBudget,
  retryDelayMs,
  reuseDecision,
  providerOrderId,
  queuedMessage,
  acceptPaymentPush,
  findPaymentByOrderRef,
  attachInflightSonicOrder,
  startPaymentDispatcher,
  shouldDeferStatus,
  noteStatusCheck,
  getDispatchPressure,
  scheduleDispatch,
};

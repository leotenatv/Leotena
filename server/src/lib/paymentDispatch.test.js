/**
 * Queue behaviour for PIN pushes under a rush.
 * Run: node src/lib/paymentDispatch.test.js
 */
if (!process.env.DATABASE_URL) {
  process.env.DATABASE_URL = 'postgresql://127.0.0.1:5432/leotena';
}
const {
  createPaymentDispatcher,
  retryBudget,
  reuseDecision,
} = require('./paymentDispatch');

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function testConcurrency() {
  const d = createPaymentDispatcher({ concurrency: 2, maxConcurrency: 2, gapMs: 0, log: () => {} });
  let active = 0;
  let maxActive = 0;
  const waits = [];
  for (let i = 0; i < 12; i++) {
    const id = `job-${i}`;
    d.enqueue({
      id,
      execute: async () => {
        active += 1;
        maxActive = Math.max(maxActive, active);
        await sleep(25);
        active -= 1;
        return { ok: true, id };
      },
    });
    waits.push(d.waitFor(id, 5000));
  }
  const results = await Promise.all(waits);
  assert(results.every((r) => r.ok), 'every push should complete');
  assert(maxActive <= 2, `concurrency cap exceeded: ${maxActive}`);
  assert(d.waiting === 0 && d.active === 0, 'queue should drain');
}

async function testRateLimitRetry() {
  const d = createPaymentDispatcher({
    concurrency: 2,
    maxConcurrency: 2,
    gapMs: 0,
    rateLimitPauseMs: 30,
    log: () => {},
  });
  let calls = 0;
  d.enqueue({
    id: 'rate',
    execute: async () => {
      calls += 1;
      if (calls < 3) {
        return { retry: true, rateLimited: true, delayMs: 15, error: 'too many attempts' };
      }
      return { ok: true };
    },
  });
  const result = await d.waitFor('rate', 4000);
  assert(result.ok, 'rate-limited push should succeed after retry');
  assert(calls === 3, `expected 3 attempts, got ${calls}`);
}

async function testDuplicateJoin() {
  const d = createPaymentDispatcher({ concurrency: 1, maxConcurrency: 1, gapMs: 0, log: () => {} });
  let calls = 0;
  const job = {
    id: 'same',
    execute: async () => {
      calls += 1;
      await sleep(40);
      return { ok: true };
    },
  };
  assert(d.enqueue(job) === true, 'first enqueue');
  assert(d.enqueue({ ...job }) === false, 'duplicate enqueue must not start a second push');
  const result = await d.waitFor('same', 2000);
  assert(result.ok, 'joined push completes');
  assert(calls === 1, `duplicate sent ${calls} pushes`);
}

async function testDeferWhileQueued() {
  const d = createPaymentDispatcher({ concurrency: 1, maxConcurrency: 1, gapMs: 0, log: () => {} });
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  for (let i = 0; i < 6; i++) {
    d.enqueue({
      id: `block-${i}`,
      execute: () => gate.then(() => ({ ok: true })),
    });
  }
  await sleep(30);
  assert(d.shouldDeferStatus(), 'status polls should yield while a rush is queued');
  release();
  await Promise.all(
    Array.from({ length: 6 }, (_, i) => d.waitFor(`block-${i}`, 4000))
  );
  assert(!d.shouldDeferStatus(), 'status polls resume after the queue drains');
}

function testBudgets() {
  assert(retryBudget('too many attempts', false) === 8, 'rate limit budget');
  assert(retryBudget('SonicPesa request timed out', false) === 2, 'timeout budget');
  assert(retryBudget('wrong credential 9003', false) === 0, 'hard errors are not retried');
  assert(reuseDecision(null) === 'create', 'missing row creates');
  assert(
    reuseDecision({ status: 'queued', createdAt: new Date() }) === 'join',
    'in-flight push is reused'
  );
  assert(
    reuseDecision({
      status: 'pending',
      orderId: 'sp_1',
      createdAt: new Date(),
      metadata: { sonic_order_id: 'sp_1' },
    }) === 'already_sent',
    'fresh PIN is not sent again'
  );
  assert(
    reuseDecision({
      status: 'pending',
      orderId: 'sp_old',
      createdAt: new Date(Date.now() - 3 * 60 * 1000),
      metadata: { sonic_order_id: 'sp_old' },
    }) === 'create',
    'expired PIN can be sent again'
  );
}

async function main() {
  testBudgets();
  await testConcurrency();
  await testRateLimitRetry();
  await testDuplicateJoin();
  await testDeferWhileQueued();
  console.log('ok — payment dispatch queue tests passed');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

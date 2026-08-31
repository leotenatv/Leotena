/**
 * Regression checks for SonicPesa status parsing.
 * Run: node src/lib/sonicpesa.status.test.js
 */
const { isSonicpesaFailure, isSonicpesaSuccess, readPaymentStatus, readWebhookPaymentFields } = require('./sonicpesa');

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

const cases = [
  {
    name: 'nested data.status success (API envelope + paid)',
    raw: { status: 'success', data: { status: 'success', order_id: 'sp_1', amount: 25000 } },
    expect: 'SUCCESS',
  },
  {
    name: 'top-level status success with order context',
    raw: { status: 'success', order_id: 'sp_1', amount: 25000 },
    expect: 'SUCCESS',
  },
  {
    name: 'payment_status SUCCESS preferred',
    raw: { status: 'success', payment_status: 'SUCCESS', order_id: 'sp_1' },
    expect: 'SUCCESS',
  },
  {
    name: 'order_status completed',
    raw: { status: 'success', data: { order_status: 'completed', order_id: 'sp_1' } },
    expect: 'COMPLETED',
  },
  {
    name: 'nested failed is payment failure not API error',
    raw: { status: 'success', data: { status: 'failed', order_id: 'sp_1', amount: 1000 } },
    expect: 'FAILED',
  },
  {
    name: 'pending stays pending',
    raw: { status: 'success', data: { status: 'pending', order_id: 'sp_1' } },
    expect: 'PENDING',
  },
  {
    name: 'bare transport success without order → pending',
    raw: { status: 'success' },
    expect: 'PENDING',
  },
  {
    name: 'transaction.status SUCCESS when data omits payment_status',
    raw: {
      status: 'success',
      data: { order_id: 'sp_1', amount: 2000 },
      transaction: { order_id: 'sp_1', status: 'SUCCESS', amount: '2000.00' },
    },
    expect: 'SUCCESS',
  },
  {
    name: 'webhook nested transaction.status SUCCESS',
    raw: {
      event: 'payment.completed',
      data: { order_id: 'sp_wh_1', amount: 5000 },
      transaction: { status: 'SUCCESS' },
    },
    expect: 'SUCCESS',
  },
  {
    name: 'webhook order_status_data completed',
    raw: {
      event: 'payment.success',
      data: { order_status_data: { order_status: 'completed', order_id: 'sp_wh_2' } },
    },
    expect: 'COMPLETED',
  },
];

for (const c of cases) {
  const got = readPaymentStatus(c.raw);
  assert(got === c.expect, `${c.name}: expected ${c.expect}, got ${got}`);
}

assert(isSonicpesaSuccess(readPaymentStatus(cases[0].raw)), 'success detected');
assert(isSonicpesaFailure(readPaymentStatus(cases[4].raw)), 'failure detected');
assert(isSonicpesaSuccess('SUCCESSFUL'), 'SUCCESSFUL is paid');
assert(isSonicpesaSuccess('SETTLED'), 'SETTLED is paid');
assert(isSonicpesaSuccess(readPaymentStatus(cases[cases.length - 3].raw)), 'transaction.status success');

const webhookCases = [
  {
    name: 'webhook fields from nested transaction',
    raw: cases[cases.length - 2].raw,
    expectStatus: 'SUCCESS',
    expectOrder: 'sp_wh_1',
  },
  {
    name: 'webhook fields from order_status_data',
    raw: cases[cases.length - 1].raw,
    expectStatus: 'COMPLETED',
    expectOrder: 'sp_wh_2',
  },
];

for (const c of webhookCases) {
  const got = readWebhookPaymentFields(c.raw);
  assert(got.status === c.expectStatus, `${c.name}: expected status ${c.expectStatus}, got ${got.status}`);
  assert(got.orderId === c.expectOrder, `${c.name}: expected order ${c.expectOrder}, got ${got.orderId}`);
}

console.log(`ok — ${cases.length} sonicpesa status cases + ${webhookCases.length} webhook cases passed`);

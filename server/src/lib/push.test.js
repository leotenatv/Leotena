/**
 * Partner push helpers.
 * Run: node src/lib/push.test.js
 */
const { normalizeTarget, topicForTarget } = require('./push');
const { secretsEqual } = require('../routes/partner.routes');

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

assert(normalizeTarget('premium') === 'premium', 'premium target');
assert(normalizeTarget('FREE') === 'free', 'free target');
assert(normalizeTarget('') === 'all', 'empty target is all');
assert(normalizeTarget('everyone') === 'all', 'unknown target is all');
assert(topicForTarget('all') === 'leotena_all_users', 'all topic');
assert(topicForTarget('premium') === 'leotena_premium_users', 'premium topic');
assert(topicForTarget('free') === 'leotena_free_users', 'free topic');

assert(secretsEqual('abc', 'abc') === true, 'matching secrets');
assert(secretsEqual('abc', 'abd') === false, 'mismatch secrets');
assert(secretsEqual('', 'abc') === false, 'empty provided');
assert(secretsEqual('abc', '') === false, 'empty expected');
assert(secretsEqual('ab', 'abc') === false, 'length mismatch');

console.log('push.test.js ok');

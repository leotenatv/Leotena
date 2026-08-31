const DEFAULT_BASE = 'https://api.sonicpesa.com';
const SONICPESA_TIMEOUT_MS = 28_000;
/** Outer transport OK only — never treat payment terminal states as "not a status". */
const API_TRANSPORT_OK = new Set(['ok']);

function sonicHeaders() {
  const h = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    'X-API-KEY': process.env.SONICPESA_API_KEY || '',
  };
  const secret =
    process.env.SONICPESA_SECRET_KEY ||
    process.env.SONICPESA_API_SECRET ||
    process.env.SONICPESA_SECRETE_KEY ||
    '';
  // Sonic dashboard / error text: some accounts expect X-SECRET-KEY.
  if (secret.trim()) h['X-SECRET-KEY'] = secret.trim();
  return h;
}

/** Short cache so aggressive app polling does not burn Sonic rate limits. */
const ORDER_STATUS_CACHE_TTL_MS = 6_000;
const _orderStatusCache = new Map();

function isSonicpesaRateLimited(errorOrMessage) {
  const s = String(errorOrMessage || '').toLowerCase();
  return s.includes('too many attempts') || s.includes('too many requests') || s.includes('rate limit');
}

function sonicpesaConfigured() {
  return Boolean((process.env.SONICPESA_API_KEY || '').trim());
}

/** Local `07…` / `06…` or `255…` → `2557XXXXXXXX` / `2556XXXXXXXX`. */
function normalizeTzPhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (!digits) return null;

  while (digits.startsWith('255') && digits.length > 9) {
    digits = digits.slice(3);
  }
  while (digits.startsWith('0')) {
    digits = digits.slice(1);
  }

  if (digits.length !== 9 || !/^[67]\d{8}$/.test(digits)) return null;
  return `255${digits}`;
}

/** National `0XXXXXXXXX` for DB / display. */
function toLocalTzPhone(raw) {
  const intl = normalizeTzPhone(raw);
  if (!intl || !intl.startsWith('255') || intl.length !== 12) return null;
  return `0${intl.slice(3)}`;
}

function normalizePaymentStatus(raw) {
  return String(raw ?? '')
    .trim()
    .toUpperCase()
    .replace(/[\s_-]+/g, '');
}

function isSonicpesaSuccess(status) {
  const s = normalizePaymentStatus(status);
  return (
    s === 'SUCCESS' ||
    s === 'SUCCESSFUL' ||
    s === 'COMPLETED' ||
    s === 'COMPLETE' ||
    s === 'PAID' ||
    s === 'DONE' ||
    s === 'SETTLED' ||
    s === 'TXNSUCCESS' ||
    s === 'PAYMENTSUCCESS' ||
    s === 'CONFIRMED'
  );
}

function isSonicpesaFailure(status) {
  const s = normalizePaymentStatus(status);
  return (
    s === 'CANCELLED' ||
    s === 'CANCELED' ||
    s === 'USERCANCELLED' ||
    s === 'USERCANCELED' ||
    s === 'REJECTED' ||
    s === 'FAILED' ||
    s === 'FAILURE' ||
    s === 'EXPIRED' ||
    s === 'DECLINED' ||
    s === 'TIMEOUT' ||
    s === 'TIMEDOUT' ||
    s === 'ERROR'
  );
}

function asRecord(value) {
  return value && typeof value === 'object' && !Array.isArray(value) ? value : null;
}

/** SonicPesa wraps order fields in `data` (and sometimes `order_status_data`). */
function unwrapSonicpesaBody(raw) {
  const fromData = asRecord(raw.data);
  const osd = asRecord(fromData?.order_status_data ?? raw.order_status_data);
  return { ...raw, ...(fromData || {}), ...(osd || {}) };
}

/**
 * API-level rejection (bad key, validation) — NOT payment FAILED/SUCCESS.
 * Payment terminal states must flow through readPaymentStatus / isSonicpesaSuccess.
 */
function sonicpesaApiError(raw, httpStatus) {
  if (httpStatus >= 400) {
    return String(raw.error ?? raw.message ?? `SonicPesa HTTP ${httpStatus}`).trim();
  }

  const topStatus = String(raw.status ?? '')
    .trim()
    .toLowerCase();
  if (topStatus !== 'error') return undefined;

  const data = asRecord(raw.data);
  const hasOrderContext = Boolean(
    raw.order_id ||
      raw.orderId ||
      raw.payment_status ||
      raw.order_status ||
      (data && (data.order_id || data.orderId || data.payment_status || data.status))
  );
  if (hasOrderContext) return undefined;

  return String(raw.message ?? raw.error ?? 'SonicPesa rejected the request').trim();
}

function readOrderId(body) {
  return String(body.order_id ?? body.orderId ?? body.id ?? '').trim();
}

function firstNonEmpty(...values) {
  for (const v of values) {
    if (v == null) continue;
    const s = String(v).trim();
    if (s) return s;
  }
  return undefined;
}

function readBuyerPhone(body) {
  return String(
    body.buyer_phone ?? body.buyerPhone ?? body.phone ?? body.customer_phone ?? body.msisdn ?? ''
  ).trim();
}

/**
 * Extract payment status from SonicPesa create_order / order_status payloads.
 *
 * Critical: SonicPesa uses `status: "success"` for BOTH the API envelope and a paid order.
 * Older code treated any "success"/"failed" as envelope-only and defaulted to PENDING, so
 * successful payments never upgraded accounts when the webhook was missing.
 */
function readPaymentStatus(raw) {
  const fromData = asRecord(raw.data);
  const fromTxn = asRecord(raw.transaction);
  const fromOsd = asRecord(fromData?.order_status_data ?? raw.order_status_data);
  const body = unwrapSonicpesaBody(raw);

  const explicit = firstNonEmpty(
    body.payment_status,
    body.order_status,
    body.transaction_status,
    body.txn_status,
    fromTxn?.payment_status,
    fromTxn?.status,
    fromOsd?.payment_status,
    fromOsd?.order_status,
    fromData?.payment_status,
    fromData?.order_status
  );
  if (explicit) return normalizePaymentStatus(explicit);

  const nestedStatus = firstNonEmpty(fromOsd?.status, fromData?.status);
  if (nestedStatus) {
    const n = normalizePaymentStatus(nestedStatus);
    if (n !== 'OK') return n;
  }

  const top = firstNonEmpty(raw.status);
  if (top) {
    const lower = top.toLowerCase();
    if (API_TRANSPORT_OK.has(lower)) return 'PENDING';

    const hasOrderContext = Boolean(
      body.order_id ||
        body.orderId ||
        body.amount != null ||
        body.reference ||
        body.buyer_phone ||
        body.buyerPhone ||
        fromData ||
        fromTxn
    );

    if ((lower === 'success' || lower === 'error') && !hasOrderContext) {
      return 'PENDING';
    }

    return normalizePaymentStatus(top);
  }

  return 'PENDING';
}

/** Normalize webhook JSON (top-level or nested `data` / `transaction`). */
function readWebhookPaymentFields(b) {
  const nested = asRecord(b.data);
  const txn = asRecord(b.transaction);
  const osd = asRecord(nested?.order_status_data ?? b.order_status_data);
  const body = unwrapSonicpesaBody(b);
  const status = readPaymentStatus(b);
  return {
    status,
    event: String(b.event ?? nested?.event ?? txn?.event ?? '')
      .trim()
      .toLowerCase(),
    orderId: String(
      body.order_id ?? body.orderId ?? b.order_id ?? b.orderId ?? nested?.order_id ?? nested?.orderId ?? ''
    ).trim(),
    transid: String(
      b.transid ?? b.transaction_id ?? txn?.transid ?? nested?.transid ?? ''
    ).trim(),
    phone: String(
      body.buyer_phone ??
        body.buyerPhone ??
        body.phone ??
        b.buyer_phone ??
        b.buyerPhone ??
        b.phone ??
        b.customer_phone ??
        b.msisdn ??
        nested?.buyer_phone ??
        nested?.phone ??
        txn?.buyer_phone ??
        ''
    ).trim(),
    amount: Number(body.amount ?? b.amount ?? nested?.amount ?? txn?.amount ?? 0),
  };
}

async function sonicpesaPost(path, payload) {
  const base = (process.env.SONICPESA_BASE_URL || DEFAULT_BASE).replace(/\/+$/, '');
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), SONICPESA_TIMEOUT_MS);
  try {
    const res = await fetch(`${base}${path}`, {
      method: 'POST',
      headers: sonicHeaders(),
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });
    const raw = (await res.json().catch(() => ({}))) || {};
    return { ok: true, res, raw };
  } catch (e) {
    const name = e instanceof Error ? e.name : '';
    if (name === 'TimeoutError' || name === 'AbortError') {
      return { ok: false, error: 'SonicPesa request timed out' };
    }
    return { ok: false, error: 'SonicPesa is unreachable' };
  } finally {
    clearTimeout(timer);
  }
}

async function sonicpesaCreateOrder(input) {
  const posted = await sonicpesaPost('/api/v1/payment/create_order', input);
  if (!posted.ok) return { ok: false, error: posted.error };

  const { res, raw } = posted;
  const apiError = sonicpesaApiError(raw, res.status);
  if (apiError && !res.ok) return { ok: false, error: apiError, raw };
  if (!res.ok) {
    return { ok: false, error: apiError || `SonicPesa HTTP ${res.status}`, raw };
  }

  const body = unwrapSonicpesaBody(raw);
  const orderId = readOrderId(body);
  const paymentStatus = readPaymentStatus(raw);
  const wrappedError = sonicpesaApiError(raw, 0);

  return {
    ok: Boolean(orderId) && !wrappedError,
    order_id: orderId || undefined,
    reference: String(body.reference ?? body.ref ?? '').trim() || undefined,
    payment_status: paymentStatus,
    status: paymentStatus,
    amount: Number(body.amount ?? input.amount),
    currency: String(body.currency ?? input.currency),
    buyer_phone: readBuyerPhone(body) || undefined,
    error: orderId && !wrappedError ? undefined : wrappedError || 'SonicPesa did not return an order id',
    raw,
  };
}

async function sonicpesaOrderStatus(orderId) {
  const id = String(orderId || '').trim();
  if (!id) return { ok: false, error: 'order_id is required' };

  const cached = _orderStatusCache.get(id);
  if (cached && Date.now() - cached.at < ORDER_STATUS_CACHE_TTL_MS) {
    return { ...cached.value, cached: true };
  }

  const posted = await sonicpesaPost('/api/v1/payment/order_status', { order_id: id });
  if (!posted.ok) {
    return { ok: false, error: posted.error, rate_limited: isSonicpesaRateLimited(posted.error) };
  }

  const { res, raw } = posted;
  const apiError = sonicpesaApiError(raw, res.status);
  if (!res.ok) {
    const err = apiError || `SonicPesa HTTP ${res.status}`;
    return { ok: false, error: err, rate_limited: isSonicpesaRateLimited(err) || res.status === 429, raw };
  }
  if (apiError) {
    return { ok: false, error: apiError, rate_limited: isSonicpesaRateLimited(apiError), raw };
  }

  const body = unwrapSonicpesaBody(raw);
  const paymentStatus = readPaymentStatus(raw);
  const value = {
    ok: true,
    order_id: readOrderId(body) || id,
    payment_status: paymentStatus,
    status: paymentStatus,
    reference: String(body.reference ?? '').trim() || undefined,
    amount: body.amount != null ? Number(body.amount) : undefined,
    currency: body.currency != null ? String(body.currency) : undefined,
    buyer_phone: readBuyerPhone(body) || readBuyerPhone(asRecord(raw.transaction) || {}) || undefined,
    raw,
  };
  _orderStatusCache.set(id, { at: Date.now(), value });
  // Bound cache size (aggressive multi-device polling).
  if (_orderStatusCache.size > 400) {
    const first = _orderStatusCache.keys().next().value;
    if (first) _orderStatusCache.delete(first);
  }
  return value;
}

module.exports = {
  sonicpesaConfigured,
  normalizeTzPhone,
  toLocalTzPhone,
  normalizePaymentStatus,
  isSonicpesaSuccess,
  isSonicpesaFailure,
  isSonicpesaRateLimited,
  readPaymentStatus,
  readWebhookPaymentFields,
  sonicpesaCreateOrder,
  sonicpesaOrderStatus,
};

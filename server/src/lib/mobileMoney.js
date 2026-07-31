/** Tanzania mobile-money network from national `0XXXXXXXXX` phone.
 * Prefixes follow TCRA numbering (portability possible; used for UX prompts).
 */

function detectTzMobileNetwork(localPhone) {
  const digits = String(localPhone || '').replace(/\D/g, '');
  let local = digits;
  if (local.startsWith('255') && local.length >= 12) {
    local = `0${local.slice(3, 12)}`;
  } else if (local.length === 9 && /^[67]/.test(local)) {
    local = `0${local}`;
  }
  if (!/^0[67]\d{8}$/.test(local)) return 'unknown';

  const prefix = local.slice(0, 3);
  // Halotel (Viettel) — HaloPesa
  if (['061', '062', '063'].includes(prefix)) return 'halotel';
  // Yas (formerly Tigo) — Mixx
  if (['065', '067', '071', '077'].includes(prefix)) return 'tigo';
  // Airtel Money
  if (['068', '069', '078'].includes(prefix)) return 'airtel';
  // Vodacom — M-Pesa
  if (['074', '075', '076', '079'].includes(prefix)) return 'mpesa';
  // TTCL / Smile / other 06–07 → generic fallbacks
  if (local.startsWith('06')) return 'halotel';
  if (local.startsWith('07')) return 'mpesa';
  return 'unknown';
}

function mobileMoneyMethodLabel(network) {
  switch (network) {
    case 'mpesa':
      return 'M-Pesa';
    case 'airtel':
      return 'Airtel Money';
    case 'tigo':
      return 'Mixx by Yas';
    case 'halotel':
      return 'HaloPesa';
    default:
      return 'Mobile Money';
  }
}

function paymentPromptForPhone(localPhone) {
  const network = detectTzMobileNetwork(localPhone);
  switch (network) {
    case 'mpesa':
      return 'Angalia simu yako — thibitisha PIN ya M-Pesa.';
    case 'airtel':
      return 'Angalia simu yako — thibitisha PIN ya Airtel Money.';
    case 'tigo':
      return 'Angalia simu yako — thibitisha PIN ya Mixx by Yas.';
    case 'halotel':
      return 'Angalia simu yako — thibitisha PIN ya HaloPesa.';
    default:
      return 'Angalia simu yako — thibitisha PIN (M-Pesa, Mixx, Airtel Money, HaloPesa).';
  }
}

/** Map SonicPesa initiate failures to clear Swahili (esp. HaloPesa credential gaps). */
function mapSonicInitiateError(rawError, localPhone) {
  const msg = String(rawError || '').toLowerCase();
  const network = detectTzMobileNetwork(localPhone);

  if (msg.includes('9003') || msg.includes('wrong credential')) {
    if (network === 'halotel') {
      return 'Malipo ya Halotel (HaloPesa) hayajasanidi kwenye akaunti ya SonicPesa. Wasiliana na SonicPesa kuwezesha HaloPesa, au tumia M-Pesa / Mixx / Airtel.';
    }
    return 'Huduma ya malipo ya mtandao huu haijasanidi kikamilifu kwenye SonicPesa. Jaribu namba ya mtandao mwingine au wasiliana na msaada.';
  }
  if (msg.includes('unreachable') || msg.includes('timed out')) {
    return 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.';
  }
  return 'Imeshindikana kuanzisha malipo. Hakikisha namba ya simu ni sahihi na jaribu tena.';
}

module.exports = {
  detectTzMobileNetwork,
  mobileMoneyMethodLabel,
  paymentPromptForPhone,
  mapSonicInitiateError,
};

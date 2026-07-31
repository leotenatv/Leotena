import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'payment_config.dart';

/// SonicPesa payment flow via Leotena API (keys stay on server).
class SonicpesaPaymentService {
  SonicpesaPaymentService({String? apiBase})
      : baseUrl = (apiBase ?? ApiClient.baseUrl).replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  Future<SonicpesaInitiateResult> initiate({
    required String deviceId,
    required String userName,
    required String phone,
    required String planId,
  }) async {
    final localPhone = PaymentConfig.normalizeTzLocalPhone(phone) ?? phone.trim();
    final res = await http
        .post(
          Uri.parse('$baseUrl/payments/sonicpesa/initiate'),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'userName': userName,
            'phone': localPhone,
            'planId': planId,
          }),
        )
        .timeout(const Duration(seconds: 35));

    final map = _decode(res);
    if (res.statusCode == 500) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode,
            fallback: 'Seva ya malipo ina hitilafu. Jaribu tena baada ya dakika moja.'),
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode == 502) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode,
            fallback: 'Malipo yameanzishwa lakini hayajakamilika kwenye programu. Jaribu tena.'),
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode == 503) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode,
            fallback: 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.'),
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode, fallback: 'Imeshindikana kuanzisha malipo. Jaribu tena.'),
        statusCode: res.statusCode,
      );
    }
    final orderId = (map['orderId'] as String?)?.trim() ?? (map['order_id'] as String?)?.trim() ?? '';
    if (orderId.isEmpty) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode, fallback: 'Imeshindikana kuanzisha malipo. Jaribu tena.'),
      );
    }
    return SonicpesaInitiateResult(
      orderId: orderId,
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      message: (map['message'] as String?)?.trim() ?? PaymentConfig.paymentPromptFor(localPhone),
      completed: map['completed'] == true,
      local: map['local'] == true,
      premiumUntil: _parsePremiumUntil(map['premiumUntil'] ?? map['premium_until']),
      deviceJson: map['device'] is Map<String, dynamic> ? map['device'] as Map<String, dynamic> : null,
    );
  }

  Future<SonicpesaStatusResult> checkStatus({
    required String deviceId,
    required String orderId,
    String? userName,
    String? phone,
  }) async {
    final localPhone = phone != null && phone.isNotEmpty
        ? (PaymentConfig.normalizeTzLocalPhone(phone) ?? phone.trim())
        : null;
    final res = await http
        .post(
          Uri.parse('$baseUrl/payments/sonicpesa/status'),
          headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({
            'deviceId': deviceId,
            'orderId': orderId,
            if (userName != null && userName.isNotEmpty) 'userName': userName,
            if (localPhone != null && localPhone.isNotEmpty) 'phone': localPhone,
          }),
        )
        .timeout(const Duration(seconds: 25));

    final map = _decode(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SonicpesaPaymentException(
        _userFacingMessage(map, res.statusCode, fallback: 'Imeshindikana kuangalia hali ya malipo.'),
        statusCode: res.statusCode,
      );
    }

    final status = (map['paymentStatus'] as String?)?.trim().toUpperCase() ??
        (map['payment_status'] as String?)?.trim().toUpperCase() ??
        'PENDING';
    final completed = map['completed'] == true;
    final failed = map['failed'] == true;
    final premiumUntil = _parsePremiumUntil(map['premiumUntil'] ?? map['premium_until']);

    return SonicpesaStatusResult(
      paymentStatus: status,
      completed: completed,
      failed: failed,
      pending: map['pending'] == true || (!completed && !failed),
      premiumUntil: premiumUntil,
      message: (map['message'] as String?)?.trim(),
      deviceJson: map['device'] is Map<String, dynamic> ? map['device'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'error': res.body};
    }
  }

  String _userFacingMessage(Map<String, dynamic> map, int? statusCode, {required String fallback}) {
    final raw = _rawServerMessage(map);
    if (raw == null) {
      if (statusCode == 500 || statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.';
      }
      return fallback;
    }
    final lower = raw.toLowerCase();
    if (lower.contains('internal server error') ||
        lower.contains('fetch failed') ||
        lower.contains('unreachable') ||
        lower.contains('timed out')) {
      return 'Seva ya malipo haipatikani kwa sasa. Jaribu tena baada ya dakika moja.';
    }
    if (lower.contains('9003') || lower.contains('wrong credential') || lower.contains('halopesa') || lower.contains('halotel')) {
      return raw.contains('SonicPesa') || raw.contains('HaloPesa') || raw.contains('Halotel')
          ? raw
          : 'Malipo ya Halotel (HaloPesa) hayajasanidi kwenye akaunti ya SonicPesa. Tumia M-Pesa / Mixx / Airtel au wasiliana na SonicPesa.';
    }
    if (lower.contains('order') || lower.contains('sonicpesa')) {
      return 'Imeshindikana kuanzisha malipo. Hakikisha namba ya simu ni sahihi na jaribu tena.';
    }
    if (lower.contains('not configured')) {
      return 'Malipo hayajasanidi kwenye seva. Wasiliana na msaada.';
    }
    if (lower.contains('device') || lower.contains('plan')) {
      return 'Taarifa za malipo hazikamilika. Funga na fungua programu, kisha jaribu tena.';
    }
    if (lower.contains('phone') || lower.contains('tanzanian') || lower.contains('10 digits') || lower.contains('namba')) {
      return 'Weka namba ya simu sahihi: 07…, 06… (Halotel 061/062/063/069), au 255…';
    }
    if (lower.contains('plan not found') || lower.contains('not available')) {
      return 'Mpango uliyochagua haupatikani. Chagua mpango mwingine.';
    }
    if (RegExp(r'\b(4\d{2}|5\d{2})\b').hasMatch(raw) || raw.length > 120) {
      return fallback;
    }
    return raw;
  }

  String? _rawServerMessage(Map<String, dynamic> map) {
    for (final key in ['error', 'message']) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  DateTime? _parsePremiumUntil(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final ms = int.tryParse(s);
    if (ms != null && ms > 100000000000) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.tryParse(s);
  }
}

class SonicpesaInitiateResult {
  const SonicpesaInitiateResult({
    required this.orderId,
    required this.amount,
    required this.message,
    this.completed = false,
    this.local = false,
    this.premiumUntil,
    this.deviceJson,
  });

  final String orderId;
  final int amount;
  final String message;
  final bool completed;
  final bool local;
  final DateTime? premiumUntil;
  final Map<String, dynamic>? deviceJson;
}

class SonicpesaStatusResult {
  const SonicpesaStatusResult({
    required this.paymentStatus,
    required this.completed,
    required this.failed,
    required this.pending,
    this.premiumUntil,
    this.message,
    this.deviceJson,
  });

  final String paymentStatus;
  final bool completed;
  final bool failed;
  final bool pending;
  final DateTime? premiumUntil;
  final String? message;
  final Map<String, dynamic>? deviceJson;
}

class SonicpesaPaymentException implements Exception {
  SonicpesaPaymentException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

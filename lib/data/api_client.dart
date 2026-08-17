import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Thin wrapper over `http` for the consumer app — no auth token, this app
/// only ever calls the backend's public endpoints.
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://leotena-production-d6b5.up.railway.app',
  );

  static const _liveHost = 'https://leotena-production-d6b5.up.railway.app';
  static const _legacyHost = 'https://leotena-api-production.up.railway.app';

  String _base = baseUrl.replaceAll(RegExp(r'/$'), '');
  Future<void>? _resolve;

  Uri _uri(String path) => Uri.parse('$_base$path');

  List<String> get _candidates {
    final seen = <String>{};
    final out = <String>[];
    for (final h in [_liveHost, _base, baseUrl.replaceAll(RegExp(r'/$'), ''), _legacyHost]) {
      final host = h.replaceAll(RegExp(r'/$'), '');
      if (host.isEmpty || seen.contains(host)) continue;
      seen.add(host);
      out.add(host);
    }
    return out;
  }

  /// Prefer the Railway host whose /settings payload includes maintenance
  /// and force-update fields. The Play-store hostname still serves old JSON.
  Future<void> resolveHost() {
    return _resolve ??= _resolveHost();
  }

  Future<void> _resolveHost() async {
    String? fallback;
    for (final host in _candidates) {
      try {
        final res = await http.get(Uri.parse('$host/settings')).timeout(const Duration(seconds: 8));
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        fallback ??= host;
        final body = jsonDecode(res.body);
        if (body is Map && body.containsKey('maintenanceMode')) {
          _base = host;
          return;
        }
      } catch (_) {}
    }
    if (fallback != null) _base = fallback;
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Never _throwFor(http.Response res) {
    String message = 'Hitilafu ya mtandao (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) message = body['error'].toString();
    } catch (_) {
      // ignore — keep the generic message
    }
    throw ApiException(res.statusCode, message);
  }

  static const _offlineMessage =
      'Imeshindwa kuunganisha na seva. Angalia mtandao kisha jaribu tena.';

  bool _isOfflineError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('name resolution') ||
        s.contains('clientexception') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('timed out');
  }

  Future<T> _guard<T>(Future<T> Function() fn) async {
    await resolveHost();
    try {
      return await fn();
    } on ApiException {
      rethrow;
    } catch (e) {
      if (_isOfflineError(e)) throw ApiException(0, _offlineMessage);
      rethrow;
    }
  }

  Future<dynamic> get(String path) async {
    return _guard(() async {
      final res = await http.get(_uri(path));
      if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
      _throwFor(res);
    });
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _guard(() async {
      final res = await http.post(_uri(path), headers: {'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body));
      if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
      _throwFor(res);
    });
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _guard(() async {
      final res = await http.put(_uri(path), headers: {'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body));
      if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
      _throwFor(res);
    });
  }
}

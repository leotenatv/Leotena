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
  /// Live API. The old `leotena-production-d6b5` hostname returns Railway
  /// "Application not found" and must not be the first host payments call.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://leotena-api-production.up.railway.app',
  );

  static const _liveHost = 'https://leotena-api-production.up.railway.app';
  static const _fallbackHost = 'https://leotena-production-d6b5.up.railway.app';

  String _base = baseUrl.replaceAll(RegExp(r'/$'), '');
  Future<void>? _resolve;
  final Set<String> _rejected = {};

  /// Origin currently used for API calls, without a trailing slash.
  String get origin => _base;

  Uri _uri(String path) => Uri.parse('$_base$path');

  /// Railway's edge 404 when the service hostname is gone.
  static bool isMissingApplication(http.Response res) {
    if (res.statusCode != 404 && res.headers['x-railway-fallback'] != 'true') return false;
    final body = res.body.toLowerCase();
    return body.contains('application not found') || res.headers['x-railway-fallback'] == 'true';
  }

  List<String> get _candidates {
    final seen = <String>{};
    final out = <String>[];
    for (final h in [_liveHost, _base, baseUrl.replaceAll(RegExp(r'/$'), ''), _fallbackHost]) {
      final host = h.replaceAll(RegExp(r'/$'), '');
      if (host.isEmpty || seen.contains(host) || _rejected.contains(host)) continue;
      seen.add(host);
      out.add(host);
    }
    return out;
  }

  /// Drop a dead origin (Railway "Application not found") and pick the next host.
  void rejectOrigin(String origin) {
    final host = origin.replaceAll(RegExp(r'/$'), '');
    if (host.isEmpty) return;
    _rejected.add(host);
    if (_base == host) _resolve = null;
  }

  /// Prefer the host whose /settings payload includes maintenance fields.
  /// Probes run together so a dead hostname does not delay payments.
  Future<void> resolveHost() {
    return _resolve ??= _resolveHost();
  }

  Future<void> _resolveHost() async {
    final hosts = _candidates;
    if (hosts.isEmpty) return;
    final probes = await Future.wait(hosts.map(_probeHost));
    for (var i = 0; i < hosts.length; i++) {
      if (probes[i] == _HostProbe.ready) {
        _base = hosts[i];
        return;
      }
    }
    for (var i = 0; i < hosts.length; i++) {
      if (probes[i] == _HostProbe.reachable) {
        _base = hosts[i];
        return;
      }
    }
  }

  Future<_HostProbe> _probeHost(String host) async {
    try {
      final res = await http.get(Uri.parse('$host/settings')).timeout(const Duration(seconds: 6));
      if (isMissingApplication(res)) return _HostProbe.down;
      if (res.statusCode < 200 || res.statusCode >= 300) return _HostProbe.down;
      final body = jsonDecode(res.body);
      if (body is Map && body.containsKey('maintenanceMode')) return _HostProbe.ready;
      return _HostProbe.reachable;
    } catch (_) {
      return _HostProbe.down;
    }
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode == 204 || res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Never _throwFor(http.Response res) {
    if (isMissingApplication(res)) {
      throw ApiException(res.statusCode, 'Seva haipatikani kwa sasa. Jaribu tena.');
    }
    String message = 'Hitilafu ya mtandao (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final raw = body['error'] ?? body['message'];
        if (raw != null && raw.toString().trim().isNotEmpty) message = raw.toString();
      }
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

  Future<http.Response> _send(Future<http.Response> Function() fn) async {
    await resolveHost();
    try {
      var res = await fn();
      if (isMissingApplication(res)) {
        final dead = _base;
        rejectOrigin(dead);
        await resolveHost();
        if (_base != dead) res = await fn();
      }
      return res;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (_isOfflineError(e)) throw ApiException(0, _offlineMessage);
      rethrow;
    }
  }

  Future<dynamic> get(String path) async {
    final res = await _send(() => http.get(_uri(path)));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _send(
      () => http.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await _send(
      () => http.put(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: body == null ? null : jsonEncode(body),
      ),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }
}

enum _HostProbe { down, reachable, ready }

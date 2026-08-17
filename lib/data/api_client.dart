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

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

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

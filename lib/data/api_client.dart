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
    defaultValue: 'https://leotena-api-production.up.railway.app',
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

  Future<dynamic> get(String path) async {
    final res = await http.get(_uri(path));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await http.post(_uri(path), headers: {'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await http.put(_uri(path), headers: {'Content-Type': 'application/json'}, body: body == null ? null : jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }
}

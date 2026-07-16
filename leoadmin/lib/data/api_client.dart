import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  bool get isAuthError => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin wrapper over `http` that injects the persisted admin JWT and turns
/// non-2xx responses into [ApiException]s with the server's error message.
class ApiClient {
  static const _tokenKey = 'admin_jwt';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://leotena-api-production.up.railway.app',
  );

  String? _token;

  Future<void> loadPersistedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  bool get hasToken => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

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
    final res = await http.get(_uri(path), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await http.post(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await http.put(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await http.patch(_uri(path), headers: _headers, body: body == null ? null : jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) return _decode(res);
    _throwFor(res);
  }

  Future<void> delete(String path) async {
    final res = await http.delete(_uri(path), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    _throwFor(res);
  }
}

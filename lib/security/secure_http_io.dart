import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../net/direct_http.dart';

http.Client? _client;

/// API calls trust only public root certificates and skip any system proxy.
/// A user-installed certificate from a sniffer cannot decrypt these requests.
/// Hotspot Wi-Fi is reached directly, IPv4 first.
http.Client secureHttpClient() {
  if (_client != null) return _client!;
  return _client = IOClient(directHttpClient());
}

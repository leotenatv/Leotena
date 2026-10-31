import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../net/direct_http.dart';
import 'playback_http_headers.dart';

/// Local proxy used by the Windows player.
///
/// WebView2 loads the player with [NavigateToString], so the page is
/// `about:blank` and the browser attaches `Origin` / `Referer`. HTTP channel
/// servers answer 403 to those headers. Mobile ExoPlayer does not send them.
/// This proxy fetches the stream with the same headers as the phone and
/// returns the bytes to the WebView from localhost.
class PlaybackProxy {
  PlaybackProxy._();

  static final PlaybackProxy instance = PlaybackProxy._();

  HttpServer? _server;
  HttpClient? _client;
  Future<String>? _starting;
  String _playerHtml = '';

  Future<String> origin() {
    return _starting ??= _bind();
  }

  String publishPlayer(String html) {
    _playerHtml = html;
    final port = _server?.port;
    if (port == null) return '';
    return 'http://127.0.0.1:$port/player';
  }

  Future<String> _bind() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = directHttpClient();
    client.userAgent = playbackUserAgent;
    _server = server;
    _client = client;
    server.listen(_onRequest, onError: (_) {});
    return 'http://127.0.0.1:${server.port}/';
  }

  Future<void> _onRequest(HttpRequest request) async {
    final response = request.response;
    _cors(response);
    try {
      if (request.method == 'OPTIONS') {
        response.statusCode = HttpStatus.noContent;
        await response.close();
        return;
      }
      if (request.uri.path == '/player') {
        response.headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8');
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        response.write(_playerHtml);
        await response.close();
        return;
      }
      if (request.uri.path != '/p') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final raw = request.uri.queryParameters['u']?.trim() ?? '';
      final upstream = Uri.tryParse(raw);
      if (upstream == null ||
          (upstream.scheme != 'http' && upstream.scheme != 'https') ||
          upstream.host.isEmpty ||
          _isSelf(upstream)) {
        response.statusCode = HttpStatus.badRequest;
        await response.close();
        return;
      }
      await _forward(
        request,
        response,
        upstream,
        pinLocal: request.uri.queryParameters['local'] == '1',
      );
    } catch (_) {
      try {
        response.statusCode = HttpStatus.badGateway;
        await response.close();
      } catch (_) {}
    }
  }

  bool _isSelf(Uri upstream) {
    final port = _server?.port;
    if (port == null) return false;
    final host = upstream.host.toLowerCase();
    final loopback = host == '127.0.0.1' || host == 'localhost' || host == '::1';
    return loopback && upstream.port == port;
  }

  Future<void> _forward(
    HttpRequest inbound,
    HttpResponse outbound,
    Uri upstream, {
    required bool pinLocal,
  }) async {
    final client = _client;
    if (client == null) {
      outbound.statusCode = HttpStatus.badGateway;
      await outbound.close();
      return;
    }
    final method = inbound.method.toUpperCase() == 'HEAD' ? 'HEAD' : 'GET';
    final req = await client.openUrl(method, upstream);
    req.followRedirects = true;
    req.maxRedirects = 5;
    _applyUpstreamHeaders(req, upstream);
    final range = inbound.headers.value(HttpHeaders.rangeHeader);
    if (range != null && range.isNotEmpty) {
      try {
        req.headers.set(HttpHeaders.rangeHeader, range);
      } catch (_) {}
    }
    final upstreamResponse = await req.close().timeout(const Duration(seconds: 35));
    final finalUrl = upstreamResponse.redirects.isEmpty
        ? upstream
        : upstreamResponse.redirects.last.location;
    final contentType = upstreamResponse.headers.value(HttpHeaders.contentTypeHeader);
    outbound.statusCode = upstreamResponse.statusCode;
    final contentRange = upstreamResponse.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      outbound.headers.set(HttpHeaders.contentRangeHeader, contentRange);
    }
    final acceptRanges = upstreamResponse.headers.value('accept-ranges');
    if (acceptRanges != null) {
      outbound.headers.set('accept-ranges', acceptRanges);
    }

    final declaredHls = _declaredHls(finalUrl, contentType);
    final length = upstreamResponse.contentLength;
    if (!declaredHls && length > 8 * 1024 * 1024) {
      if (contentType != null && contentType.isNotEmpty) {
        outbound.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      await outbound.addStream(upstreamResponse);
      await outbound.close();
      return;
    }

    final iterator = StreamIterator<List<int>>(upstreamResponse);
    if (!await iterator.moveNext()) {
      await outbound.close();
      return;
    }
    final first = iterator.current;
    final playlist = declaredHls || _bodyIsHls(first);
    if (!playlist) {
      if (contentType != null && contentType.isNotEmpty) {
        outbound.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      outbound.add(first);
      while (await iterator.moveNext()) {
        outbound.add(iterator.current);
      }
      await outbound.close();
      return;
    }

    final bytes = <int>[...first];
    while (await iterator.moveNext()) {
      bytes.addAll(iterator.current);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final absolute = absolutizeHls(text, finalUrl);
    final pinned = pinLocal ? pinPlaylistToProxy(absolute, 'http://127.0.0.1:${_server?.port}') : absolute;
    final rewritten = utf8.encode(pinned);
    outbound.headers.set(
      HttpHeaders.contentTypeHeader,
      (contentType == null || contentType.isEmpty)
          ? 'application/vnd.apple.mpegurl'
          : contentType,
    );
    outbound.add(rewritten);
    await outbound.close();
  }

  void _applyUpstreamHeaders(HttpClientRequest req, Uri upstream) {
    final headers = mergePlaybackHeaders(upstream.toString());
    for (final entry in headers.entries) {
      final name = entry.key.toLowerCase();
      if (name == 'connection' ||
          name == 'host' ||
          name == 'content-length' ||
          name == 'transfer-encoding') {
        continue;
      }
      try {
        req.headers.set(entry.key, entry.value);
      } catch (_) {}
    }
  }

  bool _declaredHls(Uri url, String? contentType) {
    final path = url.path.toLowerCase();
    if (path.endsWith('.m3u8') || path.endsWith('.m3u')) return true;
    final type = (contentType ?? '').toLowerCase();
    return type.contains('mpegurl') || type.contains('m3u8');
  }

  bool _bodyIsHls(List<int> bytes) {
    if (bytes.length < 7) return false;
    final take = bytes.length < 64 ? bytes.length : 64;
    final start = utf8.decode(bytes.sublist(0, take), allowMalformed: true).trimLeft();
    return start.startsWith('#EXTM3U');
  }

  void _cors(HttpResponse response) {
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', '*');
    response.headers.set('Access-Control-Expose-Headers', '*');
  }
}

/// Turns playlist references into absolute upstream URLs so the Windows
/// player can request each one with the mobile header set.
String absolutizeHls(String text, Uri base) {
  final lines = text.split(RegExp(r'\r?\n'));
  final out = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      out.add(line);
      continue;
    }
    if (trimmed.startsWith('#')) {
      out.add(line.replaceAllMapped(RegExp('''URI=(["'])(.*?)\\1'''), (match) {
        final quote = match[1]!;
        final absolute = base.resolve(match[2]!.trim()).toString();
        return 'URI=$quote$absolute$quote';
      }));
      continue;
    }
    out.add(base.resolve(trimmed).toString());
  }
  return out.join('\n');
}

/// Keeps every playlist URL on the local proxy. The Windows player then
/// never opens the hotspot route itself.
String pinPlaylistToProxy(String absolutePlaylist, String proxyOrigin) {
  final origin = proxyOrigin.endsWith('/')
      ? proxyOrigin.substring(0, proxyOrigin.length - 1)
      : proxyOrigin;
  String wrap(String target) {
    final trimmed = target.trim();
    if (trimmed.isEmpty || trimmed.startsWith(origin)) return trimmed;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return trimmed;
    }
    return '$origin/p?u=${Uri.encodeQueryComponent(trimmed)}&local=1';
  }

  final lines = absolutePlaylist.split(RegExp(r'\r?\n'));
  final out = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('#')) {
      out.add(trimmed.isEmpty ? line : wrap(trimmed));
      continue;
    }
    out.add(line.replaceAllMapped(RegExp('''URI=(["'])(.*?)\\1'''), (match) {
      final quote = match[1]!;
      return 'URI=$quote${wrap(match[2]!)}$quote';
    }));
  }
  return out.join('\n');
}

Future<String?> windowsPlaybackProxyOrigin() async {
  if (!Platform.isWindows) return null;
  return PlaybackProxy.instance.origin();
}

/// Plays a remote stream through the local proxy so the Windows player only
/// talks to this PC. The proxy then reaches the stream on IPv4 or IPv6
/// directly, without the hotspot proxy.
Future<String?> windowsProxiedPlaybackUrl(String rawUrl) async {
  if (!Platform.isWindows) return null;
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
    return null;
  }
  final origin = await PlaybackProxy.instance.origin();
  final base = origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
  return '$base/p?u=${Uri.encodeQueryComponent(uri.toString())}&local=1';
}

String? publishWindowsPlayer(String html) {
  if (!Platform.isWindows || PlaybackProxy.instance._server == null) return null;
  final page = PlaybackProxy.instance.publishPlayer(html);
  return page.isEmpty ? null : page;
}

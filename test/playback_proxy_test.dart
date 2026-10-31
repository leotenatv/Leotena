import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leotena/player/playback_http_headers.dart';
import 'package:leotena/player/playback_proxy.dart';

void main() {
  test('HTTP playback proxy uses mobile headers and absolute playlist URLs', () async {
    String? seenUserAgent;
    String? seenReferer;
    String? seenOrigin;
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen((request) async {
      seenUserAgent = request.headers.value(HttpHeaders.userAgentHeader);
      seenReferer = request.headers.value(HttpHeaders.refererHeader);
      seenOrigin = request.headers.value('origin');
      request.response.headers.set(HttpHeaders.contentTypeHeader, 'application/vnd.apple.mpegurl');
      request.response.write('#EXTM3U\nseg.ts\n#EXT-X-KEY:METHOD=AES-128,URI="key.key"\n');
      await request.response.close();
    });

    final origin = await PlaybackProxy.instance.origin();
    final playlist = 'http://127.0.0.1:${upstream.port}/live/a.m3u8';
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('${origin}p?u=${Uri.encodeQueryComponent(playlist)}'));
    final res = await req.close();
    final body = utf8.decode(await res.fold<List<int>>(<int>[], (buf, chunk) {
      buf.addAll(chunk);
      return buf;
    }));

    expect(res.statusCode, 200);
    expect(seenUserAgent, playbackUserAgent);
    expect(seenReferer, isNull);
    expect(seenOrigin, isNull);
    expect(body, contains('http://127.0.0.1:${upstream.port}/live/seg.ts'));
    expect(body, contains('http://127.0.0.1:${upstream.port}/live/key.key'));

    client.close(force: true);
    await upstream.close(force: true);
  });

  test('local playback proxy keeps playlist URLs on localhost', () {
    const origin = 'http://127.0.0.1:9';
    final pinned = pinPlaylistToProxy(
      '#EXTM3U\n'
      'http://cdn.example/live/seg.ts\n'
      '#EXT-X-KEY:METHOD=AES-128,URI="http://cdn.example/live/key.key"\n',
      origin,
    );
    expect(pinned, contains('$origin/p?u='));
    expect(pinned, contains(Uri.encodeQueryComponent('http://cdn.example/live/seg.ts')));
    expect(pinned, contains(Uri.encodeQueryComponent('http://cdn.example/live/key.key')));
    expect(pinned, isNot(contains('\nhttp://cdn.example/')));
  });
}

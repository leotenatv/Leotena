import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../player/playback_http_headers.dart';

/// Opens Leotena's native ExoPlayer activity on Android (Washa Orizon stack).
class NativeAndroidPlayer {
  NativeAndroidPlayer._();

  static const _channel = MethodChannel('com.ghettodevelopers.leotena/native_player');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> open({
    required PlaybackSource source,
    String audioLanguage = 'sw',
    String defaultQuality = '480p',
    String videoZoomMode = 'contain',
  }) async {
    if (!supported) return;

    final url = source.url.trim();
    if (url.isEmpty) return;

    final drmType = switch (source.drm) {
      ChannelDrm.clearkey => 'CLEARKEY',
      ChannelDrm.widevine => 'WIDEVINE',
      ChannelDrm.none => 'NONE',
    };

    final headers = playbackHttpHeaders(url);
    final zoom = videoZoomMode.trim().isEmpty ? 'contain' : videoZoomMode.trim();

    await _channel.invokeMethod<void>('open', <String, dynamic>{
      'url': url,
      'channelId': source.channelId,
      'channelName': source.title,
      'licenseUrl': '',
      'token': '',
      'drmType': drmType,
      'clearKeyHex': source.clearKey.trim(),
      'drmClearKey': source.clearKey.trim(),
      'drm_clear_key': source.clearKey.trim(),
      'headersJson': headers.isEmpty ? '' : jsonEncode(headers),
      'audioLanguage': audioLanguage,
      'defaultQuality': defaultQuality,
      'videoZoomMode': zoom,
      'dataSaver': false,
    });
  }
}

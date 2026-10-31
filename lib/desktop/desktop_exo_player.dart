import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../player/playback_http_headers.dart';

/// Embedded ExoPlayer for the television layout. Same stream stack as the
/// phone player, shown inside the desktop watch pane.
class DesktopExoPlayer extends StatefulWidget {
  final PlaybackSource source;
  final VoidCallback onPlaying;
  final ValueChanged<String> onError;

  const DesktopExoPlayer({
    super.key,
    required this.source,
    required this.onPlaying,
    required this.onError,
  });

  @override
  State<DesktopExoPlayer> createState() => _DesktopExoPlayerState();
}

class _DesktopExoPlayerState extends State<DesktopExoPlayer> {
  MethodChannel? _channel;
  var _reported = false;

  void _onPlaying() {
    if (_reported || !mounted) return;
    _reported = true;
    widget.onPlaying();
  }

  void _onError(String message) {
    if (_reported || !mounted) return;
    _reported = true;
    widget.onError(message.trim().isEmpty ? 'Imeshindwa kucheza' : message.trim());
  }

  Future<void> _attach(int id) async {
    final channel = MethodChannel('com.ghettodevelopers.leotena/exo_player_$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'playing') _onPlaying();
      if (call.method == 'error') _onError(call.arguments?.toString() ?? '');
    });
    try {
      await channel.invokeMethod<void>('sync');
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.shrink();
    }
    final source = widget.source;
    final drmType = switch (source.drm) {
      ChannelDrm.clearkey => 'CLEARKEY',
      ChannelDrm.widevine => 'WIDEVINE',
      ChannelDrm.none => 'NONE',
    };
    return AndroidView(
      viewType: 'leotena/exo_player',
      creationParams: <String, dynamic>{
        'url': source.url.trim(),
        'drmType': drmType,
        'clearKeyHex': source.clearKey.trim(),
        'headersJson': jsonEncode(mergePlaybackHeaders(source.url.trim())),
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _attach,
    );
  }
}

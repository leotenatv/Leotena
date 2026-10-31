import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/models.dart';
import '../player/playback_http_headers.dart';
import '../player/playback_proxy.dart';

/// Windows playback for direct streams. libmpv sends the same HTTP headers
/// as the phone player and can play the MPEG-TS / HLS links a browser cannot.
class DesktopMpvPlayer extends StatefulWidget {
  final PlaybackSource source;
  final VoidCallback onPlaying;
  final ValueChanged<String> onError;

  const DesktopMpvPlayer({
    super.key,
    required this.source,
    required this.onPlaying,
    required this.onError,
  });

  @override
  State<DesktopMpvPlayer> createState() => _DesktopMpvPlayerState();
}

class _DesktopMpvPlayerState extends State<DesktopMpvPlayer> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(title: 'Leotena'),
  );
  late final VideoController _video = VideoController(
    _player,
    configuration: const VideoControllerConfiguration(
      width: 1280,
      height: 720,
    ),
  );
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _watchdog;
  Timer? _stall;
  bool _closed = false;
  bool _pictured = false;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.stream.width.listen((width) {
      if (width != null && width > 0) _onPicture();
    }));
    _subs.add(_player.stream.error.listen(_onEngineError));
    _subs.add(_player.stream.buffering.listen((buffering) {
      if (!buffering || !_pictured) {
        _stall?.cancel();
        _stall = null;
        return;
      }
      _stall ??= Timer(const Duration(seconds: 5), () {
        _unstick();
      });
    }));
    _watchdog = Timer(const Duration(seconds: 25), () {
      if (!_pictured) _report('Imeshindwa kucheza');
    });
    _open();
  }

  Future<void> _open() async {
    final url = widget.source.url.trim();
    if (url.isEmpty || _closed) return;
    try {
      MediaKit.ensureInitialized();
      final headers = mergePlaybackHeaders(url);
      headers.remove('Connection');
      await _applyEngineOptions(headers);
      if (_closed) return;
      final played = await _playbackUrl(url);
      if (_closed) return;
      await _player.open(Media(played, httpHeaders: headers));
    } catch (error) {
      _report(error.toString());
    }
  }

  /// libmpv ignores a User-Agent inside http-header-fields and refuses remote
  /// URLs loaded from its playlist file unless this flag is on. The phone
  /// player sends [playbackUserAgent] and follows the stream directly.
  Future<void> _applyEngineOptions(Map<String, String> headers) async {
    final native = _player.platform;
    if (native == null) return;
    Future<void> set(String key, String value) async {
      try {
        await (native as dynamic).setProperty(key, value);
      } catch (error) {
        debugPrint('Leotena player option $key skipped: $error');
      }
    }

    // A live playlist only has a few segments ahead. Waiting to fill a long
    // cache leaves the picture paused, because that much video does not exist
    // yet. Start a few segments behind the edge and keep playing.
    await set('load-unsafe-playlists', 'yes');
    await set('ytdl', 'no');
    await set('network-timeout', '60');
    await set('cache', 'yes');
    await set('cache-on-disk', 'no');
    await set('cache-secs', '8');
    await set('demuxer-readahead-secs', '8');
    await set('demuxer-max-bytes', '64MiB');
    await set('demuxer-max-back-bytes', '8MiB');
    await set('cache-pause', 'no');
    await set('cache-pause-initial', 'no');
    await set('demuxer-cache-wait', 'no');
    await set('hr-seek', 'no');
    await set('hr-seek-framedrop', 'no');
    await set('framedrop', 'no');
    await set('video-sync', 'audio');
    await set('interpolation', 'no');
    await set('audio-buffer', '1');
    await set('audio-pitch-correction', 'no');
    await set('audio-exclusive', 'no');
    await set('stream-buffer-size', '4MiB');
    await set(
      'demuxer-lavf-o-add',
      'live_start_index=-3,fflags=+discardcorrupt+genpts',
    );
    await set(
      'stream-lavf-o',
      'reconnect=1,reconnect_streamed=1,reconnect_delay_max=2,rw_timeout=20000000,http_proxy=',
    );
    await set('user-agent', headers['User-Agent'] ?? playbackUserAgent);
    final referer = headers['Referer'];
    if (referer != null && referer.isNotEmpty) {
      await set('referrer', referer);
    }
  }

  Future<String> _playbackUrl(String url) async {
    try {
      final proxied = await windowsProxiedPlaybackUrl(url);
      if (proxied != null && proxied.isNotEmpty) return proxied;
    } catch (error) {
      debugPrint('Leotena player proxy skipped: $error');
    }
    return url;
  }

  Future<void> _unstick() async {
    if (_closed || !_pictured) return;
    final native = _player.platform;
    if (native == null) return;
    try {
      await (native as dynamic).setProperty('cache-pause', 'no');
      await (native as dynamic).setProperty('pause', 'no');
    } catch (_) {}
  }

  void _onPicture() {
    if (_pictured || _closed || !mounted) return;
    _pictured = true;
    _watchdog?.cancel();
    debugPrint('Leotena player: picture ${widget.source.title}');
    widget.onPlaying();
  }

  void _onEngineError(String message) {
    if (_pictured || _closed) return;
    final text = message.toLowerCase();
    final failed = text.contains('403') ||
        text.contains('404') ||
        text.contains('forbidden') ||
        text.contains('refus') ||
        text.contains('unsafe') ||
        text.contains('failed to') ||
        text.contains('can not open') ||
        text.contains('cannot open') ||
        text.contains('timeout') ||
        text.contains('invalid data') ||
        text.contains('protocol not found');
    if (failed) _report(message);
  }

  void _report(String message) {
    if (_reported || _closed || !mounted) return;
    _reported = true;
    debugPrint('Leotena player: ${message.trim()}');
    widget.onError(message.trim().isEmpty ? 'Imeshindwa kucheza' : message.trim());
  }

  @override
  void dispose() {
    _closed = true;
    _watchdog?.cancel();
    _stall?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _video,
      fit: BoxFit.contain,
      fill: const Color(0xFF07111F),
      controls: NoVideoControls,
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      onEnterFullscreen: () async {},
      onExitFullscreen: () async {},
    );
  }
}

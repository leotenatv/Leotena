import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../player/stream_url_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/web_stream_player.dart';
import 'desktop_exo_player.dart';
import 'desktop_mpv_player.dart';
import 'desktop_shimmer.dart';

/// Right-hand stage: the shared stream player, with back and fullscreen.
class DesktopPlayerPane extends StatefulWidget {
  final PlaybackSource source;
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;

  const DesktopPlayerPane({
    super.key,
    required this.source,
    required this.fullscreen,
    required this.onBack,
    required this.onToggleFullscreen,
  });

  @override
  State<DesktopPlayerPane> createState() => _DesktopPlayerPaneState();
}

class _DesktopPlayerPaneState extends State<DesktopPlayerPane> {
  final _controller = WebStreamController();
  bool _playing = false;
  bool _buffering = true;
  bool _humanCheck = false;
  bool _seenPicture = false;
  String? _error;
  int _reload = 0;
  Timer? _retry;

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DesktopPlayerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.url != widget.source.url ||
        oldWidget.source.clearKey != widget.source.clearKey) {
      _retry?.cancel();
      _error = null;
      _buffering = true;
      _playing = false;
      _seenPicture = false;
      _humanCheck = false;
    }
  }

  bool _directStream(PlaybackSource source) {
    // ClearKey has the key in the app, so the browser player can unlock it.
    // Widevine rows from the server have no license URL. The phone treats
    // those as a normal stream, and this layout must do the same.
    if (source.drm == ChannelDrm.clearkey && source.clearKey.trim().isNotEmpty) {
      return false;
    }
    final url = source.url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    return !useWebViewForUrl(url);
  }

  bool _usesEngine(PlaybackSource source) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return false;
    return _directStream(source);
  }

  bool _usesExo(PlaybackSource source) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    return _directStream(source);
  }

  void _armRetry() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 4), () {
      if (!mounted || _playing) return;
      setState(() {
        _error = null;
        _buffering = true;
        _seenPicture = false;
        _reload++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return ColoredBox(
      color: const Color(0xFF07111F),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _stage(source),
          if (!_humanCheck && !_seenPicture)
            const Positioned.fill(child: DesktopPlayerShimmer()),
          if (!_humanCheck) _chrome(source),
        ],
      ),
    );
  }

  Widget _stage(PlaybackSource source) {
    return LayoutBuilder(
      builder: (context, constraints) {
        var width = constraints.maxWidth;
        var height = width * 9 / 16;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * 16 / 9;
        }
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: _usesEngine(source)
                ? DesktopMpvPlayer(
                    key: ValueKey('mpv|${source.url}|$_reload'),
                    source: source,
                    onPlaying: () {
                      if (!mounted) return;
                      setState(() {
                        _playing = true;
                        _buffering = false;
                        _seenPicture = true;
                        _error = null;
                      });
                      _retry?.cancel();
                    },
                    onError: (message) {
                      if (!mounted || _seenPicture) return;
                      setState(() {
                        _buffering = true;
                        _playing = false;
                        _error = message;
                      });
                      _armRetry();
                    },
                  )
                : _usesExo(source)
                    ? DesktopExoPlayer(
                        key: ValueKey('exo|${source.url}|$_reload'),
                        source: source,
                        onPlaying: () {
                          if (!mounted) return;
                          setState(() {
                            _playing = true;
                            _buffering = false;
                            _seenPicture = true;
                            _error = null;
                          });
                          _retry?.cancel();
                        },
                        onError: (message) {
                          if (!mounted || _seenPicture) return;
                          setState(() {
                            _buffering = true;
                            _playing = false;
                            _error = message;
                          });
                          _armRetry();
                        },
                      )
                    : WebStreamPlayer(
              key: ValueKey(
                  '${source.channelId ?? source.title}|${source.url}|$_reload'),
              source: source,
              controller: _controller,
              onState: (
                  {bool? playing,
                  bool? buffering,
                  double? position,
                  double? duration}) {
                if (!mounted) return;
                final nextPlaying = playing ?? _playing;
                final nextBuffering = buffering ?? _buffering;
                final pictured = _seenPicture || nextPlaying;
                if (nextPlaying == _playing &&
                    nextBuffering == _buffering &&
                    pictured == _seenPicture &&
                    _error == null) {
                  return;
                }
                setState(() {
                  if (playing != null) _playing = playing;
                  if (buffering != null) _buffering = buffering;
                  if (nextPlaying) {
                    _seenPicture = true;
                    _error = null;
                    _retry?.cancel();
                  }
                });
              },
              onQualities: (_) {},
              onLanguages: (_) {},
              onQualityChanged: (_) {},
              onLanguageChanged: (_) {},
              onError: (message) {
                if (!mounted || _seenPicture) return;
                final trimmed = message.trim();
                setState(() {
                  _buffering = true;
                  _playing = false;
                  _error = trimmed.isEmpty ? 'offline' : trimmed;
                });
                _armRetry();
              },
              onHumanCheck: (checking) {
                if (!mounted) return;
                setState(() => _humanCheck = checking);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _chrome(PlaybackSource source) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF07111F).withValues(alpha: 0.88),
              const Color(0xFF07111F).withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          child: Row(
            children: [
              _RoundAction(
                tooltip: 'Rudi kwenye vituo',
                icon: Icons.arrow_back_rounded,
                onTap: widget.onBack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.heading(18, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: AppColors.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE',
                          style: AppTheme.body(11,
                              color: AppColors.green, weight: FontWeight.w800),
                        ),
                        if (source.subtitle.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              source.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.fullscreen ? 'Esc kufunga' : 'F11 skrini nzima',
                style: AppTheme.body(11, color: Colors.white54),
              ),
              const SizedBox(width: 10),
              _RoundAction(
                tooltip:
                    widget.fullscreen ? 'Funga skrini nzima' : 'Skrini nzima',
                icon: widget.fullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                onTap: widget.onToggleFullscreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

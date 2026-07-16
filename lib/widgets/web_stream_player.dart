import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/models.dart';

typedef StreamStateCallback = void Function({
  bool? playing,
  bool? buffering,
  double? position,
  double? duration,
});

class WebStreamController {
  InAppWebViewController? _web;

  Future<void> play() => _run('window.leotenaPlayer?.play()');
  Future<void> pause() => _run('window.leotenaPlayer?.pause()');
  Future<void> seek(double seconds) =>
      _run('window.leotenaPlayer?.seek(${seconds.isFinite ? seconds : 0})');
  Future<void> setQuality(String quality) =>
      _run('window.leotenaPlayer?.setQuality(${jsonEncode(quality)})');
  Future<void> setLanguage(String language) =>
      _run('window.leotenaPlayer?.setLanguage(${jsonEncode(language)})');

  Future<void> _run(String source) async {
    try {
      await _web?.evaluateJavascript(source: source);
    } catch (_) {
      // The view may be closing or reloading; the next state event reconciles UI.
    }
  }
}

/// Shaka Player hosted inside a WebView. It plays the exact URL supplied by
/// the selected channel/movie and exposes real adaptive variants/audio tracks.
class WebStreamPlayer extends StatefulWidget {
  final PlaybackSource source;
  final WebStreamController controller;
  final StreamStateCallback onState;
  final ValueChanged<List<String>> onQualities;
  final ValueChanged<List<String>> onLanguages;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onError;

  const WebStreamPlayer({
    super.key,
    required this.source,
    required this.controller,
    required this.onState,
    required this.onQualities,
    required this.onLanguages,
    required this.onQualityChanged,
    required this.onLanguageChanged,
    required this.onError,
  });

  @override
  State<WebStreamPlayer> createState() => _WebStreamPlayerState();
}

class _WebStreamPlayerState extends State<WebStreamPlayer> {
  @override
  Widget build(BuildContext context) {
    if (widget.source.url.trim().isEmpty) {
      return const _PlayerMessage(
        icon: Icons.link_off_rounded,
        message: 'Kituo hiki hakina URL ya video.',
      );
    }

    // flutter_inappwebview has no Linux implementation. This guard keeps a
    // desktop development run from crashing while Android/iOS/Web use Shaka.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return const _PlayerMessage(
        icon: Icons.desktop_windows_rounded,
        message: 'Web player inatumika kwenye Android, iOS na Web.',
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _html(widget.source)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          transparentBackground: true,
          disableContextMenu: true,
          supportZoom: false,
          useHybridComposition: true,
        ),
        onWebViewCreated: (controller) {
          widget.controller._web = controller;
          controller.addJavaScriptHandler(
            handlerName: 'playerState',
            callback: (args) {
              if (args.isEmpty || args.first is! Map) return null;
              final data = Map<String, dynamic>.from(args.first as Map);
              widget.onState(
                playing: data['playing'] as bool?,
                buffering: data['buffering'] as bool?,
                position: (data['position'] as num?)?.toDouble(),
                duration: (data['duration'] as num?)?.toDouble(),
              );
              return null;
            },
          );
          controller.addJavaScriptHandler(
            handlerName: 'playerTracks',
            callback: (args) {
              if (args.isEmpty || args.first is! Map) return null;
              final data = Map<String, dynamic>.from(args.first as Map);
              final qualities = (data['qualities'] as List<dynamic>? ?? const [])
                  .map((e) => e.toString())
                  .toList();
              final languages = (data['languages'] as List<dynamic>? ?? const [])
                  .map((e) => e.toString())
                  .toList();
              widget.onQualities(qualities);
              widget.onLanguages(languages);
              final quality = data['activeQuality'] as String?;
              final language = data['activeLanguage'] as String?;
              if (quality != null) widget.onQualityChanged(quality);
              if (language != null && language.isNotEmpty) {
                widget.onLanguageChanged(language);
              }
              return null;
            },
          );
          controller.addJavaScriptHandler(
            handlerName: 'playerError',
            callback: (args) {
              widget.onError(args.isEmpty ? 'Video haikuweza kuchezwa.' : args.first.toString());
              return null;
            },
          );
        },
        onReceivedError: (_, __, error) {
          widget.onError(error.description);
        },
      ),
    );
  }

  String _html(PlaybackSource source) {
    final sourceJson = jsonEncode(source.url.trim());
    final clearKeys = <String, String>{};
    if (source.drm == ChannelDrm.clearkey) {
      final parts = source.clearKey.split(':');
      if (parts.length == 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
        clearKeys[parts[0].trim()] = parts[1].trim();
      }
    }
    final clearKeysJson = jsonEncode(clearKeys);

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
  <style>
    html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#000}
    video{width:100%;height:100%;object-fit:contain;background:#000}
  </style>
  <script src="https://cdn.jsdelivr.net/npm/shaka-player@4.16.12/dist/shaka-player.compiled.js"></script>
</head>
<body>
  <video id="video" autoplay playsinline webkit-playsinline></video>
  <script>
    const video = document.getElementById('video');
    let player = null;
    let lastStateAt = 0;

    function call(name, payload) {
      try {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler(name, payload);
        }
      } catch (_) {}
    }
    function errorText(error) {
      if (!error) return 'Video haikuweza kuchezwa.';
      if (error.detail) error = error.detail;
      return error.message || ('Shaka error ' + (error.code || 'unknown'));
    }
    function emitState(force) {
      const now = Date.now();
      if (!force && now - lastStateAt < 250) return;
      lastStateAt = now;
      call('playerState', {
        playing: !video.paused && !video.ended,
        buffering: video.readyState < 3,
        position: Number.isFinite(video.currentTime) ? video.currentTime : 0,
        duration: Number.isFinite(video.duration) ? video.duration : 0
      });
    }
    function languageCode(value) {
      return (value || 'und').toLowerCase().split('-')[0];
    }
    function emitTracks() {
      if (!player) return;
      const tracks = player.getVariantTracks();
      const heights = [...new Set(tracks.map(t => t.height).filter(Boolean))].sort((a,b) => a-b);
      const qualities = ['Auto', ...heights.map(h => h + 'p')];
      const languages = [...new Set(player.getAudioLanguages().map(languageCode).filter(x => x !== 'und'))];
      const active = tracks.find(t => t.active);
      const abr = player.getConfiguration().abr.enabled;
      call('playerTracks', {
        qualities,
        languages,
        activeQuality: abr ? 'Auto' : (active && active.height ? active.height + 'p' : 'Auto'),
        activeLanguage: active ? languageCode(active.language) : (languages[0] || '')
      });
    }

    window.leotenaPlayer = {
      play: () => video.play(),
      pause: () => video.pause(),
      seek: value => {
        if (Number.isFinite(value) && Number.isFinite(video.duration)) video.currentTime = value;
      },
      setQuality: value => {
        if (!player) return;
        if (value === 'Auto') {
          player.configure({abr:{enabled:true}});
        } else {
          const height = parseInt(value, 10);
          const tracks = player.getVariantTracks().filter(t => t.height === height);
          const currentLanguage = languageCode((player.getVariantTracks().find(t => t.active) || {}).language);
          const chosen = tracks.find(t => languageCode(t.language) === currentLanguage) || tracks[0];
          if (chosen) {
            player.configure({abr:{enabled:false}});
            player.selectVariantTrack(chosen, true, 4);
          }
        }
        setTimeout(emitTracks, 100);
      },
      setLanguage: value => {
        if (!player) return;
        player.selectAudioLanguage(value);
        setTimeout(emitTracks, 150);
      }
    };

    ['play','pause','playing','waiting','stalled','seeking','seeked','timeupdate','durationchange','ended']
      .forEach(name => video.addEventListener(name, () => emitState(name !== 'timeupdate')));

    async function init() {
      try {
        shaka.polyfill.installAll();
        if (!shaka.Player.isBrowserSupported()) throw new Error('Kifaa hiki hakitumii Shaka Player.');
        player = new shaka.Player();
        await player.attach(video);
        player.addEventListener('error', event => call('playerError', errorText(event)));
        player.addEventListener('trackschanged', emitTracks);
        player.addEventListener('variantchanged', emitTracks);
        player.addEventListener('adaptation', emitTracks);
        player.addEventListener('buffering', event => call('playerState', {
          playing: !video.paused,
          buffering: !!event.buffering,
          position: video.currentTime || 0,
          duration: Number.isFinite(video.duration) ? video.duration : 0
        }));
        player.configure({
          abr: {enabled: true},
          preferredAudioLanguage: 'sw',
          streaming: {rebufferingGoal: 2, bufferingGoal: 15},
          drm: {clearKeys: $clearKeysJson}
        });
        await player.load($sourceJson);
        emitTracks();
        emitState(true);
        try { await video.play(); } catch (_) {}
      } catch (error) {
        // Plain MP4/HLS supported natively can still work when Shaka/CDN fails.
        try {
          video.src = $sourceJson;
          await video.play();
          emitState(true);
        } catch (_) {
          call('playerError', errorText(error));
        }
      }
    }
    document.addEventListener('flutterInAppWebViewPlatformReady', init, {once:true});
    setTimeout(() => { if (!player && !video.src) init(); }, 800);
  </script>
</body>
</html>
''';
  }
}

class _PlayerMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _PlayerMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 44),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

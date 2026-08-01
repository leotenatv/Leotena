import 'dart:collection';
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

  Future<void> play() => _run('window.leotenaPlayer&&window.leotenaPlayer.play&&window.leotenaPlayer.play()');
  Future<void> pause() => _run('window.leotenaPlayer&&window.leotenaPlayer.pause&&window.leotenaPlayer.pause()');
  Future<void> seek(double seconds) =>
      _run('window.leotenaPlayer&&window.leotenaPlayer.seek&&window.leotenaPlayer.seek(${seconds.isFinite ? seconds : 0})');
  Future<void> setQuality(String quality) => _run(
        'window.leotenaPlayer&&window.leotenaPlayer.setQuality&&window.leotenaPlayer.setQuality(${jsonEncode(quality)})',
      );
  Future<void> setLanguage(String language) => _run(
        'window.leotenaPlayer&&window.leotenaPlayer.setLanguage&&window.leotenaPlayer.setLanguage(${jsonEncode(language)})',
      );

  Future<void> _run(String source) async {
    try {
      await _web?.evaluateJavascript(source: source);
    } catch (_) {
      // The view may be closing or reloading; the next state event reconciles UI.
    }
  }
}

/// Plays channel/movie URLs inside a WebView.
///
/// - Direct media (`.m3u8` / `.mpd` / `.mp4` …) → Shaka Player with a real
///   page origin so CORS is not blocked by `about:blank`.
/// - HTML embed / `player.php` pages → loaded as the WebView document itself
///   (these are not manifests; Shaka cannot play them).
class WebStreamPlayer extends StatefulWidget {
  final PlaybackSource source;
  final WebStreamController controller;
  final StreamStateCallback onState;
  final ValueChanged<List<String>> onQualities;
  final ValueChanged<List<String>> onLanguages;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onError;
  /// True while a bot-check / reCAPTCHA page is showing — host UI must not
  /// cover the WebView or steal taps.
  final ValueChanged<bool> onHumanCheck;

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
    required this.onHumanCheck,
  });

  @override
  State<WebStreamPlayer> createState() => _WebStreamPlayerState();
}

class _WebStreamPlayerState extends State<WebStreamPlayer> {
  bool get _isMediaStream => _looksLikeMediaUrl(widget.source.url);
  Widget? _cachedView;
  String? _cachedUrl;

  // Stable callback slots so the platform WebView is not rebuilt on every
  // parent setState (that rebuild cycle causes Huawei jank / "scratches").
  late StreamStateCallback _onState = widget.onState;
  late ValueChanged<List<String>> _onQualities = widget.onQualities;
  late ValueChanged<List<String>> _onLanguages = widget.onLanguages;
  late ValueChanged<String> _onQualityChanged = widget.onQualityChanged;
  late ValueChanged<String> _onLanguageChanged = widget.onLanguageChanged;
  late ValueChanged<String> _onError = widget.onError;
  late ValueChanged<bool> _onHumanCheck = widget.onHumanCheck;

  @override
  void didUpdateWidget(covariant WebStreamPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onState = widget.onState;
    _onQualities = widget.onQualities;
    _onLanguages = widget.onLanguages;
    _onQualityChanged = widget.onQualityChanged;
    _onLanguageChanged = widget.onLanguageChanged;
    _onError = widget.onError;
    _onHumanCheck = widget.onHumanCheck;
    if (oldWidget.source.url.trim() != widget.source.url.trim() ||
        oldWidget.source.clearKey != widget.source.clearKey) {
      _cachedView = null;
      _cachedUrl = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.source.url.trim();
    if (url.isEmpty) {
      return const _PlayerMessage(
        icon: Icons.link_off_rounded,
        message: 'Kituo hiki hakina URL ya video.',
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
      return const _PlayerMessage(
        icon: Icons.desktop_windows_rounded,
        message: 'Web player inatumika kwenye Android, iOS na Web.',
      );
    }

    if (_cachedView != null && _cachedUrl == url) {
      return _cachedView!;
    }
    _cachedUrl = url;
    _cachedView = RepaintBoundary(child: _buildWebView(url));
    return _cachedView!;
  }

  Widget _buildWebView(String url) {
    // Hybrid composition is required for video frames on many Huawei devices.
    // Texture/VirtualDisplay often yields audio-only (blank picture).
    const hybrid = true;

    final settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      transparentBackground: false,
      disableContextMenu: true,
      supportZoom: false,
      useHybridComposition: hybrid,
      allowsBackForwardNavigationGestures: false,
      iframeAllow: 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen',
      iframeAllowFullscreen: true,
      allowsLinkPreview: false,
      isInspectable: kDebugMode,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
      allowContentAccess: true,
      allowFileAccess: true,
      domStorageEnabled: true,
      databaseEnabled: false,
      thirdPartyCookiesEnabled: true,
      hardwareAcceleration: true,
      preferredContentMode: UserPreferredContentMode.MOBILE,
      cacheEnabled: true,
      userAgent:
          'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    );

    return ColoredBox(
      color: Colors.black,
      child: InAppWebView(
        key: ValueKey('${_isMediaStream ? 'media' : 'embed'}|$url'),
        initialUrlRequest: _isMediaStream
            ? null
            : URLRequest(
                url: WebUri(url),
                headers: {
                  'Referer': _pageOrigin(url),
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                },
              ),
        initialData: _isMediaStream
            ? InAppWebViewInitialData(
                data: _shakaHtml(widget.source),
                baseUrl: WebUri(_pageOrigin(url)),
                historyUrl: WebUri(_pageOrigin(url)),
                mimeType: 'text/html',
                encoding: 'utf-8',
              )
            : null,
        initialSettings: settings,
        initialUserScripts: _isMediaStream
            ? null
            : UnmodifiableListView<UserScript>([
                UserScript(
                  source: r'''
(function () {
  window.__leotenaShakas = window.__leotenaShakas || [];
  function patchRecaptcha(api) {
    if (!api || api.__leotenaPatched) return api;
    try {
      var ex = api.execute && api.execute.bind(api);
      if (ex) {
        api.execute = function () {
          try { return ex.apply(api, arguments); }
          catch (e) { return undefined; }
        };
      }
      api.__leotenaPatched = true;
    } catch (_) {}
    return api;
  }
  var currentCaptcha;
  try {
    Object.defineProperty(window, 'grecaptcha', {
      configurable: true,
      enumerable: true,
      get: function () { return currentCaptcha; },
      set: function (v) { currentCaptcha = patchRecaptcha(v); }
    });
  } catch (_) {}

  // Capture every Shaka Player created by the embed page so quality/language
  // controls can drive it from Flutter.
  function hookShaka() {
    if (!window.shaka || !window.shaka.Player || window.shaka.Player.__leotenaHooked) {
      return !!(window.shaka && window.shaka.Player);
    }
    try {
      var Orig = window.shaka.Player;
      var Wrapped = class extends Orig {
        constructor() {
          super(...arguments);
          window.__leotenaShaka = this;
          window.__leotenaShakas.push(this);
        }
      };
      Object.keys(Orig).forEach(function (k) {
        try { Wrapped[k] = Orig[k]; } catch (_) {}
      });
      if (Orig.isBrowserSupported) Wrapped.isBrowserSupported = function () { return Orig.isBrowserSupported(); };
      Wrapped.__leotenaHooked = true;
      window.shaka.Player = Wrapped;
      return true;
    } catch (_) {
      try {
        var Orig2 = window.shaka.Player;
        var old = Orig2;
        window.shaka.Player = function () {
          var inst = new old();
          window.__leotenaShaka = inst;
          window.__leotenaShakas.push(inst);
          return inst;
        };
        window.shaka.Player.prototype = old.prototype;
        window.shaka.Player.isBrowserSupported = old.isBrowserSupported.bind(old);
        window.shaka.Player.__leotenaHooked = true;
        return true;
      } catch (__) {
        return false;
      }
    }
  }
  var tries = 0;
  var timer = setInterval(function () {
    if (hookShaka() || ++tries > 80) clearInterval(timer);
  }, 120);
})();
''',
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
        onWebViewCreated: (controller) {
          widget.controller._web = controller;
          _bindHandlers(controller);
        },
        onLoadStart: (_, __) {
          _onState(playing: false, buffering: true);
        },
        onLoadStop: (controller, loadedUrl) async {
          if (_isMediaStream) return;
          final page = await _classifyEmbedPage(controller);
          if (page == _EmbedPage.forbidden) {
            _onHumanCheck(false);
            _onError(
              'Seva ya stream imezuia ufikiaji (403). '
              'Weka URL halisi ya .m3u8/.mpd kwenye LeoAdmin.',
            );
            return;
          }
          if (page == _EmbedPage.captcha) {
            await _prepareCaptchaPage(controller);
            _onState(playing: false, buffering: false);
            _onHumanCheck(true);
            return;
          }
          _onHumanCheck(false);
          await _injectEmbedHelpers(controller);
          _onState(playing: true, buffering: false);
          _onLanguages(const ['sw', 'en']);
          _onQualities(const ['360p', '480p', '720p', '1080p', 'Auto']);
          _onLanguageChanged('sw');
          _onQualityChanged('360p');
        },
        onReceivedError: (_, request, error) {
          final isMain = request.isForMainFrame ?? true;
          if (isMain && !_isMediaStream) {
            _onError(error.description);
          }
        },
        onReceivedHttpError: (_, request, response) {
          final isMain = request.isForMainFrame ?? true;
          if (!isMain) return;
          final code = response.statusCode ?? 0;
          if (code == 403) {
            _onError(
              'Seva ya stream imezuia ufikiaji (403). '
              'Weka URL halisi ya .m3u8/.mpd kwenye LeoAdmin.',
            );
            return;
          }
          if (_isMediaStream && code >= 400) {
            _onError('HTTP $code — stream haipatikani.');
          }
        },
        onConsoleMessage: (_, msg) {
          if (kDebugMode && msg.messageLevel == ConsoleMessageLevel.ERROR) {
            final text = msg.message;
            if (text.contains('grecaptcha') || text.contains('requestStorageAccess')) return;
            debugPrint('WebPlayer: $text');
          }
        },
      ),
    );
  }

  void _bindHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'playerState',
      callback: (args) {
        if (args.isEmpty || args.first is! Map) return null;
        final data = Map<String, dynamic>.from(args.first as Map);
        _onState(
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
        _onQualities(qualities);
        _onLanguages(languages);
        final quality = data['activeQuality'] as String?;
        final language = data['activeLanguage'] as String?;
        if (quality != null) _onQualityChanged(quality);
        if (language != null && language.isNotEmpty) {
          _onLanguageChanged(language);
        }
        return null;
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'playerError',
      callback: (args) {
        _onError(args.isEmpty ? 'Video haikuweza kuchezwa.' : args.first.toString());
        return null;
      },
    );
  }

  /// Classifies remote HTML documents so we do not treat 403 pages as video.
  Future<_EmbedPage> _classifyEmbedPage(InAppWebViewController controller) async {
    try {
      final result = await controller.evaluateJavascript(source: r'''
(function () {
  var title = (document.title || '').toLowerCase();
  var body = (document.body && (document.body.innerText || document.body.textContent) || '').toLowerCase();
  var html = (document.documentElement && document.documentElement.innerHTML || '').toLowerCase();
  if (html.indexOf('bot verification') !== -1 || html.indexOf('lsrecaptcha') !== -1) return 'captcha';
  if (title.indexOf('403') !== -1 || title.indexOf('forbidden') !== -1) return 'forbidden';
  if (body.indexOf('access to this resource on the server is denied') !== -1) return 'forbidden';
  if (body.indexOf('403') !== -1 && body.indexOf('forbidden') !== -1) return 'forbidden';
  if (!document.querySelector('video,iframe,player,.player,#player,.video-js,source')) {
    if (body.length < 400 && (body.indexOf('denied') !== -1 || body.indexOf('forbidden') !== -1)) {
      return 'forbidden';
    }
  }
  return 'ok';
})();
''');
      switch (result?.toString()) {
        case 'forbidden':
          return _EmbedPage.forbidden;
        case 'captcha':
          return _EmbedPage.captcha;
        default:
          return _EmbedPage.ok;
      }
    } catch (_) {
      return _EmbedPage.ok;
    }
  }

  /// Make the LiteSpeed reCAPTCHA checkbox usable inside a landscape WebView.
  Future<void> _prepareCaptchaPage(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: r'''
(function () {
  if (window.__leotenaCaptchaReady) return;
  window.__leotenaCaptchaReady = true;

  // Host page calls execute() on a normal checkbox captcha — neutralize it.
  if (window.grecaptcha && grecaptcha.execute && !grecaptcha.__leotenaPatched) {
    var ex = grecaptcha.execute.bind(grecaptcha);
    grecaptcha.execute = function () {
      try { return ex.apply(grecaptcha, arguments); }
      catch (e) { return undefined; }
    };
    grecaptcha.__leotenaPatched = true;
  }

  var css = document.createElement('style');
  css.textContent = [
    'html,body{margin:0!important;padding:0!important;width:100%!important;height:100%!important;overflow:auto!important;background:#f5f7fa!important}',
    '.panel{position:relative!important;z-index:2147483000!important;margin:3vh auto!important;max-width:min(440px,94vw)!important;background:#fff!important;box-shadow:0 8px 28px rgba(0,0,0,.18)!important}',
    '.title{color:#222!important}',
    '.recaptcha-center{margin-left:auto!important;margin-right:auto!important;display:flex!important;justify-content:center!important}',
    'iframe[src*="recaptcha"],div[class*="g-recaptcha"],#recaptchadiv{position:relative!important;z-index:2147483646!important;pointer-events:auto!important}',
    /* Google challenge popup iframe */
    'iframe[src*="bframe"],iframe[title*="recaptcha"],iframe[title*="challenge"]{z-index:2147483647!important;pointer-events:auto!important}'
  ].join('');
  document.documentElement.appendChild(css);

  window.leotenaPlayer = {
    play: function () {},
    pause: function () {},
    seek: function () {},
    setQuality: function () {},
    setLanguage: function () {}
  };
})();
''');
    } catch (_) {}
  }

  /// Make remote HTML players fill the screen and wire play/quality/language.
  Future<void> _injectEmbedHelpers(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: r'''
(function () {
  if (window.__leotenaEmbedReady) return;
  var t = (document.title || '').toLowerCase();
  var h = (document.documentElement && document.documentElement.innerHTML || '').toLowerCase();
  if (t.indexOf('forbidden') !== -1 || t.indexOf('403') !== -1) return;
  if (h.indexOf('lsrecaptcha') !== -1 || h.indexOf('bot verification') !== -1) return;

  window.__leotenaEmbedReady = true;

  var css = document.createElement('style');
  css.textContent = [
    'html,body{margin:0!important;padding:0!important;width:100%!important;height:100%!important;overflow:hidden!important;background:#000!important}',
    'iframe,video,.video-js,player,.player,#player,#vjs_video_3,canvas{position:fixed!important;inset:0!important;width:100%!important;height:100%!important;max-width:none!important;max-height:none!important;border:0!important;object-fit:cover!important;background:#000!important;z-index:1!important;opacity:1!important;visibility:visible!important}',
    'video{pointer-events:none!important}',
    'header,nav,footer,.ads,.ad,.banner,.navbar,.top-bar,.bottom-bar{display:none!important}'
  ].join('');
  document.documentElement.appendChild(css);

  function pickVideo() {
    return document.querySelector('video');
  }

  function languageCode(value) {
    return (value || 'und').toLowerCase().split('-')[0];
  }

  function getShaka() {
    if (window.__leotenaShaka && typeof window.__leotenaShaka.getVariantTracks === 'function') {
      return window.__leotenaShaka;
    }
    if (window.__leotenaShakas && window.__leotenaShakas.length) {
      for (var i = window.__leotenaShakas.length - 1; i >= 0; i--) {
        var p = window.__leotenaShakas[i];
        if (p && typeof p.getVariantTracks === 'function') return p;
      }
    }
    var names = ['player', 'shakaPlayer', 'Player', 'videoPlayer', 'splayer', 'tvPlayer'];
    for (var n = 0; n < names.length; n++) {
      var cand = window[names[n]];
      if (cand && typeof cand.getVariantTracks === 'function') return cand;
    }
    return null;
  }

  function trackHeight(track) {
    if (track && track.height) return track.height;
    var bw = track && track.bandwidth ? track.bandwidth : 0;
    if (bw <= 0) return 0;
    if (bw < 900000) return 360;
    if (bw < 1800000) return 480;
    if (bw < 3500000) return 720;
    return 1080;
  }

  function pickClosest(tracks, target) {
    if (!tracks || !tracks.length) return null;
    var best = null, bestDiff = 1e9;
    for (var i = 0; i < tracks.length; i++) {
      var d = Math.abs(trackHeight(tracks[i]) - target);
      if (d < bestDiff) { bestDiff = d; best = tracks[i]; }
    }
    return best;
  }

  function emitTracks(activeQuality, activeLanguage) {
    try {
      var player = getShaka();
      var qualities = ['360p','480p','720p','1080p','Auto'];
      var quality = activeQuality || '360p';
      var lang = activeLanguage || 'sw';
      if (player) {
        var tracks = player.getVariantTracks() || [];
        var heights = [];
        tracks.forEach(function (tr) {
          var ht = trackHeight(tr);
          if (ht && heights.indexOf(ht) === -1) heights.push(ht);
        });
        heights.sort(function (a,b) { return a - b; });
        if (heights.length) {
          qualities = heights.map(function (x) { return x + 'p'; }).concat(['Auto']);
        }
        var abr = false;
        try { abr = !!(player.getConfiguration().abr && player.getConfiguration().abr.enabled); } catch (_) {}
        var active = tracks.filter(function (tr) { return tr.active; })[0];
        if (abr) quality = 'Auto';
        else if (active) quality = trackHeight(active) + 'p';
      }
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('playerTracks', {
          qualities: qualities,
          languages: ['sw','en'],
          activeQuality: quality,
          activeLanguage: lang
        });
      }
    } catch (_) {}
  }

  function applyShakaQuality(value) {
    var player = getShaka();
    if (!player) return false;
    try {
      if (value === 'Auto') {
        player.configure({ abr: { enabled: true, restrictions: { maxHeight: 1080 } } });
        emitTracks('Auto');
        return true;
      }
      var target = parseInt(value, 10) || 360;
      var tracks = player.getVariantTracks() || [];
      var chosen = pickClosest(tracks, target);
      if (!chosen) return false;
      player.configure({ abr: { enabled: false, restrictions: { maxHeight: 2160 } } });
      try { player.selectVariantTrack(chosen, true); }
      catch (_) { try { player.selectVariantTrack(chosen, false); } catch (__) {} }
      emitTracks(trackHeight(chosen) + 'p');
      return true;
    } catch (_) {
      return false;
    }
  }

  function applyHlsQuality(value) {
    try {
      if (!window.hls || !window.hls.levels || !window.hls.levels.length) return false;
      if (value === 'Auto') { window.hls.currentLevel = -1; emitTracks('Auto'); return true; }
      var target = parseInt(value, 10) || 360;
      var best = 0, bestDiff = 1e9;
      window.hls.levels.forEach(function (lvl, i) {
        var d = Math.abs((lvl.height || 0) - target);
        if (d < bestDiff) { bestDiff = d; best = i; }
      });
      window.hls.currentLevel = best;
      var h = window.hls.levels[best] && window.hls.levels[best].height;
      emitTracks((h || target) + 'p');
      return true;
    } catch (_) {
      return false;
    }
  }

  function applyLanguage(value) {
    var code = (value === 'en') ? 'en' : 'sw';
    var player = getShaka();
    if (player) {
      try { player.selectAudioLanguage(code); } catch (_) {}
      try {
        var tracks = player.getVariantTracks() || [];
        var langTracks = tracks.filter(function (tr) { return languageCode(tr.language) === code; });
        if (langTracks.length) {
          var active = tracks.filter(function (tr) { return tr.active; })[0];
          var target = active ? trackHeight(active) : 360;
          var chosen = pickClosest(langTracks, target);
          if (chosen) {
            player.configure({ abr: { enabled: false } });
            try { player.selectVariantTrack(chosen, true); } catch (_) {}
          }
        }
      } catch (_) {}
      emitTracks(null, code);
      return;
    }
    try {
      var v = pickVideo();
      if (!v || !v.audioTracks) return;
      for (var i = 0; i < v.audioTracks.length; i++) {
        var at = v.audioTracks[i];
        var lang = (at.language || at.label || '').toLowerCase();
        at.enabled = lang.indexOf(code) === 0 || (code === 'sw' && (lang.indexOf('sw') === 0 || lang.indexOf('swa') === 0));
      }
      emitTracks(null, code);
    } catch (_) {}
  }

  window.leotenaPlayer = {
    play: function () {
      var v = pickVideo();
      if (v) { try { v.muted = false; v.play(); } catch (_) {} }
    },
    pause: function () {
      var v = pickVideo();
      if (v) { try { v.pause(); } catch (_) {} }
    },
    seek: function () {},
    setQuality: function (value) {
      if (applyShakaQuality(value)) return;
      if (applyHlsQuality(value)) return;
      // Retry shortly — embed Shaka may not be ready on first tap.
      setTimeout(function () {
        if (!applyShakaQuality(value)) applyHlsQuality(value);
      }, 400);
    },
    setLanguage: function (value) {
      applyLanguage(value);
    }
  };

  function emit(force) {
    var v = pickVideo();
    try {
      if (window.flutter_inappwebview) {
        window.flutter_inappwebview.callHandler('playerState', {
          playing: v ? (!v.paused && !v.ended) : true,
          buffering: v ? (v.readyState < 3) : false,
          position: v && isFinite(v.currentTime) ? v.currentTime : 0,
          duration: v && isFinite(v.duration) ? v.duration : 0
        });
      }
    } catch (_) {}
  }

  emitTracks('360p', 'sw');
  // Apply defaults once Shaka exists.
  var waits = 0;
  var readyTimer = setInterval(function () {
    waits++;
    if (getShaka() || waits > 40) {
      clearInterval(readyTimer);
      applyShakaQuality('360p');
      applyLanguage('sw');
      emitTracks('360p', 'sw');
    }
  }, 250);

  var v = pickVideo();
  if (v) {
    ['play','pause','playing','waiting','stalled','timeupdate','ended'].forEach(function (n) {
      v.addEventListener(n, function () { emit(n !== 'timeupdate'); });
    });
    try { v.muted = false; var p = v.play(); if (p && p.catch) p.catch(function(){}); } catch (_) {}
  }
  emit(true);
  setInterval(function () { emit(false); }, 2500);
})();
''');
    } catch (_) {}
  }

  String _shakaHtml(PlaybackSource source) {
    final sourceJson = jsonEncode(source.url.trim());
    final clearKeys = <String, String>{};
    if (source.drm == ChannelDrm.clearkey) {
      final parts = source.clearKey.split(':');
      if (parts.length == 2 && parts[0].trim().isNotEmpty && parts[1].trim().isNotEmpty) {
        // Shaka expects hex KID/key without dashes.
        final kid = parts[0].trim().replaceAll('-', '').toLowerCase();
        final key = parts[1].trim().replaceAll('-', '').toLowerCase();
        clearKeys[kid] = key;
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
    video{position:fixed;inset:0;width:100vw;height:100vh;object-fit:cover;background:#000;pointer-events:none}
  </style>
  <script src="https://cdn.jsdelivr.net/npm/shaka-player@4.16.12/dist/shaka-player.compiled.js"></script>
</head>
<body>
  <video id="video" autoplay playsinline webkit-playsinline muted poster=""></video>
  <script>
    const video = document.getElementById('video');
    let player = null;
    let lastStateAt = 0;
    let started = false;
    let preferredLang = 'sw';
    let preferredQuality = '360p';

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
      if (!force && now - lastStateAt < 800) return;
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
    function trackHeight(track) {
      if (track && track.height) return track.height;
      const bw = track && track.bandwidth ? track.bandwidth : 0;
      if (bw <= 0) return 0;
      if (bw < 900000) return 360;
      if (bw < 1800000) return 480;
      if (bw < 3500000) return 720;
      return 1080;
    }
    function pickClosestTrack(tracks, targetHeight) {
      if (!tracks.length) return null;
      let exact = tracks.find(t => trackHeight(t) === targetHeight);
      if (exact) return exact;
      return tracks.slice().sort((a, b) =>
        Math.abs(trackHeight(a) - targetHeight) - Math.abs(trackHeight(b) - targetHeight)
      )[0];
    }
    function tracksForLang(lang) {
      const all = player.getVariantTracks();
      const code = languageCode(lang);
      const matched = all.filter(t => languageCode(t.language) === code);
      return matched.length ? matched : all;
    }
    function emitTracks() {
      if (!player) return;
      const tracks = player.getVariantTracks();
      const heights = [...new Set(tracks.map(t => trackHeight(t)).filter(Boolean))].sort((a,b) => a-b);
      const base = [360, 480, 720, 1080];
      const merged = [...new Set([...base, ...heights])].sort((a,b) => a-b);
      const qualities = [...merged.map(h => h + 'p'), 'Auto'];
      const active = tracks.find(t => t.active);
      const abr = player.getConfiguration().abr.enabled;
      const activeHeight = active ? trackHeight(active) + 'p' : preferredQuality;
      call('playerTracks', {
        qualities,
        languages: ['sw', 'en'],
        activeQuality: abr ? 'Auto' : activeHeight,
        activeLanguage: preferredLang
      });
    }
    async function unmutePlay() {
      try {
        video.muted = false;
        await video.play();
      } catch (_) {
        try { await video.play(); } catch (__) {}
      }
    }
    function applyQuality(value) {
      if (!player) return false;
      preferredQuality = value || '360p';
      if (preferredQuality === 'Auto') {
        player.configure({
          abr: { enabled: true, restrictions: { maxHeight: 1080 }, defaultBandwidthEstimate: 800000 }
        });
        return true;
      }
      const target = parseInt(preferredQuality, 10) || 360;
      // Lift any start-up height cap so 720p/1080p can be selected.
      player.configure({ abr: { enabled: false, restrictions: { maxHeight: 2160 } } });
      const pool = tracksForLang(preferredLang);
      const chosen = pickClosestTrack(pool, target);
      if (!chosen) return false;
      try {
        player.selectVariantTrack(chosen, /* clearBuffer */ true);
      } catch (_) {
        try { player.selectVariantTrack(chosen, false); } catch (__) { return false; }
      }
      preferredQuality = trackHeight(chosen) + 'p';
      return true;
    }
    function applyLanguage(value) {
      if (!player) return;
      preferredLang = (value === 'en') ? 'en' : 'sw';
      try { player.selectAudioLanguage(preferredLang); } catch (_) {}
      applyQuality(preferredQuality);
    }

    window.leotenaPlayer = {
      play: () => unmutePlay(),
      pause: () => video.pause(),
      seek: value => {
        if (Number.isFinite(value) && Number.isFinite(video.duration)) video.currentTime = value;
      },
      setQuality: value => {
        applyQuality(value);
        setTimeout(emitTracks, 150);
      },
      setLanguage: value => {
        applyLanguage(value);
        setTimeout(emitTracks, 180);
      }
    };

    ['play','pause','playing','waiting','stalled','seeking','seeked','timeupdate','durationchange','ended']
      .forEach(name => video.addEventListener(name, () => emitState(name !== 'timeupdate')));

    async function loadNative() {
      video.removeAttribute('src');
      video.src = $sourceJson;
      video.load();
      await unmutePlay();
      emitState(true);
      started = true;
      call('playerTracks', {
        qualities: ['360p','480p','720p','1080p','Auto'],
        languages: ['sw','en'],
        activeQuality: '360p',
        activeLanguage: 'sw'
      });
    }

    async function init() {
      if (started) return;
      try {
        if (typeof shaka === 'undefined') throw new Error('Shaka haikupakiwa');
        shaka.polyfill.installAll();
        if (!shaka.Player.isBrowserSupported()) throw new Error('Kifaa hiki hakitumii Shaka Player.');
        player = new shaka.Player();
        await player.attach(video);
        player.addEventListener('error', event => {
          loadNative().catch(() => call('playerError', errorText(event)));
        });
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
          abr: {
            enabled: false,
            defaultBandwidthEstimate: 600000,
            restrictions: { maxHeight: 360 }
          },
          preferredAudioLanguage: 'sw',
          preferredTextLanguage: 'sw',
          streaming: {
            // Slightly deeper buffer = fewer scratches on unstable mobile nets.
            rebufferingGoal: 2.5,
            bufferingGoal: 12,
            bufferBehind: 20,
            stallEnabled: true,
            retryParameters: { maxAttempts: 4, baseDelay: 250, backoffFactor: 1.6, timeout: 15000 }
          },
          manifest: {
            retryParameters: { maxAttempts: 4, baseDelay: 250, backoffFactor: 1.6, timeout: 12000 }
          },
          drm: { clearKeys: $clearKeysJson }
        });
        await player.load($sourceJson);
        started = true;
        applyLanguage('sw');
        applyQuality('360p');
        // Allow picking higher ladders after the 360p start stick.
        try { player.configure({ abr: { restrictions: { maxHeight: 1080 } } }); } catch (_) {}
        emitTracks();
        emitState(true);
        await unmutePlay();
      } catch (error) {
        try {
          if (player) { try { await player.destroy(); } catch (_) {} player = null; }
          await loadNative();
        } catch (_) {
          call('playerError', errorText(error));
        }
      }
    }
    document.addEventListener('flutterInAppWebViewPlatformReady', init, {once:true});
    setTimeout(() => { if (!started) init(); }, 400);
  </script>
</body>
</html>
''';
  }
}

enum _EmbedPage { ok, forbidden, captcha }

bool _looksLikeMediaUrl(String raw) {
  final url = raw.trim().toLowerCase();
  if (url.isEmpty) return false;

  // Explicit HTML/embed player endpoints must never go through Shaka.
  if (url.contains('player.php') ||
      url.contains('/embed/') ||
      url.contains('embed.php') ||
      (url.contains('/player/') && url.contains('.php'))) {
    return false;
  }

  final uri = Uri.tryParse(raw.trim());
  final path = (uri?.path ?? url).toLowerCase();
  if (path.endsWith('.m3u8') ||
      path.endsWith('.mpd') ||
      path.endsWith('.mp4') ||
      path.endsWith('.webm') ||
      path.endsWith('.mkv') ||
      path.endsWith('.ts') ||
      path.endsWith('.m4v')) {
    return true;
  }

  if (url.contains('m3u8') ||
      url.contains('mpd') ||
      url.contains('format=mp4') ||
      url.contains('type=hls') ||
      url.contains('type=dash')) {
    return true;
  }

  // Unknown non-media URL (often a hosted HTML player) → load as page.
  return false;
}

String _pageOrigin(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return 'https://localhost/';
  }
  return '${uri.scheme}://${uri.host}/';
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

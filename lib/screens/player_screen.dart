import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/channel_art.dart';
import '../widgets/web_stream_player.dart';
import '../app_route_observer.dart';
import '../widgets/premium_lock_modal.dart';

/// Full-screen, landscape-by-default video player with auto-hiding controls,
/// green progress, a buffering animation, and an in-player live-channel
/// switcher that swaps streams without leaving the player.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const PlayerScreen()),
    ));
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver, RouteAware {
  bool _controls = true;
  bool _playing = false;
  bool _buffering = true;
  double _position = 0;
  double _duration = 0;
  String _lang = 'sw';
  String _quality = 'Auto';
  List<String> _languages = const [];
  List<String> _qualities = const ['Auto'];
  String? _playerError;
  int _reloadToken = 0;
  final _streamController = WebStreamController();
  Timer? _hideTimer;

  static const _langLabels = <String, String>{
    'sw': 'Kiswahili',
    'en': 'English',
    'fr': 'Français',
    'ar': 'العربية',
    'pt': 'Português',
    'es': 'Español',
  };

  void _enterLandscapeMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterLandscapeMode();
    _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _enterLandscapeMode();
    }
  }

  @override
  void didPopNext() {
    _enterLandscapeMode();
  }

  void _startBuffer() {
    setState(() {
      _buffering = true;
      _playing = false;
      _position = 0;
      _duration = 0;
      _quality = 'Auto';
      _qualities = const ['Auto'];
      _languages = const [];
      _playerError = null;
      _reloadToken++;
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }

  String _fmt(double seconds) {
    if (!seconds.isFinite || seconds < 0) return '0:00';
    final s = seconds.floor();
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final secs = (s % 60).toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:$secs'
        : '$minutes:$secs';
  }

  void _exit() => Navigator.of(context).maybePop();

  Future<void> _openSwitcher() async {
    await ChannelSwitcherSheet.show(context, onSwitched: () {
      _startBuffer();
    });
    if (mounted) _enterLandscapeMode();
  }

  Future<void> _openLanguagePicker(PlaybackSource src) async {
    _hideTimer?.cancel();
    final picked = await LanguagePickerSheet.show(
      context,
      languages: _languages,
      selected: _lang,
    );
    if (!mounted) return;
    if (picked != null && picked != _lang) {
      setState(() => _buffering = true);
      await _streamController.setLanguage(picked);
    }
    _enterLandscapeMode();
    _scheduleHide();
  }

  Future<void> _openQualityPicker() async {
    _hideTimer?.cancel();
    final picked = await QualityPickerSheet.show(
      context,
      qualities: _qualities,
      selected: _quality,
    );
    if (!mounted) return;
    if (picked != null && picked != _quality) {
      setState(() => _buffering = true);
      await _streamController.setQuality(picked);
    }
    _enterLandscapeMode();
    _scheduleHide();
  }

  Widget _wrapLandscape(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final portrait = constraints.maxHeight > constraints.maxWidth;
        if (!portrait) return child;
        return RotatedBox(
          quarterTurns: 1,
          child: SizedBox(
            width: constraints.maxHeight,
            height: constraints.maxWidth,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final src = state.nowPlaying;

    if (src == null) {
      // Defensive: nothing to play.
      return const Scaffold(backgroundColor: AppColors.navyDeep);
    }

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: _wrapLandscape(
        GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real Shaka web-player surface using the clicked item's URL.
              WebStreamPlayer(
                key: ValueKey('${src.channelId ?? src.title}|${src.url}|$_reloadToken'),
                source: src,
                controller: _streamController,
                onState: ({
                  bool? playing,
                  bool? buffering,
                  double? position,
                  double? duration,
                }) {
                  if (!mounted) return;
                  setState(() {
                    if (playing != null) _playing = playing;
                    if (buffering != null) _buffering = buffering;
                    if (position != null) _position = position;
                    if (duration != null) _duration = duration;
                  });
                },
                onQualities: (items) {
                  if (!mounted) return;
                  setState(() => _qualities = items.isEmpty ? const ['Auto'] : items);
                },
                onLanguages: (items) {
                  if (!mounted) return;
                  setState(() => _languages = items);
                },
                onQualityChanged: (value) {
                  if (mounted) setState(() => _quality = value);
                },
                onLanguageChanged: (value) {
                  if (mounted) setState(() => _lang = value);
                },
                onError: (message) {
                  if (!mounted) return;
                  setState(() {
                    _buffering = false;
                    _playing = false;
                    _playerError = message;
                  });
                },
              ),

              if (_buffering && _playerError == null)
                const Center(
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(strokeWidth: 4, color: AppColors.green),
                  ),
                ),

              if (_playerError != null) _errorOverlay(),

              // Controls overlay.
              AnimatedOpacity(
                opacity: _controls ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_controls,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF06122A).withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.transparent,
                          const Color(0xFF06122A).withValues(alpha: 0.78),
                        ],
                        stops: const [0, 0.28, 0.62, 1],
                      ),
                    ),
                    child: Stack(
                      children: [
                        _topBar(src),
                        _centerTransport(),
                        _bottomBar(src),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(PlaybackSource src) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 0),
        child: Row(
          children: [
            _circleBtn(Icons.chevron_left_rounded, _exit),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(src.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(15, color: Colors.white, weight: FontWeight.w700)),
                  Text(src.subtitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(11.5, color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _centerTransport() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () async {
              if (_playing) {
                await _streamController.pause();
              } else {
                await _streamController.play();
              }
              _scheduleHide();
            },
            child: Container(
              width: 74, height: 74,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(PlaybackSource src) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (src.isChannel)
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const PulseDot(color: Colors.white, size: 7),
                    const SizedBox(width: 6),
                    Text('MOJA KWA MOJA', style: AppTheme.body(11, color: Colors.white, weight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Container(height: 6,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(3))),
                ),
              ])
            else
              Row(children: [
                Text(_fmt(_position),
                    style: AppTheme.body(11.5, color: Colors.white, weight: FontWeight.w700)),
                const SizedBox(width: 11),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 6,
                      activeTrackColor: AppColors.green,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                      thumbColor: Colors.white,
                      overlayShape: SliderComponentShape.noOverlay,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _duration > 0 ? _position.clamp(0, _duration) : 0,
                      max: _duration > 0 ? _duration : 1,
                      onChanged: _duration > 0
                          ? (value) {
                              setState(() => _position = value);
                              _streamController.seek(value);
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(_fmt(_duration), style: AppTheme.body(11.5, color: Colors.white.withValues(alpha: 0.6), weight: FontWeight.w700)),
              ]),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                if (_languages.length > 1)
                  _tool(
                    Icons.translate_rounded,
                    _langLabels[_lang] ?? 'Kiswahili',
                    () => _openLanguagePicker(src),
                  ),
                if (_qualities.length > 1)
                  _tool(Icons.high_quality_rounded, _quality, _openQualityPicker),
                _tool(Icons.live_tv_rounded, src.isChannel ? 'Badili Kituo' : 'Vituo', _openSwitcher, accent: true),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap, {bool accent = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: accent ? AppColors.green : Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label, style: AppTheme.body(11.5, color: Colors.white, weight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _errorOverlay() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xE61A2740),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 42),
            const SizedBox(height: 10),
            Text(
              'Video haikuweza kuchezwa',
              style: AppTheme.body(16, color: Colors.white, weight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _playerError ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTheme.body(11.5, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _startBuffer,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.green),
              label: Text(
                'Jaribu tena',
                style: AppTheme.body(13, color: Colors.white, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

/// In-player live channel switcher (modern bottom sheet). Switches streams
/// instantly; premium ("Malipo") channels route to the payment screen when
/// the user is not subscribed.
class ChannelSwitcherSheet extends StatefulWidget {
  final VoidCallback onSwitched;
  const ChannelSwitcherSheet({super.key, required this.onSwitched});

  static Future<void> show(BuildContext context, {required VoidCallback onSwitched}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF06122A).withValues(alpha: 0.55),
      builder: (_) => ChannelSwitcherSheet(onSwitched: onSwitched),
    );
  }

  @override
  State<ChannelSwitcherSheet> createState() => _ChannelSwitcherSheetState();
}

class _ChannelSwitcherSheetState extends State<ChannelSwitcherSheet> {
  String _cat = 'zote';
  static const _cats = <(String, String, IconData)>[
    ('zote', 'Zote', Icons.grid_view_rounded),
    ('movies', 'Movies', Icons.movie_rounded),
    ('tamthilia', 'Tamthilia', Icons.theater_comedy_rounded),
    ('football', 'Football', Icons.sports_soccer_rounded),
    ('wanyama', 'Wanyama', Icons.pets_rounded),
    ('katuni', 'Katuni', Icons.animation_rounded),
    ('burudani', 'Burudani', Icons.celebration_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.currentChannel;
    final list = state.channels.where((c) => _cat == 'zote' || c.category == _cat).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 42, height: 5, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFD6E7F5), borderRadius: BorderRadius.circular(3))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Badili Kituo', style: AppTheme.heading(19)),
                  Text('${state.channels.length} vituo vya moja kwa moja',
                      style: AppTheme.body(11, color: AppColors.textHint, weight: FontWeight.w700)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const PulseDot(size: 7),
                  const SizedBox(width: 6),
                  Text('LIVE', style: AppTheme.body(11, color: AppColors.green, weight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),

          // Now playing preview.
          if (current != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  _preview(current),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('UNATAZAMA SASA', style: AppTheme.body(10, color: AppColors.green, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(current.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(15, color: AppColors.textPrimary, weight: FontWeight.w800)),
                      Row(children: [
                        const Icon(Icons.tv_rounded, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(current.program,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(11.5, color: AppColors.textHint)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),

          // Category chips.
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _cats.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _cats[i];
                final active = cat.$1 == _cat;
                final color = active ? Colors.white : AppColors.textSecondary;
                return GestureDetector(
                  onTap: () => setState(() => _cat = cat.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: active ? const LinearGradient(colors: [AppColors.navy, AppColors.navyMid]) : null,
                      color: active ? null : AppColors.section,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$3, size: 15, color: color),
                        const SizedBox(width: 5),
                        Text(
                          cat.$2,
                          style: AppTheme.body(12, color: color, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (_, i) => _channelRow(context, state, list[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(Channel c) {
    return SizedBox(
      width: 96,
      height: 58,
      child: Stack(
        children: [
          ChannelArt(
            channel: c,
            width: 96,
            height: 58,
            borderRadius: BorderRadius.circular(14),
          ),
          const Positioned(top: 6, left: 6, child: GreenBadge('● LIVE')),
          const Positioned(bottom: 6, right: 7, child: Equalizer(color: Colors.white, height: 13)),
        ],
      ),
    );
  }

  Widget _channelRow(BuildContext context, AppState state, Channel c) {
    final current = state.nowChannelId == c.id;
    final locked = state.channelLocked(c);
    return GestureDetector(
      onTap: () {
        if (locked) {
          Navigator.of(context).pop();
          PremiumLockModal.show(context);
          return;
        }
        if (state.switchChannel(c)) {
          Navigator.of(context).pop();
          widget.onSwitched();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: current ? AppColors.green.withValues(alpha: 0.07) : AppColors.section,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: current ? AppColors.green.withValues(alpha: 0.35) : Colors.transparent, width: 1.5),
        ),
        child: Row(children: [
          SizedBox(
            width: 78,
            height: 52,
            child: ChannelArt(
              channel: c,
              width: 78,
              height: 52,
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(
                  child: Text(c.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(14.5, color: AppColors.textPrimary, weight: FontWeight.w700)),
                ),
                if (c.premium) ...[const SizedBox(width: 7), const PremiumChannelBadge()],
              ]),
              const SizedBox(height: 2),
              Text(c.program, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(11.5, color: AppColors.textHint)),
            ]),
          ),
          const SizedBox(width: 8),
          if (current)
            const Equalizer(height: 16)
          else if (locked)
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            )
          else
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), boxShadow: AppColors.shadow(blur: 16, y: 8, opacity: 0.3)),
              child: const Icon(Icons.play_arrow_rounded, color: AppColors.green, size: 20),
            ),
        ]),
      ),
    );
  }
}

/// Audio language picker — Kiswahili / English when tracks are available.
class LanguagePickerSheet extends StatelessWidget {
  final List<String> languages;
  final String selected;
  const LanguagePickerSheet({super.key, required this.languages, required this.selected});

  static const _labels = <String, String>{
    'sw': 'Kiswahili',
    'en': 'English',
  };

  static Future<String?> show(
    BuildContext context, {
    required List<String> languages,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF06122A).withValues(alpha: 0.55),
      builder: (_) => LanguagePickerSheet(languages: languages, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFD6E7F5), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Text('Lugha', style: AppTheme.heading(19)),
          const SizedBox(height: 4),
          Text('Chagua lugha ya sauti', style: AppTheme.body(12, color: AppColors.textHint, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...languages.map((code) {
            final active = code == selected;
            final label = _labels[code] ?? code.toUpperCase();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(code),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.green.withValues(alpha: 0.10) : AppColors.section,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? AppColors.green.withValues(alpha: 0.45) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          color: active ? AppColors.green : AppColors.navy,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: AppTheme.body(15, color: AppColors.textPrimary, weight: FontWeight.w700),
                          ),
                        ),
                        if (active)
                          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22)
                        else
                          Icon(Icons.circle_outlined, color: AppColors.textHint.withValues(alpha: 0.5), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Stream quality picker — values come from the loaded manifest.
class QualityPickerSheet extends StatelessWidget {
  final List<String> qualities;
  final String selected;
  const QualityPickerSheet({super.key, required this.qualities, required this.selected});

  static Future<String?> show(
    BuildContext context, {
    required List<String> qualities,
    required String selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF06122A).withValues(alpha: 0.55),
      builder: (_) => QualityPickerSheet(qualities: qualities, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFD6E7F5), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          Text('Ubora', style: AppTheme.heading(19)),
          const SizedBox(height: 4),
          Text('Chagua ubora wa video', style: AppTheme.body(12, color: AppColors.textHint, weight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...qualities.map((q) {
            final active = q == selected;
            final isDefault = q == 'Auto';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(q),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.green.withValues(alpha: 0.10) : AppColors.section,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? AppColors.green.withValues(alpha: 0.45) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.high_quality_rounded,
                          color: active ? AppColors.green : AppColors.navy,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                q,
                                style: AppTheme.body(15, color: AppColors.textPrimary, weight: FontWeight.w700),
                              ),
                              if (isDefault) ...[
                                const SizedBox(width: 8),
                                Text(
                                  'chaguo-msingi',
                                  style: AppTheme.body(11, color: AppColors.textHint, weight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (active)
                          const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 22)
                        else
                          Icon(Icons.circle_outlined, color: AppColors.textHint.withValues(alpha: 0.5), size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

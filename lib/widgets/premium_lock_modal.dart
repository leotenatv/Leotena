import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'common.dart';

/// Premium unlock as a centered card carousel (side cards peek in).
class PremiumLockModal extends StatefulWidget {
  const PremiumLockModal({super.key});

  static const scripts = <String>[
    'Ndugu, fungua chaneli zote kwa kufanya malipo. Ni rahisi tu.',
    'Weka majina yako kamili na nambari ya simu, kisha gusa Endelea.',
    'Chagua kifurushi unachotaka, kisha gusa Lipia sasa.',
    'Tafadhali subiri. Tunangoja uthibitisho wa malipo yako.',
  ];

  static const successScript =
      'Hongera! Malipo yamefanikiwa. Chaneli zote zimefunguliwa. Furahia kutazama.';

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'premium-carousel',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => const PremiumLockModal(),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<PremiumLockModal> createState() => _PremiumLockModalState();
}

class _PremiumLockModalState extends State<PremiumLockModal> with TickerProviderStateMixin {
  late final PageController _pageCtrl;
  final _tts = FlutterTts();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  AnimationController? _pulse;
  AnimationController? _wave;
  AnimationController? _waitSpin;
  AnimationController? _successPop;

  Timer? _confirmTimer;
  int _page = 0;
  bool _speaking = false;
  bool _paymentSuccess = false;
  String? _formError;
  String _selectedPkgId = 'mwezi';

  static const _viewport = 0.78;

  void _ensureAnims() {
    _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _wave ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _waitSpin ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _successPop ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 780));
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: _viewport);
    _ensureAnims();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.userName != 'Mtumiaji') _nameCtrl.text = state.userName;
      if (state.phoneNumber.isNotEmpty) _phoneCtrl.text = state.phoneNumber;
      final pkgs = state.packages;
      if (pkgs.isNotEmpty) {
        final popular = pkgs.where((p) => p.popular);
        _selectedPkgId = popular.isNotEmpty ? popular.first.id : pkgs.first.id;
      }
      _speak(_page);
    });
  }

  Future<void> _speakText(String message) async {
    try {
      await _tts.stop();
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      var spoken = message;
      final langs = await _tts.getLanguages;
      if (langs is List) {
        final list = langs.map((e) => e.toString().toLowerCase()).toList();
        if (list.any((l) => l.contains('sw'))) {
          await _tts.setLanguage(list.firstWhere((l) => l.contains('sw')));
        } else {
          await _tts.setLanguage('en-US');
        }
      }
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      if (mounted) setState(() => _speaking = true);
      await _tts.speak(spoken);
    } catch (_) {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<bool> _hasSwahiliVoice() async {
    try {
      final langs = await _tts.getLanguages;
      if (langs is! List) return false;
      return langs
          .map((e) => e.toString().toLowerCase())
          .any((l) => l.contains('sw'));
    } catch (_) {
      return false;
    }
  }

  Future<void> _speak(int step) async {
    if (_paymentSuccess) {
      await _speakText(PremiumLockModal.successScript);
      return;
    }
    var message = PremiumLockModal.scripts[step.clamp(0, 3)];
    if (!await _hasSwahiliVoice()) {
      message = [
        'Dear user, unlock all channels by making a payment. It is very easy.',
        'Enter your full name and phone number, then tap Continue.',
        'Choose a package, then tap Pay now.',
        'Please wait. We are waiting for your payment confirmation.',
      ][step.clamp(0, 3)];
    }
    await _speakText(message);
  }

  Future<void> _stopAudio() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  void _schedulePaymentSuccess() {
    _confirmTimer?.cancel();
    _paymentSuccess = false;
    _successPop?.reset();
    _waitSpin
      ?..reset()
      ..repeat();
    _confirmTimer = Timer(const Duration(milliseconds: 3200), () async {
      if (!mounted || _page != 3) return;
      context.read<AppState>().confirmPayment();
      _waitSpin?.stop();
      setState(() => _paymentSuccess = true);
      await _successPop?.forward(from: 0);
      if (mounted) await _speakText(PremiumLockModal.successScript);
    });
  }

  Future<void> _goTo(int page, {bool speak = true}) async {
    if (page < 0 || page > 3) return;
    await _stopAudio();
    if (!mounted) return;
    if (page != 3) {
      _confirmTimer?.cancel();
      _paymentSuccess = false;
    }
    setState(() {
      _page = page;
      _formError = null;
    });
    await _pageCtrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
    if (page == 3) _schedulePaymentSuccess();
    if (speak && mounted && !_paymentSuccess) _speak(page);
  }

  Future<void> _close() async {
    _confirmTimer?.cancel();
    await _stopAudio();
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) Navigator.of(context).pop();
  }

  bool _validateDetails() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _formError = 'Tafadhali jaza jina na nambari ya simu');
      return false;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 9) {
      setState(() => _formError = 'Nambari ya simu si sahihi');
      return false;
    }
    context.read<AppState>().setProfile(name: name, phone: phone);
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  Future<void> _next() async {
    if (_paymentSuccess) {
      await _close();
      return;
    }
    if (_page == 1 && !_validateDetails()) {
      await _goTo(1, speak: false);
      return;
    }
    if (_page == 2) {
      final pkgs = context.read<AppState>().packages;
      final pkg = pkgs.firstWhere((p) => p.id == _selectedPkgId, orElse: () => pkgs.first);
      context.read<AppState>().submitPaymentPending(pkg);
    }
    if (_page >= 3) {
      // Still waiting — ignore or stay
      return;
    }
    await _goTo(_page + 1);
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _pulse?.dispose();
    _wave?.dispose();
    _waitSpin?.dispose();
    _successPop?.dispose();
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    // Fire-and-forget — must catch async MissingPluginException (e.g. Linux / hot reload).
    _tts.stop().then((_) {}, onError: (_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnims();
    final r = R.of(context);
    final size = r.size;
    final kb = r.viewInsets.bottom;
    final topSafe = r.padding.top;
    final keyboardOpen = kb > 40;
    final chrome = keyboardOpen ? 72.0 : 108.0;
    final available = size.height - kb - topSafe - chrome;
    final cardH = keyboardOpen
        ? available.clamp(240.0, 520.0)
        : r.modalCardMaxH;

    return Material(
      color: Colors.transparent,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: kb),
        child: Stack(
          children: [
            // Frosted blur over whatever is behind the modal.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0F2748).withOpacity(0.38),
                            const Color(0xFF0F2748).withOpacity(0.52),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                      child: Row(
                        children: [
                          Expanded(child: _dots()),
                          IconButton(
                            onPressed: _close,
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!keyboardOpen) const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: keyboardOpen ? Alignment.bottomCenter : Alignment.center,
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: SizedBox(
                            height: cardH,
                            child: PageView.builder(
                              controller: _pageCtrl,
                              itemCount: 4,
                              physics: _paymentSuccess
                                  ? const NeverScrollableScrollPhysics()
                                  : const PageScrollPhysics(),
                              onPageChanged: (i) {
                                setState(() {
                                  _page = i;
                                  _formError = null;
                                });
                                if (i == 3) {
                                  _schedulePaymentSuccess();
                                } else {
                                  _confirmTimer?.cancel();
                                  _paymentSuccess = false;
                                }
                                if (!_paymentSuccess) _speak(i);
                              },
                              itemBuilder: (context, index) {
                                return AnimatedBuilder(
                                  animation: _pageCtrl,
                                  builder: (context, child) {
                                    var scale = 1.0;
                                    var opacity = 1.0;
                                    if (_pageCtrl.position.haveDimensions) {
                                      final dist = (_pageCtrl.page ?? _page.toDouble()) - index;
                                      scale = (1 - dist.abs() * (keyboardOpen ? 0.06 : 0.12))
                                          .clamp(keyboardOpen ? 0.94 : 0.86, 1.0);
                                      opacity = (1 - dist.abs() * 0.35).clamp(0.55, 1.0);
                                    } else if (index != _page) {
                                      scale = 0.88;
                                      opacity = 0.7;
                                    }
                                    return Transform.scale(
                                      scale: scale,
                                      child: Opacity(opacity: opacity, child: child),
                                    );
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: keyboardOpen ? 4 : 8,
                                      vertical: keyboardOpen ? 4 : 10,
                                    ),
                                    child: _CarouselCard(
                                      child: _cardBody(index, cardH),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!keyboardOpen)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _pageLabel,
                                style: AppTheme.body(13, color: Colors.white.withOpacity(0.85), weight: FontWeight.w600),
                              ),
                            ),
                            _NextFab(
                              onTap: _next,
                              isLast: _page >= 3,
                              success: _paymentSuccess,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _pageLabel {
    if (_paymentSuccess) return 'Imefanikiwa';
    switch (_page) {
      case 0:
        return 'Hatua 1 / 4';
      case 1:
        return 'Hatua 2 / 4';
      case 2:
        return 'Hatua 3 / 4';
      default:
        return 'Hatua 4 / 4';
    }
  }

  Widget _dots() {
    return Row(
      children: List.generate(4, (i) {
        final on = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.only(right: 6),
          width: on ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? AppColors.green : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _cardBody(int index, double cardH) {
    switch (index) {
      case 0:
        return _introCard();
      case 1:
        return _detailsCard();
      case 2:
        return _pricesCard();
      default:
        return _waitingCard();
    }
  }

  Widget _introCard() {
    return _CardScaffold(
      hero: _HeroPanel(icon: Icons.lock_open_rounded, pulse: _pulse!),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    'Ndugu Fungua chaneli zote kwa kufanya malipo, ni rahisi tu',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading(18).copyWith(height: 1.28),
                  ),
                  const SizedBox(height: 12),
                  _audioStrip(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Fungua Chaneli zote sasa',
            icon: Icons.play_arrow_rounded,
            onTap: () => _goTo(1),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    return _CardScaffold(
      hero: _HeroPanel(icon: Icons.person_rounded, pulse: _pulse!, compact: true),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text('Taarifa Zako', style: AppTheme.heading(18)),
                  const SizedBox(height: 10),
                  _audioStrip(),
                  const SizedBox(height: 12),
                  _field(_nameCtrl, 'Weka majina yako kamili', Icons.badge_rounded),
                  const SizedBox(height: 8),
                  _field(_phoneCtrl, 'Nambari ya simu', Icons.phone_rounded, TextInputType.phone),
                  if (_formError != null) ...[
                    const SizedBox(height: 8),
                    Text(_formError!, style: AppTheme.body(12, color: Colors.redAccent, weight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Endelea',
            icon: Icons.arrow_forward_rounded,
            onTap: () {
              if (_validateDetails()) _goTo(2);
            },
          ),
        ],
      ),
    );
  }

  Widget _pricesCard() {
    final packages = context.watch<AppState>().packages;
    return _CardScaffold(
      heroHeight: 120,
      hero: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Chagua Kifurushi', style: AppTheme.heading(18, color: Colors.white)),
            const SizedBox(height: 10),
            _audioStrip(lite: true),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: packages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final pk = packages[i];
                final on = pk.id == _selectedPkgId;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPkgId = pk.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: on ? AppColors.green.withOpacity(0.08) : AppColors.section,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: on ? AppColors.green : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? AppColors.green : Colors.transparent,
                            border: Border.all(color: on ? AppColors.green : const Color(0xFFC9DEF0), width: 2),
                          ),
                          child: on ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(pk.name,
                                        style: AppTheme.body(13.5, color: AppColors.textPrimary, weight: FontWeight.w800)),
                                  ),
                                  if (pk.popular) ...[const SizedBox(width: 6), const GreenBadge('MAARUFU')],
                                ],
                              ),
                              Text(pk.note, style: AppTheme.body(10.5, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        Text('TSh ${pk.price}', style: AppTheme.heading(14)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Lipia sasa',
            icon: Icons.payments_rounded,
            onTap: () async {
              final pkgs = context.read<AppState>().packages;
              final pkg = pkgs.firstWhere((p) => p.id == _selectedPkgId, orElse: () => pkgs.first);
              context.read<AppState>().submitPaymentPending(pkg);
              await _goTo(3);
            },
          ),
        ],
      ),
    );
  }

  Widget _waitingCard() {
    final pending = context.watch<AppState>().pendingPackage;
    return _CardScaffold(
      hero: _paymentSuccess
          ? _SuccessTick(controller: _successPop!)
          : _HeroPanel(icon: Icons.hourglass_top_rounded, pulse: _waitSpin!, spinning: true),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  Text(
                    _paymentSuccess ? 'Malipo Yamefanikiwa!' : 'Tunasubiri uthibitisho',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading(18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _paymentSuccess
                        ? 'Chaneli zote zimefunguliwa. Karibu ufurahie Premium.'
                        : pending == null
                            ? 'Malipo yako yanashughulikiwa…'
                            : 'Kifurushi: ${pending.name} • TSh ${pending.price}\nTunangoja uthibitisho wa malipo yako.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body(13, color: AppColors.textSecondary).copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _audioStrip(),
                  if (!_paymentSuccess) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        'Tafadhali subiri kidogo…',
                        textAlign: TextAlign.center,
                        style: AppTheme.body(12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_paymentSuccess)
            PrimaryButton(
              label: 'Endelea Kutazama',
              icon: Icons.play_arrow_rounded,
              onTap: _close,
            )
          else
            GestureDetector(
              onTap: _close,
              child: Text('Funga', style: AppTheme.body(14, color: AppColors.navyMid, weight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _audioStrip({bool lite = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: lite ? 8 : 10),
      decoration: BoxDecoration(
        color: lite ? Colors.white.withOpacity(0.16) : AppColors.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _speaking ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: lite ? Colors.white : AppColors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _speaking
                ? AnimatedBuilder(
                    animation: _wave!,
                    builder: (_, __) => Row(
                      children: List.generate(5, (i) {
                        final phase = (_wave!.value + i * 0.14) % 1.0;
                        final h = 4.0 + (10.0 * (0.35 + 0.65 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0)));
                        return Container(
                          width: 3,
                          height: h,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: lite ? Colors.white : AppColors.green,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  )
                : Text(
                    'Gusa kusikiliza tena',
                    style: AppTheme.body(11.5, color: lite ? Colors.white70 : AppColors.textHint),
                  ),
          ),
          GestureDetector(
            onTap: () {
              if (_speaking) {
                _stopAudio();
              } else {
                _speak(_page);
              }
            },
            child: Icon(
              _speaking ? Icons.stop_rounded : Icons.replay_rounded,
              color: lite ? Colors.white : AppColors.navyMid,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, [TextInputType? type]) {
    return TextField(
      controller: c,
      keyboardType: type,
      scrollPadding: const EdgeInsets.only(bottom: 160),
      style: AppTheme.body(14, color: AppColors.textPrimary, weight: FontWeight.w600),
      onChanged: (_) {
        if (_formError != null) setState(() => _formError = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.body(12.5, color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.navyMid, size: 18),
        filled: true,
        fillColor: AppColors.section,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  final Widget child;
  const _CarouselCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.navy.withOpacity(0.14), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2748).withOpacity(0.32),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(color: Colors.white, child: child),
      ),
    );
  }
}

class _CardScaffold extends StatelessWidget {
  final Widget hero;
  final Widget child;
  final double heroHeight;

  const _CardScaffold({
    required this.hero,
    required this.child,
    this.heroHeight = 168,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: heroHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navyMid, AppColors.navy],
              ),
            ),
            child: hero,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final IconData icon;
  final AnimationController pulse;
  final bool compact;
  final bool spinning;

  const _HeroPanel({
    required this.icon,
    required this.pulse,
    this.compact = false,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, __) {
          final t = spinning ? pulse.value * 2 * math.pi : 0.0;
          final scale = spinning ? 1.0 : (0.94 + pulse.value * 0.06);
          return Transform.rotate(
            angle: t,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: compact ? 64 : 78,
                height: compact ? 64 : 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.16),
                  border: Border.all(color: Colors.white.withOpacity(0.28), width: 2),
                ),
                child: Icon(icon, color: Colors.white, size: compact ? 30 : 34),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NextFab extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLast;
  final bool success;

  const _NextFab({required this.onTap, required this.isLast, this.success = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: success
                ? const [AppColors.green, AppColors.greenDark]
                : const [AppColors.green, AppColors.greenDark],
          ),
          boxShadow: AppColors.greenGlow(),
        ),
        child: Icon(
          success
              ? Icons.check_rounded
              : (isLast ? Icons.hourglass_top_rounded : Icons.chevron_right_rounded),
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class _SuccessTick extends StatelessWidget {
  final AnimationController controller;
  const _SuccessTick({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t = Curves.easeOutBack.transform(controller.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: 0.4 + (0.6 * t),
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withOpacity(0.45),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

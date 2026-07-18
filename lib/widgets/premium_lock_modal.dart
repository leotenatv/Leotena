import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../utils/payment_voices.dart';
import '../data/payment_config.dart';
import '../data/sonicpesa_payment_service.dart';
import 'common.dart';

/// Premium unlock as a centered card carousel (side cards peek in).
class PremiumLockModal extends StatefulWidget {
  const PremiumLockModal({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'premium-carousel',
      barrierColor: const Color(0x990F2748),
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
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _formScrollCtrl = ScrollController();

  AnimationController? _pulse;
  AnimationController? _wave;
  AnimationController? _waitSpin;
  AnimationController? _successPop;

  Timer? _confirmTimer;
  int _page = 0;
  bool _speaking = false;
  bool _paymentSuccess = false;
  bool _paymentBusy = false;
  String? _formError;
  String _selectedPkgId = 'mwezi';
  String _waitingHint = 'Tafadhali subiri kidogo…';

  void _ensureAnims() {
    _pulse ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _wave ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _waitSpin ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _successPop ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 780));
  }

  @override
  void initState() {
    super.initState();
    _ensureAnims();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.userName != 'Mtumiaji') _nameCtrl.text = state.userName;
      if (state.phoneNumber.isNotEmpty) _phoneCtrl.text = state.phoneNumber;
      final pkgs = state.packages;
      if (pkgs.isNotEmpty) {
        final popular = pkgs.where((p) => p.popular);
        _selectedPkgId = popular.isNotEmpty ? popular.first.id : pkgs.first.id;
      }
      await PaymentVoices.prepare();
      if (!mounted) return;
      _speak(_page);
    });
  }

  Future<void> _speak(int step) async {
    if (_paymentSuccess) {
      await PaymentVoices.playAsset(
        PaymentVoices.successAsset,
        onStart: () {
          if (mounted) setState(() => _speaking = true);
        },
        onDone: () {
          if (mounted) setState(() => _speaking = false);
        },
      );
      return;
    }
    await PaymentVoices.playStep(
      step.clamp(0, 3),
      onStart: () {
        if (mounted) setState(() => _speaking = true);
      },
      onDone: () {
        if (mounted) setState(() => _speaking = false);
      },
    );
  }

  Future<void> _stopAudio() async {
    await PaymentVoices.stop();
    if (mounted) setState(() => _speaking = false);
  }

  void _schedulePaymentSuccess() {
    _confirmTimer?.cancel();
    _paymentSuccess = false;
    _paymentBusy = true;
    _successPop?.reset();
    _waitSpin
      ?..reset()
      ..repeat();
    unawaited(_runSonicPaymentFlow());
  }

  Future<void> _runSonicPaymentFlow() async {
    final state = context.read<AppState>();
    final pkgs = state.packages;
    if (pkgs.isEmpty) {
      if (!mounted) return;
      setState(() {
        _paymentBusy = false;
        _waitingHint = 'Hakuna kifurushi kinachopatikana. Jaribu tena baadaye.';
      });
      return;
    }
    final pkg = pkgs.firstWhere((p) => p.id == _selectedPkgId, orElse: () => pkgs.first);
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    try {
      final init = await state.initiateSonicPayment(pkg: pkg, name: name, phone: phone);
      if (!mounted || _page != 3) return;

      // Never unlock on initiate alone — wait for PIN confirmation via status polling.
      // (Local TSh-0 complete is disabled in production.)
      if (init.completed && init.local) {
        // Dev-only path if ALLOW_LOCAL_PAYMENTS is enabled on a local server.
        await _markPaymentSuccess();
        return;
      }

      setState(() {
        _waitingHint = init.message.isNotEmpty ? init.message : PaymentConfig.paymentPromptFor(phone);
      });

      const maxAttempts = 90;
      for (var i = 0; i < maxAttempts; i++) {
        final delay = i < 20 ? const Duration(seconds: 1) : const Duration(seconds: 2);
        await Future.delayed(delay);
        if (!mounted || _page != 3 || _paymentSuccess) return;

        try {
          final status = await state.pollSonicPayment(
            orderId: init.orderId,
            userName: name,
            phone: phone,
          );
          if (status.completed) {
            await _markPaymentSuccess();
            return;
          }
          if (status.failed) {
            if (!mounted) return;
            setState(() {
              _paymentBusy = false;
              _waitingHint = status.message?.isNotEmpty == true
                  ? status.message!
                  : 'Malipo hayajakamilika. Jaribu tena.';
            });
            return;
          }
        } on SonicpesaPaymentException catch (e) {
          final code = e.statusCode;
          if (code == 502 || code == 503 || code == 504) {
            if (mounted) {
              setState(() => _waitingHint = 'Seva inaendelea kuchakata malipo…');
            }
            continue;
          }
          // Soft: keep waiting instead of hard-failing transient issues.
          if (mounted) {
            setState(() => _waitingHint = PaymentConfig.paymentPromptFor(phone));
          }
          continue;
        }

        if (!mounted) return;
        setState(() {
          _waitingHint = i < 8
              ? PaymentConfig.paymentPromptFor(phone)
              : 'Bado tunasubiri uthibitisho wa ${PaymentConfig.networkLabel(PaymentConfig.detectNetwork(phone))}…';
        });
      }

      if (!mounted) return;
      setState(() {
        _paymentBusy = false;
        _waitingHint =
            'Muda wa kusubiri malipo umeisha. Hakikisha umethibitisha PIN kwenye simu, kisha jaribu tena.';
      });
    } on SonicpesaPaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentBusy = false;
        _waitingHint = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paymentBusy = false;
        _waitingHint = 'Hitilafu ya mtandao. Jaribu tena.';
      });
    }
  }

  Future<void> _markPaymentSuccess() async {
    if (!mounted || _page != 3) return;
    _waitSpin?.stop();
    setState(() {
      _paymentSuccess = true;
      _paymentBusy = false;
      _waitingHint = 'Chaneli zote zimefunguliwa. Karibu ufurahie Premium.';
    });
    await _successPop?.forward(from: 0);
    if (mounted) {
      await PaymentVoices.playAsset(
        PaymentVoices.successAsset,
        onStart: () {
          if (mounted) setState(() => _speaking = true);
        },
        onDone: () {
          if (mounted) setState(() => _speaking = false);
        },
      );
    }
  }

  /// Button-only navigation — no swipe / PageView.
  Future<void> _goTo(int page, {bool speak = true}) async {
    if (page < 0 || page > 3 || page == _page) return;
    await _stopAudio();
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();

    if (page != 3) {
      _confirmTimer?.cancel();
      _paymentSuccess = false;
    }

    setState(() {
      _page = page;
      _formError = null;
    });

    if (page == 3) _schedulePaymentSuccess();
    if (speak && mounted && !_paymentSuccess) _speak(page);
  }

  Future<void> _back() async {
    if (_page <= 0 || _page >= 3) return;
    await _goTo(_page - 1);
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
    if (!PaymentConfig.isValidFullName(name)) {
      setState(() => _formError = 'Tafadhali jaza jina kamili (angalau majina mawili)');
      return false;
    }
    if (!PaymentConfig.isValidTzLocalPhone(phone)) {
      setState(() => _formError = 'Namba ya simu si sahihi. Tumia 07…, 06… au 255…');
      return false;
    }
    final local = PaymentConfig.normalizeTzLocalPhone(phone)!;
    context.read<AppState>().setProfile(name: name, phone: local);
    FocusManager.instance.primaryFocus?.unfocus();
    return true;
  }

  Future<void> _next() async {
    if (_paymentSuccess) {
      await _close();
      return;
    }
    if (_page == 1 && !_validateDetails()) return;
    if (_page == 2) {
      final pkgs = context.read<AppState>().packages;
      final pkg = pkgs.firstWhere((p) => p.id == _selectedPkgId, orElse: () => pkgs.first);
      context.read<AppState>().submitPaymentPending(pkg);
    }
    if (_page >= 3) return;
    await _goTo(_page + 1);
  }

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _formScrollCtrl.dispose();
    _pulse?.dispose();
    _wave?.dispose();
    _waitSpin?.dispose();
    _successPop?.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    PaymentVoices.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureAnims();
    final r = R.of(context);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = kb > 40;
    final canGoBack = _page > 0 && _page < 3 && !_paymentSuccess;
    // One lift only — avoid double-padding that shoved the card off-screen.
    final maxCardH = keyboardOpen
        ? (r.size.height - r.padding.top - 88).clamp(240.0, r.modalCardMaxH)
        : r.modalCardMaxH;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (keyboardOpen) {
                  FocusManager.instance.primaryFocus?.unfocus();
                } else {
                  _close();
                }
              },
              child: const ColoredBox(color: Color(0x990F2748)),
            ),
          ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: kb),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (canGoBack)
                          IconButton(
                            onPressed: _back,
                            tooltip: 'Rudi nyuma',
                            icon: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                            ),
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(child: Center(child: _dots())),
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
                    const SizedBox(height: 6),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxCardH, maxWidth: 420),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey('pay-step-$_page'),
                              child: _CarouselCard(child: _cardBody(_page)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!keyboardOpen) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (canGoBack)
                            TextButton(
                              onPressed: _back,
                              child: Text(
                                'Rudi',
                                style: AppTheme.body(14, color: Colors.white.withValues(alpha: 0.9), weight: FontWeight.w700),
                              ),
                            )
                          else
                            const SizedBox(width: 56),
                          Expanded(
                            child: Text(
                              _pageLabel,
                              textAlign: TextAlign.center,
                              style: AppTheme.body(13, color: Colors.white.withValues(alpha: 0.85), weight: FontWeight.w600),
                            ),
                          ),
                          _NextFab(
                            onTap: _next,
                            isLast: _page >= 3,
                            success: _paymentSuccess,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final on = i == _page;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: on ? AppColors.green : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _cardBody(int index) {
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
      heroHeight: 100,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _formScrollCtrl,
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  Text('Taarifa Zako', style: AppTheme.heading(18)),
                  const SizedBox(height: 10),
                  _audioStrip(),
                  const SizedBox(height: 12),
                  _field(
                    _nameCtrl,
                    'Weka majina yako kamili',
                    Icons.badge_rounded,
                    focusNode: _nameFocus,
                  ),
                  const SizedBox(height: 8),
                  _field(
                    _phoneCtrl,
                    'Nambari ya simu',
                    Icons.phone_rounded,
                    type: TextInputType.phone,
                    focusNode: _phoneFocus,
                  ),
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
                      color: on ? AppColors.green.withValues(alpha: 0.08) : AppColors.section,
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
              if (_paymentBusy) return;
              final pkgs = context.read<AppState>().packages;
              final pkg = pkgs.firstWhere((p) => p.id == _selectedPkgId, orElse: () => pkgs.first);
              context.read<AppState>().submitPaymentPending(pkg);
              setState(() {
                _waitingHint = PaymentConfig.paymentPromptFor(_phoneCtrl.text);
              });
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
                        _waitingHint,
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
        color: lite ? Colors.white.withValues(alpha: 0.16) : AppColors.section,
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

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: c,
      focusNode: focusNode,
      keyboardType: type,
      textInputAction: type == TextInputType.phone ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) {
        if (type != TextInputType.phone) {
          _phoneFocus.requestFocus();
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      },
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: AppTheme.body(14, color: AppColors.textPrimary, weight: FontWeight.w600),
      cursorColor: AppColors.navy,
      onChanged: (_) {
        if (_formError != null) setState(() => _formError = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.body(12.5, color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.navyMid, size: 18),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6E8F6), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6E8F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.14), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2748).withValues(alpha: 0.32),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(color: Colors.white, elevation: 0, child: child),
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
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: child,
            ),
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
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 2),
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
          gradient: const LinearGradient(
            colors: [AppColors.green, AppColors.greenDark],
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
                      color: AppColors.green.withValues(alpha: 0.45),
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

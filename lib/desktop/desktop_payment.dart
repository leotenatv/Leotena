import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/payment_config.dart';
import '../data/sonicpesa_payment_service.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'desktop_shimmer.dart';

/// One-month price shown on desktop. Charged only when the server has a
/// matching active plan, so a different package is never billed by mistake.
const int kDesktopMonthPrice = 5000;
const int kDesktopMonthDays = 30;

/// Desktop checkout: phone number, then the same SonicPesa USSD push the
/// phone app uses. No package steps and no voice prompts.
class DesktopPayment {
  DesktopPayment._();

  static Future<bool> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'malipo',
      barrierColor: const Color(0xFF0F2748).withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => const _DesktopPaymentCard(),
      transitionBuilder: (_, anim, __, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curve),
            child: child,
          ),
        );
      },
    ).then((paid) => paid ?? false);
  }
}

SubscriptionPackage? desktopMonthPlan(List<SubscriptionPackage> packages) {
  int amount(SubscriptionPackage plan) {
    final cleaned = plan.price.replaceAll(',', '').replaceAll(' ', '').trim();
    final whole = cleaned.split('.').first;
    return int.tryParse(whole) ?? -1;
  }

  final priced =
      packages.where((plan) => amount(plan) == kDesktopMonthPrice).toList();
  for (final plan in priced) {
    if (plan.days >= 28 && plan.days <= 31) return plan;
  }
  if (priced.isNotEmpty) return priced.first;
  return null;
}

String _payerName(AppState state) {
  final name = state.userName.trim();
  if (PaymentConfig.isValidFullName(name)) return name;
  return 'Mtumiaji Leotena';
}

class _CancelPaymentAsk extends StatelessWidget {
  const _CancelPaymentAsk();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.shadow(blur: 40, y: 18, opacity: 0.3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Je unataka kukatisha malipo? Chaneli hazitafunguliwa mda huu',
                textAlign: TextAlign.center,
                style: AppTheme.heading(18),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _AskButton(
                      label: 'Hapana',
                      filled: false,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AskButton(
                      label: 'Ndiyo',
                      filled: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AskButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _AskButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? AppColors.navy : AppColors.section,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: AppTheme.body(
              15,
              color: filled ? Colors.white : AppColors.navy,
              weight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPaymentCard extends StatefulWidget {
  const _DesktopPaymentCard();

  @override
  State<_DesktopPaymentCard> createState() => _DesktopPaymentCardState();
}

class _DesktopPaymentCardState extends State<_DesktopPaymentCard> {
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _paying = false;
  bool _done = false;
  String? _error;
  String? _status;

  @override
  void initState() {
    super.initState();
    final phone = context.read<AppState>().phoneNumber.trim();
    if (phone.isNotEmpty) _phoneCtrl.text = phone;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final cancel = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'kukatisha malipo',
      barrierColor: const Color(0xFF0F2748).withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const _CancelPaymentAsk(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
    if (cancel == true && mounted) Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    if (_paying || _done) return;
    final phone = _phoneCtrl.text.trim();
    if (!PaymentConfig.isValidTzLocalPhone(phone)) {
      setState(
          () => _error = 'Namba ya simu si sahihi. Tumia 07…, 06… au 255…');
      return;
    }

    final state = context.read<AppState>();
    var plan = desktopMonthPlan(state.packages);
    if (plan == null) {
      setState(() {
        _paying = true;
        _error = null;
        _status = 'Inaangalia kifurushi…';
      });
      try {
        await state.refreshContent();
      } catch (_) {}
      if (!mounted) return;
      plan = desktopMonthPlan(context.read<AppState>().packages);
    }
    if (plan == null) {
      setState(() {
        _paying = false;
        _status = null;
        _error =
            'Kifurushi cha TSh 5,000 kwa mwezi mmoja hakipatikani kwa sasa.';
      });
      return;
    }

    setState(() {
      _paying = true;
      _error = null;
      _status = PaymentConfig.paymentPromptFor(phone);
    });

    final name = _payerName(context.read<AppState>());
    try {
      final init =
          await state.initiateSonicPayment(pkg: plan, name: name, phone: phone);
      if (!mounted) return;
      if (init.completed &&
          (init.local || context.read<AppState>().subscribed)) {
        setState(() {
          _paying = false;
          _done = true;
          _status = null;
          _error = null;
        });
        return;
      }

      final wait = await state.awaitSonicPayment(
        orderId: init.orderId,
        alive: () => mounted,
        userName: name,
        phone: phone,
        planId: plan.id,
        onProgress: (message) {
          if (mounted) setState(() => _status = message);
        },
      );
      if (!mounted || wait.cancelled) return;
      if (wait.status?.completed == true && context.read<AppState>().subscribed) {
        setState(() {
          _paying = false;
          _done = true;
          _status = null;
          _error = null;
        });
        return;
      }
      setState(() {
        _paying = false;
        _status = null;
        _error = wait.status?.failed == true
            ? (wait.status?.message ?? 'Malipo hayajakamilika. Jaribu tena.')
            : 'Muda wa kusubiri malipo umeisha. Hakikisha umethibitisha PIN kwenye simu, kisha jaribu tena.';
      });
    } on SonicpesaPaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _status = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _status = null;
        _error = 'Hitilafu ya mtandao. Jaribu tena.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_paying,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 440,
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppColors.shadow(blur: 50, y: 24, opacity: 0.35),
              ),
              child: _done ? _success() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final phone = _phoneCtrl.text;
    final valid = PaymentConfig.isValidTzLocalPhone(phone);
    final network = valid
        ? PaymentConfig.networkLabel(PaymentConfig.detectNetwork(phone))
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            IconButton(
              tooltip: 'Funga',
              onPressed: _close,
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.green, AppColors.greenDark]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.greenGlow(),
            ),
            child: const Icon(Icons.lock_open_rounded,
                color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 18),
        Text('Fungua vituo vyote',
            style: AppTheme.heading(24), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Lipa shilingi 5,000 za Tanzania kwa mwezi mmoja. Baada ya malipo, vituo vyote vitafunguliwa.',
          textAlign: TextAlign.center,
          style: AppTheme.body(13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.section,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mwezi 1',
                        style: AppTheme.body(13,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Siku $kDesktopMonthDays',
                        style: AppTheme.body(12, color: AppColors.textHint)),
                  ],
                ),
              ),
              Text('TSh 5,000', style: AppTheme.heading(22)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          enabled: !_paying,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]'))
          ],
          style: AppTheme.body(16,
              color: AppColors.textPrimary, weight: FontWeight.w700),
          cursorColor: AppColors.navy,
          onChanged: (_) {
            if (_error != null || _status != null) {
              setState(() {
                _error = null;
              });
            } else {
              setState(() {});
            }
          },
          onSubmitted: (_) {
            if (valid && !_paying) _submit();
          },
          decoration: InputDecoration(
            labelText: 'Nambari ya simu',
            hintText: '07… au 06…',
            labelStyle: AppTheme.body(13, color: AppColors.textHint),
            hintStyle: AppTheme.body(14, color: AppColors.textHint),
            prefixIcon: const Icon(Icons.phone_rounded,
                color: AppColors.navyMid, size: 20),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFD6E8F6), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.green, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFFD6E8F6), width: 1.4),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
        if (network != null) ...[
          const SizedBox(height: 8),
          Text(network,
              style: AppTheme.body(12.5,
                  color: AppColors.greenDark, weight: FontWeight.w700)),
        ],
        if (_status != null) ...[
          const SizedBox(height: 10),
          Text(_status!,
              style: AppTheme.body(13,
                  color: AppColors.navy, weight: FontWeight.w700)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: AppTheme.body(13,
                  color: const Color(0xFFC4384B), weight: FontWeight.w700)),
        ],
        const SizedBox(height: 18),
        if (_paying)
          const DesktopShimmer(
            child: ShimmerBone(height: 54, radius: 18),
          )
        else
          PrimaryButton(
            label: 'Lipa TSh 5,000',
            icon: Icons.payments_rounded,
            onTap: _submit,
          ),
        const SizedBox(height: 12),
        Text(
          'Thibitisha PIN kwenye simu yako. Malipo salama.',
          textAlign: TextAlign.center,
          style: AppTheme.body(12, color: AppColors.textHint),
        ),
      ],
    );
  }

  Widget _success() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.green, AppColors.greenDark]),
            shape: BoxShape.circle,
            boxShadow: AppColors.greenGlow(),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 18),
        Text('Malipo yamefanikiwa',
            style: AppTheme.heading(22), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Vituo vyote vimefunguliwa kwa mwezi mmoja.',
          textAlign: TextAlign.center,
          style: AppTheme.body(13.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Endelea kutazama',
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

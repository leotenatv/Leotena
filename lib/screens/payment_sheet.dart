import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../utils/payment_voices.dart';
import '../data/payment_config.dart';
import '../data/sonicpesa_payment_service.dart';
import '../widgets/common.dart';

/// Centered animated success modal (no native dialogs / alerts anywhere).
class SuccessModal extends StatefulWidget {
  final String title;
  final String message;
  final String buttonLabel;
  const SuccessModal({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Endelea Kutazama',
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Endelea Kutazama',
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      barrierColor: const Color(0xFF0F2748).withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => SuccessModal(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
      ),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<SuccessModal> createState() => _SuccessModalState();
}

class _SuccessModalState extends State<SuccessModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await PaymentVoices.playAsset(PaymentVoices.successAsset);
    });
  }

  @override
  void dispose() {
    PaymentVoices.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppColors.shadow(blur: 60, y: 30, opacity: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
                    shape: BoxShape.circle,
                    boxShadow: AppColors.greenGlow(),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 18),
                Text(widget.title, style: AppTheme.heading(22), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(widget.message,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(13, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: widget.buttonLabel,
                  onTap: () async {
                    await PaymentVoices.stop();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet payment screen: pick a kifurushi (package) and activate.
class PaymentSheet extends StatefulWidget {
  final List<SubscriptionPackage> packages;
  const PaymentSheet({super.key, required this.packages});

  static Future<void> show(BuildContext context, List<SubscriptionPackage> packages) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF0F2748).withValues(alpha: 0.5),
      builder: (_) => PaymentSheet(packages: packages),
    );
  }

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  String _selected = 'mwezi';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _error;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.userName != 'Mtumiaji') _nameCtrl.text = state.userName;
      if (state.phoneNumber.isNotEmpty) _phoneCtrl.text = state.phoneNumber;
      final pkgs = widget.packages;
      if (pkgs.isNotEmpty) {
        final popular = pkgs.where((p) => p.popular);
        _selected = popular.isNotEmpty ? popular.first.id : pkgs.first.id;
      }
      await PaymentVoices.playAsset(PaymentVoices.packageAsset);
    });
  }

  @override
  void dispose() {
    PaymentVoices.stop();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(SubscriptionPackage selectedPkg) async {
    if (_paying) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Tafadhali jaza jina na nambari ya simu');
      PaymentVoices.playAsset(PaymentVoices.detailsAsset);
      return;
    }
    if (!PaymentConfig.isValidFullName(name)) {
      setState(() => _error = 'Tafadhali jaza jina kamili (angalau majina mawili)');
      PaymentVoices.playAsset(PaymentVoices.detailsAsset);
      return;
    }
    if (!PaymentConfig.isValidTzLocalPhone(phone)) {
      setState(() => _error = 'Namba ya simu si sahihi. Tumia 07…, 06… au 255…');
      PaymentVoices.playAsset(PaymentVoices.detailsAsset);
      return;
    }

    setState(() {
      _paying = true;
      _error = PaymentConfig.paymentPromptFor(phone);
    });
    PaymentVoices.stop();

    final state = context.read<AppState>();
    try {
      final init = await state.initiateSonicPayment(pkg: selectedPkg, name: name, phone: phone);
      if (!mounted) return;

      if (init.completed && init.local) {
        Navigator.of(context).pop();
        SuccessModal.show(
          context,
          title: 'Malipo Yamefanikiwa!',
          message: 'Karibu $name! Kifurushi cha ${selectedPkg.name} kimewezeshwa.',
        );
        return;
      }

      setState(() => _error = init.message);

      const maxAttempts = 60;
      for (var i = 0; i < maxAttempts; i++) {
        // Slower polling avoids Sonic "Too Many Attempts" which blocked auto-upgrade.
        final delay = i < 10 ? const Duration(seconds: 2) : const Duration(seconds: 4);
        await Future.delayed(delay);
        if (!mounted) return;

        try {
          final status = await state.pollSonicPayment(
            orderId: init.orderId,
            userName: name,
            phone: phone,
          );
          if (status.completed) {
            if (!mounted) return;
            Navigator.of(context).pop();
            SuccessModal.show(
              context,
              title: 'Malipo Yamefanikiwa!',
              message: 'Karibu $name! Kifurushi cha ${selectedPkg.name} (TSh ${selectedPkg.price}) kimewezeshwa.',
            );
            return;
          }
          if (status.failed) {
            if (!mounted) return;
            setState(() {
              _paying = false;
              _error = status.message ?? 'Malipo hayajakamilika. Jaribu tena.';
            });
            return;
          }
        } on SonicpesaPaymentException catch (e) {
          final code = e.statusCode;
          if (code == 429 || code == 502 || code == 503 || code == 504) {
            if (mounted) {
              setState(() => _error = 'Seva inaendelea kuchakata malipo…');
            }
            await Future.delayed(const Duration(seconds: 5));
          }
          // Soft: keep polling through other transient issues.
        }
        if (!mounted) return;
        setState(() {
          _error = i < 8
              ? PaymentConfig.paymentPromptFor(phone)
              : 'Bado tunasubiri uthibitisho wa ${PaymentConfig.networkLabel(PaymentConfig.detectNetwork(phone))}…';
        });
      }
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Muda wa kusubiri malipo umeisha. Hakikisha umethibitisha PIN kwenye simu, kisha jaribu tena.';
      });
    } on SonicpesaPaymentException catch (e) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _paying = false;
        _error = 'Hitilafu ya mtandao. Jaribu tena.';
      });
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTheme.body(14.5, color: AppColors.textPrimary, weight: FontWeight.w600),
      cursorColor: AppColors.navy,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.body(13, color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.navyMid, size: 20),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6E8F6), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.green, width: 1.8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD6E8F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedPkg = widget.packages.firstWhere((p) => p.id == _selected, orElse: () => widget.packages[1]);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: const Color(0xFFD6E7F5), borderRadius: BorderRadius.circular(3)),
            ),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.greenGlow(),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Chagua Kifurushi', style: AppTheme.heading(23)),
            const SizedBox(height: 6),
            Text(
              'Jaza taarifa zako kisha chagua kifurushi.',
              textAlign: TextAlign.center,
              style: AppTheme.body(13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _field(controller: _nameCtrl, label: 'Jina kamili', icon: Icons.person_rounded),
            const SizedBox(height: 10),
            _field(
              controller: _phoneCtrl,
              label: 'Nambari ya simu',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTheme.body(12.5, color: Colors.redAccent, weight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            ...widget.packages.map((pk) {
              final on = pk.id == _selected;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = pk.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: on ? AppColors.green.withValues(alpha: 0.06) : AppColors.section,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: on ? AppColors.green : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 23,
                          height: 23,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on ? AppColors.green : Colors.transparent,
                            border: Border.all(color: on ? AppColors.green : const Color(0xFFC9DEF0), width: 2),
                          ),
                          child: on ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(pk.name, style: AppTheme.body(14.5, color: AppColors.textPrimary, weight: FontWeight.w800)),
                                if (pk.popular) ...[const SizedBox(width: 7), const GreenBadge('MAARUFU')],
                              ]),
                              const SizedBox(height: 2),
                              Text(pk.note, style: AppTheme.body(11, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                        Text('TSh ${pk.price}', style: AppTheme.heading(16)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            PrimaryButton(
              label: _paying
                  ? 'Inasubiri malipo…'
                  : 'Lipa & Wezesha — TSh ${selectedPkg.price}',
              onTap: () => _submit(selectedPkg),
            ),
            const SizedBox(height: 12),
            Text('Ghairi wakati wowote • Malipo salama 🔒', style: AppTheme.body(11.5, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

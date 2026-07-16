import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Centered animated success modal (no native dialogs / alerts anywhere).
class SuccessModal extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  const SuccessModal({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Endelea Kutazama',
  });

  static Future<void> show(BuildContext context,
      {required String title, required String message, String buttonLabel = 'Endelea Kutazama'}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'success',
      barrierColor: const Color(0xFF0F2748).withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => SuccessModal(title: title, message: message, buttonLabel: buttonLabel),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
    );
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
                Text(title, style: AppTheme.heading(22), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: AppTheme.body(13, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                PrimaryButton(label: buttonLabel, onTap: () => Navigator.of(context).pop()),
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
      barrierColor: const Color(0xFF0F2748).withOpacity(0.5),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.userName != 'Mtumiaji') _nameCtrl.text = state.userName;
      if (state.phoneNumber.isNotEmpty) _phoneCtrl.text = state.phoneNumber;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit(SubscriptionPackage selectedPkg) {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Tafadhali jaza jina na nambari ya simu');
      return;
    }
    if (phone.length < 9) {
      setState(() => _error = 'Nambari ya simu si sahihi');
      return;
    }
    context.read<AppState>().activatePackage(selectedPkg, name: name, phone: phone);
    Navigator.of(context).pop();
    SuccessModal.show(
      context,
      title: 'Malipo Yamefanikiwa!',
      message: 'Karibu $name! Kifurushi cha ${selectedPkg.name} (TSh ${selectedPkg.price}) kimewezeshwa.',
    );
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
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTheme.body(13, color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.navyMid, size: 20),
        filled: true,
        fillColor: AppColors.section,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                      color: on ? AppColors.green.withOpacity(0.06) : AppColors.section,
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
              label: 'Lipa & Wezesha — TSh ${selectedPkg.price}',
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

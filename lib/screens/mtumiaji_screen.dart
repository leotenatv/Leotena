import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common.dart';
import '../widgets/premium_lock_modal.dart';

/// User profile tab — name, phone, device id, msaada (WhatsApp), subscription time.
class MtumiajiScreen extends StatefulWidget {
  const MtumiajiScreen({super.key});

  @override
  State<MtumiajiScreen> createState() => _MtumiajiScreenState();
}

class _MtumiajiScreenState extends State<MtumiajiScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    // Pulls in any premium grant/revoke the admin made since this app booted.
    context.read<AppState>().refreshDeviceStatus();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _openPremium() => PremiumLockModal.show(context);

  void _copyDeviceId(String id) {
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nambari ya kifaa imenakiliwa', style: AppTheme.body(13, color: Colors.white)),
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp(AppState state) async {
    final phone = state.supportWhatsApp.replaceAll(RegExp(r'\D'), '');
    final text = Uri.encodeComponent(
      'Habari Leotena, ninaomba msaada.\nJina: ${state.userName}\nDevice ID: ${state.deviceId}',
    );
    final uri = Uri.parse('https://wa.me/$phone?text=$text');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imeshindikana kufungua WhatsApp', style: AppTheme.body(13, color: Colors.white)),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgSoft, AppColors.bg],
          stops: [0, 0.38],
        ),
      ),
      child: Consumer<AppState>(
        builder: (_, state, __) {
          final countdown = _countdownParts(state.remaining);

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: r.maxContentWidth),
              child: ListView(
                padding: EdgeInsets.only(top: r.topContent, bottom: r.bottomNavClearance),
                children: [
                  _profileHeader(state, r),
                  SizedBox(height: r.sectionGap + 4),
                  _infoCard(state, r),
                  SizedBox(height: r.sp(14)),
                  _subscriptionCard(state, countdown, r),
                  SizedBox(height: r.sp(14)),
                  _msaadaCard(state, r),
                  if (!state.subscribed) ...[
                    SizedBox(height: r.sectionGap),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
                      child: PrimaryButton(label: 'Fanya Malipo', onTap: _openPremium),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _profileHeader(AppState state, R r) {
    final avatar = r.sp(88);
    return Column(
      children: [
        Container(
          width: avatar,
          height: avatar,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navyMid, AppColors.navy]),
            borderRadius: BorderRadius.circular(r.sp(28)),
            boxShadow: AppColors.shadow(blur: 40, y: 20, opacity: 0.5),
          ),
          child: Text(state.userInitial, style: AppTheme.heading(r.sp(32), color: Colors.white)),
        ),
        SizedBox(height: r.sp(16)),
        Text(state.userName, style: AppTheme.heading(r.sp(22))),
        const SizedBox(height: 4),
        Text(
          state.subscribed ? 'Uanachama unatumika' : 'Akaunti ya bure',
          style: AppTheme.body(r.sp(13), color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _infoCard(AppState state, R r) {
    final phone = state.phoneNumber.trim().isEmpty ? 'Haijawekwa' : state.phoneNumber;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
      child: FloatingCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            _infoRow(Icons.person_rounded, 'Jina', state.userName),
            const Divider(height: 22, color: AppColors.section),
            _infoRow(Icons.phone_rounded, 'Simu', phone),
            const Divider(height: 22, color: AppColors.section),
            _infoRow(
              Icons.smartphone_rounded,
              'Device ID',
              state.deviceId,
              trailing: GestureDetector(
                onTap: () => _copyDeviceId(state.deviceId),
                child: const Icon(Icons.copy_rounded, color: AppColors.green, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Widget? trailing}) {
    final r = R.of(context);
    return Row(
      children: [
        Container(
          width: r.sp(40),
          height: r.sp(40),
          decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: r.sp(20), color: AppColors.navyMid),
        ),
        SizedBox(width: r.sp(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTheme.body(r.sp(11.5), color: AppColors.textHint, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(value, style: AppTheme.body(r.sp(15), color: AppColors.textPrimary, weight: FontWeight.w700)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _msaadaCard(AppState state, R r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
      child: GestureDetector(
        onTap: () => _openWhatsApp(state),
        child: FloatingCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F7EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.chat_rounded, color: AppColors.green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Uliza swali kwa mtoa huduma', style: AppTheme.body(15, color: AppColors.textPrimary, weight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.greenGlow(),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subscriptionCard(AppState state, List<_CountdownPart> countdown, R r) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
      child: FloatingCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MUDA ULIYOSALIA',
                    style: AppTheme.body(12, color: AppColors.textHint, weight: FontWeight.w800)
                        .copyWith(letterSpacing: 0.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: state.subscribed ? AppColors.green : AppColors.textHint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    state.subscribed ? 'PREMIUM' : 'BURE',
                    style: AppTheme.body(10.5, color: Colors.white, weight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            if (state.subscribed) ...[
              const SizedBox(height: 13),
              Text('Muda uliobaki wa uanachama', style: AppTheme.body(12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                children: countdown
                    .map((c) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(13)),
                            child: Column(
                              children: [
                                Text(c.value, style: AppTheme.heading(18)),
                                const SizedBox(height: 3),
                                Text(
                                  c.label,
                                  style: AppTheme.body(9, color: AppColors.textHint, weight: FontWeight.w800)
                                      .copyWith(letterSpacing: 0.3),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ] else ...[
              const SizedBox(height: 13),
              Text(
                'Hakuna uanachama hai. Fanya malipo ili kuwezesha Premium.',
                style: AppTheme.body(13, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_CountdownPart> _countdownParts(Duration d) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return [
      _CountdownPart('${d.inDays}', 'SIKU'),
      _CountdownPart(p2(d.inHours % 24), 'SAA'),
      _CountdownPart(p2(d.inMinutes % 60), 'DAKIKA'),
      _CountdownPart(p2(d.inSeconds % 60), 'SEKUNDE'),
    ];
  }
}

class _CountdownPart {
  final String value;
  final String label;
  const _CountdownPart(this.value, this.label);
}

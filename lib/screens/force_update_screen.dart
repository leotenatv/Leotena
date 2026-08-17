import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Non-dismissible gate. User must tap Update sasa and install from Play Store.
class ForceUpdateScreen extends StatefulWidget {
  const ForceUpdateScreen({super.key, required this.onRecheck});

  final Future<void> Function() onRecheck;

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.onRecheck();
    }
  }

  Future<void> _openStore() async {
    final url = context.read<AppState>().appSettings.storeUrl;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.appSettings;
    final current = state.currentAppVersion.isEmpty
        ? '—'
        : '${state.currentAppVersion}${state.currentAppBuild > 0 ? '+${state.currentAppBuild}' : ''}';
    final requiredLabel = [
      if (s.minAppVersion.isNotEmpty) s.minAppVersion,
      if (s.minCodeVersion > 0) 'code ${s.minCodeVersion}',
    ].join(' · ');

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.green, AppColors.greenDark]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppColors.greenGlow(),
                  ),
                  child: const Icon(Icons.system_update_alt_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                Text('Toleo jipya lipo', style: AppTheme.heading(26), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  s.displayForceUpdateMessage,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(14.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.section,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _metaRow('Toleo lako', current),
                      if (requiredLabel.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _metaRow('Inahitajika', requiredLabel),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  label: 'Update sasa',
                  icon: Icons.shop_rounded,
                  onTap: _openStore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTheme.body(12.5, color: AppColors.textHint)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTheme.body(13, color: AppColors.textPrimary, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

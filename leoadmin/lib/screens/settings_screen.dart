import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _wa;
  late final TextEditingController _maintenanceMsg;
  late final TextEditingController _codeVersion;
  late final TextEditingController _appVersion;
  late final TextEditingController _updateMsg;
  late bool _maintenanceOn;
  late bool _forceUpdateOn;
  bool _saving = false;
  bool _hydrated = false;

  void _hydrate(AdminSettings s) {
    _wa.text = s.supportWhatsApp;
    _maintenanceMsg.text = s.maintenanceMessage;
    _codeVersion.text = s.minCodeVersion > 0 ? '${s.minCodeVersion}' : '';
    _appVersion.text = s.minAppVersion;
    _updateMsg.text = s.forceUpdateMessage;
    _maintenanceOn = s.maintenanceMode;
    _forceUpdateOn = s.forceUpdateEnabled;
  }

  @override
  void initState() {
    super.initState();
    final s = context.read<AdminState>().settings;
    _wa = TextEditingController(text: s.supportWhatsApp);
    _maintenanceMsg = TextEditingController(text: s.maintenanceMessage);
    _codeVersion = TextEditingController(text: s.minCodeVersion > 0 ? '${s.minCodeVersion}' : '');
    _appVersion = TextEditingController(text: s.minAppVersion);
    _updateMsg = TextEditingController(text: s.forceUpdateMessage);
    _maintenanceOn = s.maintenanceMode;
    _forceUpdateOn = s.forceUpdateEnabled;
  }

  Future<void> _save() async {
    final code = int.tryParse(_codeVersion.text.trim()) ?? 0;
    final appVer = _appVersion.text.trim();
    if (_forceUpdateOn && code <= 0 && appVer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weka code version au app version kabla ya kuwasha lazima ku update.',
            style: AdminTheme.body(13, color: Colors.white),
          ),
          backgroundColor: AdminColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<AdminState>().updateSettings(
            AdminSettings(
              supportWhatsApp: _wa.text,
              maintenanceMode: _maintenanceOn,
              maintenanceMessage: _maintenanceMsg.text.trim(),
              forceUpdateEnabled: _forceUpdateOn,
              minCodeVersion: code,
              minAppVersion: appVer,
              forceUpdateMessage: _updateMsg.text.trim(),
              playStoreUrl: context.read<AdminState>().settings.playStoreUrl,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imehifadhiwa', style: AdminTheme.body(13, color: Colors.white)),
          backgroundColor: AdminColors.surfaceLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imeshindwa: ${e.message}', style: AdminTheme.body(13, color: Colors.white)),
          backgroundColor: AdminColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _wa.dispose();
    _maintenanceMsg.dispose();
    _codeVersion.dispose();
    _appVersion.dispose();
    _updateMsg.dispose();
    super.dispose();
  }

  InputDecoration _deco(String hint) => InputDecoration(hintText: hint);

  Widget _card({
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AdminTheme.body(12, color: AdminColors.textHint)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AdminTheme.body(14, color: AdminColors.textPrimary, weight: FontWeight.w700)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: color.withValues(alpha: 0.45),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? color : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminState>();
    if (admin.settingsReady && !_hydrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hydrated) return;
        _hydrate(admin.settings);
        setState(() => _hydrated = true);
      });
    }
    if (!admin.settingsReady) {
      return const AdminPage(
        toolbar: [],
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AdminPage(
      toolbar: [
        Text('Mipangilio', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
      ],
      child: ListView(
        children: [
          _card(
            accent: AdminColors.green,
            icon: Icons.chat_rounded,
            title: 'WhatsApp (Msaada)',
            subtitle: 'Namba watumiaji watatumia kuwasiliana na msaada.',
            child: TextField(
              controller: _wa,
              keyboardType: TextInputType.phone,
              style: AdminTheme.body(14, color: AdminColors.textPrimary),
              decoration: _deco('255712345678'),
            ),
          ),
          const SizedBox(height: 14),
          _card(
            accent: AdminColors.warning,
            icon: Icons.build_circle_rounded,
            title: 'Hali ya matengenezo',
            subtitle: 'Watumiaji wataona ujumbe huu na hawawezi kutumia app hadi uzime.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _switchRow(
                  label: _maintenanceOn ? 'Imewashwa' : 'Imezimwa',
                  value: _maintenanceOn,
                  color: AdminColors.warning,
                  onChanged: (v) => setState(() => _maintenanceOn = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _maintenanceMsg,
                  maxLines: 3,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: _deco('Programu iko katika matengenezo. Tafadhali rudi baadaye.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            accent: const Color(0xFFFB7185),
            icon: Icons.system_update_alt_rounded,
            title: 'Lazima ku update',
            subtitle:
                'Toleo la Play sasa ni 11.6.0 (code 55). Weka code KUBWA kuliko hiyo (mfano 56) au app version mpya (mfano 11.6.1). Toleo la sasa au jipya litaendelea; la zamani litalazimishwa kusasisha.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _switchRow(
                  label: _forceUpdateOn ? 'Imewashwa' : 'Imezimwa',
                  value: _forceUpdateOn,
                  color: const Color(0xFFFB7185),
                  onChanged: (v) => setState(() => _forceUpdateOn = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _codeVersion,
                  keyboardType: TextInputType.number,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: _deco('Code version ya chini inayoruhusiwa (mfano 56, si 55)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _appVersion,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: _deco('App version (mfano 11.6.0)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _updateMsg,
                  maxLines: 3,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: _deco('Toleo jipya la Leotena lipo. Tafadhali sasisha ili uendelee kutumia programu.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_saving || !_hydrated) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('Hifadhi', style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

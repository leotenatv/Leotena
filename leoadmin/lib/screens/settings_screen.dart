import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wa = TextEditingController(text: context.read<AdminState>().supportWhatsApp);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AdminState>().updateSupportWhatsApp(_wa.text);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      toolbar: [
        Text('Mipangilio', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
      ],
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AdminColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WhatsApp (Msaada)', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _wa,
                  keyboardType: TextInputType.phone,
                  style: AdminTheme.body(14, color: AdminColors.textPrimary),
                  decoration: const InputDecoration(hintText: '255712345678'),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _saving ? null : _save,
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
          ),
        ],
      ),
    );
  }
}

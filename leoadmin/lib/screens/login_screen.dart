import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await context.read<AdminState>().login(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (!ok) _error = context.read<AdminState>().authError ?? 'Barua pepe au nenosiri si sahihi';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AdminColors.bg, Color(0xFF0A1E3D), AdminColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AdminColors.greenDark, AdminColors.green]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: AdminColors.green.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 24),
                  Text('LeoAdmin', style: AdminTheme.heading(32)),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AdminColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Barua pepe', style: AdminTheme.body(12, color: AdminColors.textHint)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: AdminTheme.body(14, color: AdminColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'admin@leotena.com'),
                        ),
                        const SizedBox(height: 18),
                        Text('Nenosiri', style: AdminTheme.body(12, color: AdminColors.textHint)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          style: AdminTheme.body(14, color: AdminColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AdminColors.textHint, size: 20),
                            ),
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: AdminTheme.body(12, color: AdminColors.danger)),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AdminColors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text('Ingia', style: AdminTheme.body(15, color: Colors.white, weight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

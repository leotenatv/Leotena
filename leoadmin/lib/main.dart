import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'state/admin_state.dart';
import 'theme/admin_theme.dart';

void main() {
  runApp(const LeoAdminApp());
}

class LeoAdminApp extends StatelessWidget {
  const LeoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminState(),
      child: MaterialApp(
        title: 'LeoAdmin',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.dark(),
        home: const _BootGate(),
      ),
    );
  }
}

/// Restores a persisted admin session (if any) before deciding between the
/// login screen and the dashboard, so a valid JWT survives app restarts.
class _BootGate extends StatefulWidget {
  const _BootGate();

  @override
  State<_BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<_BootGate> {
  @override
  void initState() {
    super.initState();
    // Deferred to a microtask: tryRestoreSession() calls notifyListeners()
    // before its first await, and initState() runs synchronously during the
    // very first build — notifying listeners mid-build throws.
    Future.microtask(() {
      if (!mounted) return;
      context.read<AdminState>().tryRestoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    if (state.booting) {
      return const Scaffold(
        backgroundColor: AdminColors.bg,
        body: Center(child: CircularProgressIndicator(color: AdminColors.green)),
      );
    }
    return state.loggedIn ? const AdminShell() : const LoginScreen();
  }
}

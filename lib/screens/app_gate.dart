import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'force_update_screen.dart';
import 'maintenance_screen.dart';
import 'root_shell.dart';

bool _isPhoneViewer() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Chooses RootShell, maintenance, or forced update from live admin settings.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_isPhoneViewer() && state.forceUpdateRequired) {
      return ForceUpdateScreen(onRecheck: state.refreshContent);
    }
    if (_isPhoneViewer() && state.maintenanceMode) {
      return MaintenanceScreen(onRetry: state.refreshContent);
    }
    return const RootShell();
  }
}

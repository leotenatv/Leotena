import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../desktop/desktop_shell.dart';
import '../desktop/tv_layout.dart';
import '../state/app_state.dart';
import 'force_update_screen.dart';
import 'maintenance_screen.dart';
import 'root_shell.dart';

bool _isPhoneViewer() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Chooses the phone shell, the Windows desktop shell, maintenance, or a
/// forced update from live admin settings.
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
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows || TvLayout.active)) {
      return const DesktopShell();
    }
    return const RootShell();
  }
}

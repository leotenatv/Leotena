import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Full-screen block while admin has maintenance mode on.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key, required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final message = state.appSettings.displayMaintenanceMessage;

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
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.build_circle_rounded, color: Colors.white, size: 44),
                ),
                const SizedBox(height: 24),
                Text('Matengenezo', style: AppTheme.heading(26), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(14.5, color: AppColors.textSecondary),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  label: 'Jaribu tena',
                  icon: Icons.refresh_rounded,
                  onTap: () => onRetry(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

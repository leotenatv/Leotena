import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/admin_repository.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    const weekly = AdminRepository.weeklyUsers;
    final max = weekly.reduce((a, b) => a > b ? a : b);

    return AdminPage(
      toolbar: [
        Text('Takwimu', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Watumiaji (siku 7)', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(weekly.length, (i) {
                      final h = (weekly[i] / max) * 120;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            height: h.clamp(8, 120),
                            decoration: BoxDecoration(
                              color: AdminColors.green.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...AdminRepository.topContent.map(
            (t) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: t.gradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(t.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: AdminTheme.body(14, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                        Text(t.subtitle, style: AdminTheme.body(12, color: AdminColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(t.views, style: AdminTheme.body(13, color: AdminColors.green, weight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vituo ${state.channels.length} · Bei ${state.pricingPlans.length}',
            style: AdminTheme.body(12, color: AdminColors.textHint),
          ),
        ],
      ),
    );
  }
}

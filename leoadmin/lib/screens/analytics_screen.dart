import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final categories = <String, int>{};
    for (final c in state.channels) {
      categories[c.category] = (categories[c.category] ?? 0) + 1;
    }
    final catEntries = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxCat = catEntries.isEmpty ? 1 : catEntries.first.value;

    return AdminPage(
      toolbar: [
        Text('Takwimu', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
      ],
      child: ListView(
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatTile(label: 'Watumiaji', value: '${state.users.length}'),
                  _StatTile(label: 'Premium', value: '${state.premiumUserCount}'),
                  _StatTile(label: 'Malipo', value: '${state.successfulPaymentsCount}'),
                  _StatTile(label: 'Mapato', value: state.revenueLabel),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
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
                Text('Vituo kwa kategoria', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                const SizedBox(height: 18),
                if (catEntries.isEmpty)
                  Text('Hakuna vituo bado.', style: AdminTheme.body(13, color: AdminColors.textHint))
                else
                  SizedBox(
                    height: 140,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: catEntries.map((e) {
                        final h = (e.value / maxCat) * 120;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${e.value}', style: AdminTheme.body(10, color: AdminColors.textHint)),
                                const SizedBox(height: 4),
                                Container(
                                  height: h.clamp(8, 120),
                                  decoration: BoxDecoration(
                                    color: AdminColors.green.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  kCategoryLabels[e.key] ?? e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AdminTheme.body(9, color: AdminColors.textHint),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Vituo kwa watazamaji', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (state.topChannelsByViewers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Hakuna vituo bado.', style: AdminTheme.body(13, color: AdminColors.textHint)),
            )
          else
            ...state.topChannelsByViewers.map((c) => _ChannelRankRow(channel: c)),
          const SizedBox(height: 8),
          Text(
            'Vituo ${state.channels.length} · Bei ${state.pricingPlans.length} · Ratiba ${state.schedule.length}',
            style: AdminTheme.body(12, color: AdminColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AdminTheme.heading(22, color: AdminColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label, style: AdminTheme.body(12, color: AdminColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ChannelRankRow extends StatelessWidget {
  final AdminChannel channel;
  const _ChannelRankRow({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              gradient: LinearGradient(colors: channel.gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              channel.live ? Icons.live_tv_rounded : Icons.movie_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel.name, style: AdminTheme.body(14, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                Text(
                  kCategoryLabels[channel.category] ?? channel.category,
                  style: AdminTheme.body(12, color: AdminColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            _formatViewers(channel.viewers),
            style: AdminTheme.body(13, color: AdminColors.green, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _formatViewers(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

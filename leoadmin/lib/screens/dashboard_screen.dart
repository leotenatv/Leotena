import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final contentBars = <(String, double)>[
      ('Vituo', state.channels.length.toDouble()),
      ('LIVE', state.liveChannelCount.toDouble()),
      ('Ratiba', state.schedule.length.toDouble()),
      ('Slaidi', state.slides.length.toDouble()),
      ('Bei', state.pricingPlans.length.toDouble()),
      ('Malipo', state.successfulPaymentsCount.toDouble()),
    ];

    return AdminPage(
      toolbar: const [],
      child: ListView(
        children: [
          _HeroBanner(
            users: state.users.length,
            premium: state.premiumUserCount,
            revenue: state.revenueLabel,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 820;
              if (wide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: _ContentChart(data: contentBars)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _QuickGrid(state: state)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _ContentChart(data: contentBars),
                  const SizedBox(height: 16),
                  _QuickGrid(state: state),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _KpiCard(
                    label: 'Watumiaji',
                    value: '${state.users.length}',
                    icon: Icons.people_rounded,
                    gradient: const [Color(0xFF1D4A82), Color(0xFF3A86C9)],
                  ),
                  _KpiCard(
                    label: 'Premium',
                    value: '${state.premiumUserCount}',
                    icon: Icons.workspace_premium_rounded,
                    gradient: const [Color(0xFF0A7D4A), Color(0xFF19B26B)],
                  ),
                  _KpiCard(
                    label: 'Vituo LIVE',
                    value: '${state.liveChannelCount}',
                    icon: Icons.live_tv_rounded,
                    gradient: const [Color(0xFF5B2A86), Color(0xFF9B59B6)],
                  ),
                  _KpiCard(
                    label: 'Malipo',
                    value: '${state.successfulPaymentsCount}',
                    icon: Icons.payments_rounded,
                    gradient: const [Color(0xFF0F2748), Color(0xFF1D4A82)],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Malipo ya hivi karibuni', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (state.recentPayments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Hakuna malipo bado.',
                style: AdminTheme.body(13, color: AdminColors.textHint),
              ),
            )
          else
            ...state.recentPayments.map((s) => _PaymentRow(record: s)),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final int users;
  final int premium;
  final String revenue;

  const _HeroBanner({required this.users, required this.premium, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A7D4A), Color(0xFF19B26B), Color(0xFF1D4A82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AdminColors.green.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leotena Admin', style: AdminTheme.heading(26, color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  '$users watumiaji · $premium premium',
                  style: AdminTheme.body(14, color: Colors.white.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Mapato ya leo', style: AdminTheme.body(11, color: Colors.white70)),
                Text(revenue, style: AdminTheme.heading(16, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentChart extends StatelessWidget {
  final List<(String, double)> data;
  const _ContentChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((e) => e.$2).fold<double>(0, (a, b) => a > b ? a : b);
    final chartMax = maxY <= 0 ? 1.0 : maxY * 1.2;
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i].$2));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Yaliyomo (sasa)', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AdminColors.border.withValues(alpha: 0.25),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: AdminTheme.body(10, color: AdminColors.textHint),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length) return const SizedBox.shrink();
                        return Text(data[i].$1, style: AdminTheme.body(9, color: AdminColors.textHint));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AdminColors.green,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AdminColors.green,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminColors.green.withValues(alpha: 0.35),
                          AdminColors.green.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  final AdminState state;
  const _QuickGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Watumiaji', Icons.people_rounded, 'users', AdminColors.green),
      ('Bei', Icons.sell_rounded, 'pricing', AdminColors.info),
      ('Vituo', Icons.live_tv_rounded, 'channels', AdminColors.warning),
      ('Slaidi', Icons.view_carousel_rounded, 'carousel', Color(0xFF9B59B6)),
      ('Ratiba', Icons.schedule_rounded, 'ratiba', AdminColors.navyMid),
      ('Malipo', Icons.payments_rounded, 'subscriptions', AdminColors.greenDark),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Haraka', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: items.map((item) {
              return Material(
                color: AdminColors.bg,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: () => state.setSection(item.$3),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$2, color: item.$4, size: 22),
                        const SizedBox(height: 8),
                        Text(item.$1, style: AdminTheme.body(13, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 26),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AdminTheme.heading(24, color: Colors.white)),
              Text(label, style: AdminTheme.body(12, color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final SubscriptionRecord record;
  const _PaymentRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AdminColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.payments_rounded, color: AdminColors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.user.isEmpty ? 'Mtumiaji' : record.user,
                    style: AdminTheme.body(14, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                Text(record.packageName, style: AdminTheme.body(12, color: AdminColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(record.amount, style: AdminTheme.body(13, color: AdminColors.green, weight: FontWeight.w800)),
              Text(record.date, style: AdminTheme.body(11, color: AdminColors.textHint)),
            ],
          ),
        ],
      ),
    );
  }
}

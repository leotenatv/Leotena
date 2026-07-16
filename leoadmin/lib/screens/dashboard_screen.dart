import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    const stats = AdminRepository.stats;
    const weekly = AdminRepository.weeklyUsers;

    return AdminPage(
      toolbar: const [],
      child: ListView(
        children: [
          _HeroBanner(
            users: state.users.length,
            premium: state.premiumUserCount,
            revenue: stats.revenueTzs,
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
                      Expanded(flex: 3, child: _GrowthChart(data: weekly)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _QuickGrid(state: state)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _GrowthChart(data: weekly),
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
                    label: 'Filamu',
                    value: '${state.channels.where((c) => c.category == 'movies').length}',
                    icon: Icons.movie_rounded,
                    gradient: const [Color(0xFF0F2748), Color(0xFF1D4A82)],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Shughuli za hivi karibuni', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...AdminRepository.activities.map((a) => _ActivityRow(item: a)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text('Mapato', style: AdminTheme.body(11, color: Colors.white70)),
                    Text(revenue, style: AdminTheme.heading(16, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              _HeroChip(icon: Icons.trending_up_rounded, label: '+12.5% watumiaji'),
              SizedBox(width: 10),
              _HeroChip(icon: Icons.star_rounded, label: '+8.3% premium'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label, style: AdminTheme.body(12, color: Colors.white, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _GrowthChart extends StatelessWidget {
  final List<double> data;
  const _GrowthChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = List.generate(data.length, (i) => FlSpot(i.toDouble(), data[i]));
    final maxY = data.reduce((a, b) => a > b ? a : b) * 1.15;

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
          Text('Watumiaji (siku 7)', style: AdminTheme.body(15, color: AdminColors.textPrimary, weight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
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
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        '${(v / 1000).toStringAsFixed(0)}k',
                        style: AdminTheme.body(10, color: AdminColors.textHint),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const days = ['J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'J7'];
                        final i = v.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        return Text(days[i], style: AdminTheme.body(10, color: AdminColors.textHint));
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

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  const _ActivityRow({required this.item});

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
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.circle, color: item.color, size: 10),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AdminTheme.body(14, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                Text(item.subtitle, style: AdminTheme.body(12, color: AdminColors.textSecondary)),
              ],
            ),
          ),
          Text(item.time, style: AdminTheme.body(11, color: AdminColors.textHint)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/common.dart';

/// TV schedule tab — day picker and programme timeline with reminders.
class RatibaScreen extends StatefulWidget {
  const RatibaScreen({super.key});

  @override
  State<RatibaScreen> createState() => _RatibaScreenState();
}

class _RatibaScreenState extends State<RatibaScreen> {
  int _activeDay = 2;
  final Set<int> _reminders = {};

  static const _days = [
    ['Jmn', '26'],
    ['Jmosi', '27'],
    ['Leo', '28'],
    ['Jmn', '29'],
    ['Alh', '30'],
    ['Iju', '01'],
  ];

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final schedule = context.watch<AppState>().schedule;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgSoft, AppColors.bg],
          stops: [0, 0.32],
        ),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.maxContentWidth),
          child: ListView(
            padding: EdgeInsets.only(top: r.topContent, bottom: r.bottomNavClearance),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ratiba', style: AppTheme.heading(r.sp(26))),
                    const SizedBox(height: 4),
                    Text('Mipango ya vipindi na mechi',
                        style: AppTheme.body(r.sp(13), color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: r.sp(72),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 9),
                  itemBuilder: (_, i) => _dayChip(i, r),
                ),
              ),
              SizedBox(height: r.sectionGap),
              ...List.generate(schedule.length, (i) => _scheduleRow(schedule[i], i, r)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dayChip(int i, R r) {
    final active = i == _activeDay;
    return GestureDetector(
      onTap: () => setState(() => _activeDay = i),
      child: Container(
        width: r.sp(62),
        padding: EdgeInsets.symmetric(vertical: r.sp(12), horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [AppColors.navy, AppColors.navyMid]) : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.shadow(blur: 22, y: 12, opacity: 0.35),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_days[i][0],
                style: AppTheme.body(r.sp(11),
                    color: active ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_days[i][1], style: AppTheme.heading(r.sp(19), color: active ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(ScheduleItem item, int index, R r) {
    final reminded = _reminders.contains(index);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: r.sp(54),
            child: Column(
              children: [
                Text(item.time, style: AppTheme.heading(r.sp(14))),
                Text(item.ampm, style: AppTheme.body(r.sp(10), color: AppColors.textHint, weight: FontWeight.w700)),
                Container(
                  width: 2,
                  height: r.sp(72),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(2)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FloatingCard(
                padding: EdgeInsets.all(r.sp(14)),
                child: Row(
                  children: [
                    Container(
                      width: r.sp(52),
                      height: r.sp(52),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: item.gradient),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: Colors.white, size: r.sp(22)),
                    ),
                    SizedBox(width: r.sp(13)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.body(r.sp(14), color: AppColors.textPrimary, weight: FontWeight.w700)),
                              ),
                              if (item.live) ...[const SizedBox(width: 7), const GreenBadge('LIVE')],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(r.sp(11.5), color: AppColors.textHint)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (reminded) {
                          _reminders.remove(index);
                        } else {
                          _reminders.add(index);
                        }
                      }),
                      child: Container(
                        width: r.sp(40),
                        height: r.sp(40),
                        decoration: BoxDecoration(
                          color: reminded ? AppColors.green : AppColors.section,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          reminded ? Icons.check_rounded : Icons.notifications_none_rounded,
                          color: reminded ? Colors.white : AppColors.textSecondary,
                          size: r.sp(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

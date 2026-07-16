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
  DateTime? _activeDay;
  final Set<String> _reminders = {};
  final _dayScrollCtrl = ScrollController();
  bool _didAutoPick = false;

  static const _weekdayShort = [
    'Jpili', // Sunday
    'Jtatu', // Monday
    'Jnn', // Tuesday
    'Jtano', // Wednesday
    'Alh', // Thursday
    'Iju', // Friday
    'Jmosi', // Saturday
  ];

  static const _monthShort = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Tanzania (EAT = UTC+3) wall-clock — matches admin schedule convention.
  DateTime get _eatNow {
    final utc = DateTime.now().toUtc();
    return utc.add(const Duration(hours: 3));
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Upcoming calendar days that actually have schedule items.
  List<DateTime> _daysWithEvents(List<ScheduleItem> schedule) {
    final today = _dateOnly(_eatNow);
    final dates = <DateTime>{};
    for (final s in schedule) {
      final raw = s.date;
      if (raw == null) continue;
      final d = _dateOnly(raw);
      if (!d.isBefore(today)) dates.add(d);
    }
    final sorted = dates.toList()..sort();
    return sorted;
  }

  List<ScheduleItem> _itemsForDay(List<ScheduleItem> schedule, DateTime day) {
    final items = schedule.where((s) {
      final raw = s.date;
      if (raw == null) return false;
      return _sameDay(raw, day);
    }).toList()
      ..sort((a, b) {
        final da = a.date ?? DateTime(0);
        final db = b.date ?? DateTime(0);
        return da.compareTo(db);
      });
    return items;
  }

  String _dayLabel(DateTime day) {
    final today = _dateOnly(_eatNow);
    if (_sameDay(day, today)) return 'Leo';
    return _weekdayShort[day.weekday % 7];
  }

  String _eventDateLabel(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day} ${_monthShort[dt.month - 1]}';
  }

  void _pickDefaultDayIfNeeded(List<DateTime> days) {
    if (days.isEmpty) {
      if (_activeDay != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _activeDay = null);
        });
      }
      return;
    }
    if (_activeDay != null && days.any((d) => _sameDay(d, _activeDay!))) return;
    final today = _dateOnly(_eatNow);
    final todayIdx = days.indexWhere((d) => _sameDay(d, today));
    final next = todayIdx >= 0 ? days[todayIdx] : days.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _activeDay = next);
      _scrollToActiveDay(days);
    });
  }

  void _scrollToActiveDay(List<DateTime> days) {
    if (_didAutoPick || _activeDay == null || !_dayScrollCtrl.hasClients) return;
    final idx = days.indexWhere((d) => _sameDay(d, _activeDay!));
    if (idx <= 0) {
      _didAutoPick = true;
      return;
    }
    _didAutoPick = true;
    final offset = (idx * 71.0).clamp(0.0, _dayScrollCtrl.position.maxScrollExtent);
    _dayScrollCtrl.animateTo(offset, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _dayScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final schedule = context.watch<AppState>().schedule;
    final days = _daysWithEvents(schedule);
    _pickDefaultDayIfNeeded(days);

    final active = _activeDay ?? (days.isEmpty ? null : days.first);
    final dayItems = active == null ? <ScheduleItem>[] : _itemsForDay(schedule, active);

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
          child: RefreshIndicator(
            color: AppColors.green,
            onRefresh: () => context.read<AppState>().refreshContent(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                if (days.isEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(r.pageGutter, 40, r.pageGutter, 0),
                    child: Center(
                      child: Text(
                        'Hakuna ratiba kwa sasa',
                        style: AppTheme.body(r.sp(14), color: AppColors.textHint),
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: r.sp(72),
                    child: ListView.separated(
                      controller: _dayScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 9),
                      itemBuilder: (_, i) => _dayChip(days[i], r),
                    ),
                  ),
                  SizedBox(height: r.sectionGap),
                  if (dayItems.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.pageGutter, vertical: 24),
                      child: Text(
                        'Hakuna vipindi siku hii',
                        style: AppTheme.body(r.sp(13), color: AppColors.textHint),
                      ),
                    )
                  else
                    ...List.generate(dayItems.length, (i) => _scheduleRow(dayItems[i], i, r)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayChip(DateTime day, R r) {
    final active = _activeDay != null && _sameDay(day, _activeDay!);
    return GestureDetector(
      onTap: () => setState(() => _activeDay = day),
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
            Text(
              _dayLabel(day),
              style: AppTheme.body(
                r.sp(11),
                color: active ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}'.padLeft(2, '0'),
              style: AppTheme.heading(r.sp(19), color: active ? Colors.white : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(ScheduleItem item, int index, R r) {
    final key = '${item.title}-${item.date?.toIso8601String() ?? index}';
    final reminded = _reminders.contains(key);
    final dateLabel = _eventDateLabel(item.date);
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
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(dateLabel, style: AppTheme.body(r.sp(9), color: AppColors.textHint, weight: FontWeight.w700)),
                ],
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
                          Text(
                            [
                              if (dateLabel.isNotEmpty) dateLabel,
                              if (item.subtitle.isNotEmpty) item.subtitle,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(r.sp(11.5), color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (reminded) {
                          _reminders.remove(key);
                        } else {
                          _reminders.add(key);
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

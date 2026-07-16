import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class RatibaScreen extends StatelessWidget {
  const RatibaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final items = List<AdminScheduleItem>.from(state.schedule)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return AdminPage(
      toolbar: [
        Text('${items.length} vipindi', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => _openEditor(context, state.newScheduleDraft(), isNew: true),
        ),
      ],
      child: items.isEmpty
          ? Center(child: Text('Hakuna vipindi', style: AdminTheme.body(13, color: AdminColors.textHint)))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final s = items[i];
                final subtitleParts = [
                  if (s.channel.isNotEmpty) s.channel,
                  AdminScheduleItem.dateLabel(s.dateTime),
                  if (s.subtitle.isNotEmpty) s.subtitle,
                ];

                return AdminListTile(
                  leading: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: s.gradient),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(AdminScheduleItem.timeLabel(s.dateTime),
                            style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
                        Text(AdminScheduleItem.periodLabel(s.dateTime), style: AdminTheme.body(9, color: Colors.white70)),
                      ],
                    ),
                  ),
                  title: s.title,
                  titleContent: s.isMatch ? _MatchTitle(team1: s.team1, team2: s.team2) : null,
                  subtitle: subtitleParts.join(' · '),
                  badges: [
                    StatusBadge(s.isMatch ? 'MECHI' : 'KIPINDI', color: s.isMatch ? AdminColors.warning : AdminColors.navyMid),
                    if (s.live) const StatusBadge('LIVE', color: AdminColors.green),
                    if (!s.active) const StatusBadge('Zimwa', color: AdminColors.textHint),
                  ],
                  actions: [
                    IconButton(
                      onPressed: () => _openEditor(context, s, isNew: false),
                      icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
                    ),
                    Switch(
                      value: s.active,
                      activeThumbColor: AdminColors.green,
                      onChanged: (_) => runWithErrorSnackBar(
                          context, () => context.read<AdminState>().toggleScheduleActive(s.id)),
                    ),
                    DeleteIconButton(
                      onDelete: () => deleteWithConfirm(
                        context,
                        dialogTitle: 'Futa kipindi',
                        itemName: s.title,
                        onDelete: () => context.read<AdminState>().deleteScheduleItem(s.id),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, AdminScheduleItem item, {required bool isNew}) async {
    final channels = context.read<AdminState>().channels;
    final title = TextEditingController(text: item.title);
    final subtitle = TextEditingController(text: item.subtitle);
    final team1 = TextEditingController(text: item.team1);
    final team2 = TextEditingController(text: item.team2);
    var isMatch = item.isMatch;
    var channel = channels.any((c) => c.name == item.channel)
        ? item.channel
        : (channels.isNotEmpty ? channels.first.name : '');
    var date = DateTime(item.dateTime.year, item.dateTime.month, item.dateTime.day);
    var timeOfDay = TimeOfDay.fromDateTime(item.dateTime);
    var live = item.live;
    var active = item.active;
    var saving = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: isNew ? 'Kipindi kipya' : 'Hariri kipindi',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminFieldLabel('Aina'),
            Row(
              children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Kipindi / Filamu',
                    selected: !isMatch,
                    onTap: () => setLocal(() => isMatch = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    label: 'Mechi',
                    selected: isMatch,
                    onTap: () => setLocal(() => isMatch = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (isMatch) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Timu ya 1'),
                        adminTextField(controller: team1, hint: 'Simba'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 26, left: 8, right: 8),
                    child: Text('VS', style: AdminTheme.body(12, color: AdminColors.textHint, weight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Timu ya 2'),
                        adminTextField(controller: team2, hint: 'Yanga'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              adminFieldLabel('Ligi / Maelezo'),
              adminTextField(controller: subtitle, hint: 'Ligi Kuu'),
            ] else ...[
              adminFieldLabel('Kichwa'),
              adminTextField(controller: title, hint: 'Habari za Jioni'),
              const SizedBox(height: 14),
              adminFieldLabel('Maelezo'),
              adminTextField(controller: subtitle, hint: 'Maelezo mafupi'),
            ],
            const SizedBox(height: 14),
            adminFieldLabel('Kituo'),
            channels.isEmpty
                ? Text('Hakuna vituo — ongeza kituo kwanza', style: AdminTheme.body(12, color: AdminColors.textHint))
                : DropdownButtonFormField<String>(
                    initialValue: channel,
                    dropdownColor: AdminColors.surfaceLight,
                    style: AdminTheme.body(14, color: AdminColors.textPrimary),
                    items: channels.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                    onChanged: (v) => setLocal(() => channel = v ?? channel),
                  ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      adminFieldLabel('Tarehe'),
                      _PickerField(
                        icon: Icons.calendar_month_rounded,
                        label: '${date.day}/${date.month}/${date.year}',
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(date.year - 1),
                            lastDate: DateTime(date.year + 2),
                          );
                          if (picked != null) setLocal(() => date = picked);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      adminFieldLabel('Saa (Muda wa Tanzania — EAT)'),
                      _PickerField(
                        icon: Icons.access_time_rounded,
                        label: timeOfDay.format(ctx),
                        onTap: () async {
                          final picked = await showTimePicker(context: ctx, initialTime: timeOfDay);
                          if (picked != null) setLocal(() => timeOfDay = picked);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('LIVE', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: live,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => live = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Hai', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: active,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => active = v),
            ),
            if (formError != null) adminFormError(formError!),
            adminSaveButton(
              label: isNew ? 'Ongeza' : 'Hifadhi',
              loading: saving,
              onTap: () async {
                final combined = DateTime(date.year, date.month, date.day, timeOfDay.hour, timeOfDay.minute);
                final resolvedTitle = isMatch
                    ? '${team1.text.trim()} vs ${team2.text.trim()}'
                    : title.text.trim();
                if (isMatch && (team1.text.trim().isEmpty || team2.text.trim().isEmpty)) return;
                if (!isMatch && title.text.trim().isEmpty) return;

                final next = item.copyWith(
                  dateTime: combined,
                  title: resolvedTitle,
                  subtitle: subtitle.text.trim(),
                  channel: channel,
                  team1: isMatch ? team1.text.trim() : '',
                  team2: isMatch ? team2.text.trim() : '',
                  live: live,
                  active: active,
                );
                setLocal(() {
                  saving = true;
                  formError = null;
                });
                final state = context.read<AdminState>();
                try {
                  if (isNew) {
                    await state.addScheduleItem(next);
                  } else {
                    await state.updateScheduleItem(next);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } on ApiException catch (e) {
                  setLocal(() {
                    saving = false;
                    formError = e.message;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AdminColors.green : AdminColors.surfaceLight.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AdminTheme.body(13, color: selected ? Colors.white : AdminColors.textSecondary, weight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surfaceLight.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AdminColors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: AdminTheme.body(13, color: AdminColors.textPrimary, weight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Team-vs-team title row: small initials avatar + name on each side of "VS".
class _MatchTitle extends StatelessWidget {
  final String team1;
  final String team2;
  const _MatchTitle({required this.team1, required this.team2});

  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TeamAvatar(initials: _initials(team1)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(team1,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AdminTheme.body(13, color: AdminColors.textPrimary, weight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('VS', style: AdminTheme.body(11, color: AdminColors.green, weight: FontWeight.w800)),
        ),
        Flexible(
          child: Text(team2,
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
              style: AdminTheme.body(13, color: AdminColors.textPrimary, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 6),
        _TeamAvatar(initials: _initials(team2)),
      ],
    );
  }
}

class _TeamAvatar extends StatelessWidget {
  final String initials;
  const _TeamAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AdminColors.navyMid,
        shape: BoxShape.circle,
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
      ),
      child: Text(initials, style: AdminTheme.body(8, color: Colors.white, weight: FontWeight.w800)),
    );
  }
}

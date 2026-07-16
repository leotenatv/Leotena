import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final q = state.userQuery.toLowerCase();
    final list = state.users.where((u) {
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.phone.contains(q) ||
          u.deviceId.toLowerCase().contains(q);
    }).toList();

    return AdminPage(
      toolbar: [
        Expanded(child: SearchField(hint: 'Tafuta jina, simu, kifaa…', onChanged: state.setUserQuery)),
        const SizedBox(width: 12),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => openUserEditor(context, state.newUserDraft(), isNew: true),
        ),
      ],
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) => _UserRow(user: list[i]),
      ),
    );
  }
}

Future<void> openUserEditor(BuildContext context, AppUser user, {required bool isNew}) async {
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final device = TextEditingController(text: user.deviceId);
    var active = user.active;
    var saving = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: isNew ? 'Mtumiaji mpya' : 'Hariri mtumiaji',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminFieldLabel('Jina'),
            adminTextField(controller: name, hint: 'Amani Joseph'),
            const SizedBox(height: 14),
            adminFieldLabel('Simu'),
            adminTextField(controller: phone, hint: '0712345678', keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            adminFieldLabel('Kifaa (Device ID)'),
            adminTextField(controller: device, hint: 'LT-XXXX'),
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
                final next = user.copyWith(
                  name: name.text.trim(),
                  phone: phone.text.trim(),
                  deviceId: device.text.trim(),
                  active: active,
                );
                if (next.name.isEmpty) return;
                setLocal(() {
                  saving = true;
                  formError = null;
                });
                final state = context.read<AdminState>();
                try {
                  if (isNew) {
                    await state.addUser(next);
                  } else {
                    await state.updateUser(next);
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

class _UserRow extends StatelessWidget {
  final AppUser user;
  const _UserRow({required this.user});

  @override
  Widget build(BuildContext context) {
    final premium = user.hasPremiumAccess;
    final remaining = AppUser.formatPremiumRemaining(user.premiumUntil, plan: user.plan);

    return AdminListTile(
      leading: CircleAvatar(
        backgroundColor: premium ? AdminColors.green.withValues(alpha: 0.25) : AdminColors.navyMid,
        child: Icon(
          premium ? Icons.workspace_premium_rounded : Icons.person_rounded,
          color: premium ? AdminColors.green : Colors.white,
          size: 22,
        ),
      ),
      title: user.name,
      subtitle: '${user.phone} · ${user.deviceId}',
      badges: [
        StatusBadge(
          premium ? remaining : 'Bure',
          color: premium ? AdminColors.green : AdminColors.info,
        ),
        if (!user.active) const StatusBadge('Zimwa', color: AdminColors.textHint),
      ],
      actions: [
        _AccessBtn(user: user),
        IconButton(
          tooltip: 'Hariri',
          onPressed: () => openUserEditor(context, user, isNew: false),
          icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
        ),
        Switch(
          value: user.active,
          activeThumbColor: AdminColors.green,
          onChanged: (_) =>
              runWithErrorSnackBar(context, () => context.read<AdminState>().toggleUserActive(user.id)),
        ),
        DeleteIconButton(
          onDelete: () => deleteWithConfirm(
            context,
            dialogTitle: 'Futa mtumiaji',
            itemName: user.name,
            onDelete: () => context.read<AdminState>().deleteUser(user.id),
          ),
        ),
      ],
    );
  }
}

class _AccessBtn extends StatelessWidget {
  final AppUser user;
  const _AccessBtn({required this.user});

  @override
  Widget build(BuildContext context) {
    final active = user.hasPremiumAccess;
    final color = active ? AdminColors.green : AdminColors.info;
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _AccessSheet.show(context, user),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? Icons.verified_rounded : Icons.vpn_key_rounded, color: color, size: 18),
              const SizedBox(width: 4),
              Text('Ufikiaji', style: AdminTheme.body(11, color: color, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grants or revokes a user's premium access, in minutes/hours/days/weeks.
class _AccessSheet extends StatefulWidget {
  final AppUser user;
  const _AccessSheet({required this.user});

  static Future<void> show(BuildContext context, AppUser user) {
    return showAdminSheet(
      context: context,
      title: 'Dhibiti Ufikiaji',
      child: _AccessSheet(user: user),
    );
  }

  @override
  State<_AccessSheet> createState() => _AccessSheetState();
}

class _AccessSheetState extends State<_AccessSheet> {
  int _amount = 1;
  PremiumDurationUnit _unit = PremiumDurationUnit.days;
  bool _busy = false;

  static const _presets = <(int, PremiumDurationUnit, String, IconData)>[
    (30, PremiumDurationUnit.minutes, '30 dakika', Icons.bolt_rounded),
    (1, PremiumDurationUnit.hours, '1 saa', Icons.schedule_rounded),
    (6, PremiumDurationUnit.hours, '6 masaa', Icons.schedule_rounded),
    (1, PremiumDurationUnit.days, '1 siku', Icons.today_rounded),
    (7, PremiumDurationUnit.days, '7 siku', Icons.date_range_rounded),
    (4, PremiumDurationUnit.weeks, '4 wiki', Icons.calendar_month_rounded),
  ];

  Future<void> _grant(int amount, PremiumDurationUnit unit) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AdminState>().grantPremium(widget.user.id, amount, unit);
      if (!mounted) return;
      Navigator.pop(context);
      _toast('Ufikiaji umetolewa kwa ${widget.user.name}', AdminColors.greenDark);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Imeshindwa: ${e.message}', AdminColors.danger);
    }
  }

  Future<void> _revoke() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AdminState>().revokePremium(widget.user.id);
      if (!mounted) return;
      Navigator.pop(context);
      _toast('Ufikiaji wa ${widget.user.name} umeondolewa', AdminColors.danger);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('Imeshindwa: ${e.message}', AdminColors.danger);
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AdminTheme.body(13, color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final active = u.hasPremiumAccess;
    final remaining = AppUser.formatPremiumRemaining(u.premiumUntil, plan: u.plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active
                  ? [AdminColors.greenDark, AdminColors.green]
                  : [AdminColors.surfaceLight, AdminColors.navyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                    style: AdminTheme.body(18, color: Colors.white, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: AdminTheme.body(15, color: Colors.white, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(active ? Icons.verified_rounded : Icons.lock_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.9), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          active ? 'Inaendelea: $remaining' : 'Hana ufikiaji sasa',
                          style: AdminTheme.body(12, color: Colors.white.withValues(alpha: 0.9), weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Ongeza haraka', style: AdminTheme.body(13, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            return Material(
              color: AdminColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _busy ? null : () => _grant(p.$1, p.$2),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.$4, color: AdminColors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(p.$3, style: AdminTheme.body(12, color: AdminColors.textPrimary, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Text('Kiasi maalum', style: AdminTheme.body(13, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AdminColors.surfaceLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                onTap: () => setState(() => _amount = (_amount - 1).clamp(1, 999)),
              ),
              Expanded(
                child: Text(
                  '$_amount',
                  textAlign: TextAlign.center,
                  style: AdminTheme.heading(20, color: AdminColors.textPrimary),
                ),
              ),
              _StepButton(
                icon: Icons.add_rounded,
                onTap: () => setState(() => _amount = (_amount + 1).clamp(1, 999)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PremiumDurationUnit.values.map((unit) {
            final selected = unit == _unit;
            return ChoiceChip(
              label: Text(AppUser.unitLabel(unit, amount: _amount)),
              selected: selected,
              onSelected: (_) => setState(() => _unit = unit),
              showCheckmark: false,
              labelStyle: AdminTheme.body(12, color: selected ? Colors.white : AdminColors.textSecondary, weight: FontWeight.w700),
              selectedColor: AdminColors.green,
              backgroundColor: AdminColors.bg,
              side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: active && !_busy ? _revoke : null,
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                label: Text('Ondoa Ufikiaji', style: AdminTheme.body(13, weight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdminColors.danger,
                  disabledForegroundColor: AdminColors.textHint,
                  side: BorderSide(color: active ? AdminColors.danger : AdminColors.border.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: adminSaveButton(
                label: 'Toa Ufikiaji',
                loading: _busy,
                onTap: () => _grant(_amount, _unit),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AdminColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

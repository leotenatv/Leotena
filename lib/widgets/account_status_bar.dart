import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

/// Navbar identity: the device id an admin uses to unlock, plus a live
/// subscription clock once premium is active.
class AccountStatusBar extends StatefulWidget {
  const AccountStatusBar({super.key});

  @override
  State<AccountStatusBar> createState() => _AccountStatusBarState();
}

class _AccountStatusBarState extends State<AccountStatusBar> {
  Timer? _tick;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _copy(String id) async {
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ID imenakiliwa', style: AppTheme.body(13, color: Colors.white)),
        backgroundColor: AppColors.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final r = R.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 860;
    final id = state.deviceId;
    final subscribed = state.subscribed;

    final identity = _IdentityChip(
      id: id.isEmpty ? 'Inaandaliwa…' : id,
      copied: _copied,
      onCopy: id.isEmpty ? null : () => _copy(id),
    );
    final clock = subscribed ? _RemainingClock(remaining: state.remaining, stretch: !wide) : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.pageGutter, 10, r.pageGutter, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD6E8F6)),
          boxShadow: AppColors.shadow(blur: 22, y: 10, opacity: 0.08),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: wide
              ? Row(
                  children: [
                    Expanded(child: identity),
                    if (clock != null) ...[
                      const SizedBox(width: 16),
                      clock,
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    if (clock != null) ...[
                      const SizedBox(height: 10),
                      clock,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  final String id;
  final bool copied;
  final VoidCallback? onCopy;

  const _IdentityChip({required this.id, required this.copied, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.navyMid, AppColors.navy]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID YA MTUMIAJI',
                style: AppTheme.body(10, color: AppColors.textHint, weight: FontWeight.w800)
                    .copyWith(letterSpacing: 0.6),
              ),
              const SizedBox(height: 2),
              Text(
                id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(14, color: AppColors.textPrimary, weight: FontWeight.w800)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                'Tuma kwa admin kufungua',
                style: AppTheme.body(11, color: AppColors.textSecondary, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: copied ? AppColors.green.withValues(alpha: 0.14) : AppColors.section,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                copied ? Icons.check_rounded : Icons.copy_rounded,
                color: AppColors.greenDark,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemainingClock extends StatelessWidget {
  final Duration remaining;
  final bool stretch;

  const _RemainingClock({required this.remaining, required this.stretch});

  @override
  Widget build(BuildContext context) {
    final parts = _parts(remaining);
    final units = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) units.add(const SizedBox(width: 6));
      final tick = _Tick(value: parts[i].$1, label: parts[i].$2);
      units.add(stretch ? Expanded(child: tick) : tick);
    }
    return Column(
      crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
      children: [
        Text(
          'MUDA ULIOSALIA',
          style: AppTheme.body(10, color: AppColors.textHint, weight: FontWeight.w800)
              .copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 6),
        Row(mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min, children: units),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  final String value;
  final String label;
  const _Tick({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.heading(18).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.body(9, color: AppColors.greenDark, weight: FontWeight.w800)
                .copyWith(letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}

List<(String, String)> _parts(Duration remaining) {
  String two(int n) => n.toString().padLeft(2, '0');
  final days = remaining.inDays < 0 ? 0 : remaining.inDays;
  return [
    ('$days', 'Siku'),
    (two(remaining.inHours % 24), 'Masaa'),
    (two(remaining.inMinutes % 60), 'Dakika'),
    (two(remaining.inSeconds % 60), 'Sekunde'),
  ];
}

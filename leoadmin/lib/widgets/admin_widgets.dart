import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: card);
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final List<Color> gradient;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: gradient.first.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AdminTheme.body(12, color: Colors.white.withValues(alpha: 0.85)))),
              Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 26),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: AdminTheme.heading(28, color: Colors.white)),
          const SizedBox(height: 6),
          Text('↑ $delta', style: AdminTheme.body(12, color: Colors.white.withValues(alpha: 0.9))),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge(this.label, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: AdminTheme.body(11, color: color, weight: FontWeight.w800)),
    );
  }
}

class AdminPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const AdminPrimaryButton({super.key, required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon ?? Icons.add_rounded, size: 18),
      label: Text(label, style: AdminTheme.body(13, color: Colors.white, weight: FontWeight.w800)),
    );
  }
}

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AdminTheme.body(14, color: AdminColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textHint, size: 20),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AdminTheme.heading(24)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AdminTheme.body(13, color: AdminColors.textHint)),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

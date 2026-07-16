import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../models/admin_models.dart';
import '../theme/admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  final String activeId;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogout;
  final bool compact;

  const AdminSidebar({
    super.key,
    required this.activeId,
    required this.onSelect,
    required this.onLogout,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surface,
      child: Container(
        width: compact ? 72 : 260,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: AdminColors.border.withValues(alpha: 0.35))),
        ),
        child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 22, 28, compact ? 12 : 22, 24),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AdminColors.greenDark, AdminColors.green]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 26),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Expanded(child: Text('LeoAdmin', style: AdminTheme.heading(18))),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
              children: [
                for (final item in AdminRepository.navItems)
                  _NavTile(
                    item: item,
                    active: item.id == activeId,
                    compact: compact,
                    onTap: () => onSelect(item.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 10 : 16),
            child: compact
                ? IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, color: AdminColors.danger),
                  )
                : InkWell(
                    onTap: onLogout,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: AdminColors.surfaceLight,
                            child: Icon(Icons.person_rounded, color: AdminColors.green, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Admin', style: AdminTheme.body(13, color: AdminColors.textPrimary)),
                                Text('admin@leotena.com', style: AdminTheme.body(10, color: AdminColors.textHint), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.logout_rounded, color: AdminColors.danger, size: 18),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final AdminNavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.active, required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = active ? AdminColors.green.withValues(alpha: 0.18) : Colors.transparent;
    final fg = active ? AdminColors.green : AdminColors.textSecondary;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: item.label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(item.icon, color: fg, size: 22),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: active ? Border.all(color: AdminColors.green.withValues(alpha: 0.35)) : null,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: fg, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label, style: AdminTheme.body(13, color: active ? AdminColors.textPrimary : fg))),
            ],
          ),
        ),
      ),
    );
  }
}

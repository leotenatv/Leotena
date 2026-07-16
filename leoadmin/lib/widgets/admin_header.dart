import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final Widget? trailing;

  const AdminHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenu,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onMenu != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: IconButton(
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded, color: AdminColors.textPrimary),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AdminTheme.heading(26)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AdminTheme.body(13, color: AdminColors.textHint)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

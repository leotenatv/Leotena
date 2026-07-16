import 'package:flutter/material.dart';
import '../theme/admin_theme.dart';

/// Shared page chrome: toolbar row + scrollable body. No subtitle clutter.
class AdminPage extends StatelessWidget {
  final List<Widget> toolbar;
  final Widget child;

  const AdminPage({super.key, required this.toolbar, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: toolbar),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Clean list row card used across CRUD screens.
class AdminListTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final Widget? titleContent;
  final String? subtitle;
  final List<Widget> badges;
  final Widget? footer;
  final Widget? dragHandle;
  final List<Widget> actions;

  const AdminListTile({
    super.key,
    required this.leading,
    required this.title,
    this.titleContent,
    this.subtitle,
    this.badges = const [],
    this.footer,
    this.dragHandle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 10)],
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleContent ??
                    Text(title,
                        style: AdminTheme.body(15,
                            color: AdminColors.textPrimary,
                            weight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!,
                      style: AdminTheme.body(12,
                          color: AdminColors.textSecondary)),
                ],
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: badges),
                ],
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  footer!,
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

Future<T?> showAdminSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        // Material (not a plain decorated Container) so ListTile/SwitchListTile
        // descendants (used throughout the editor forms) paint ink splashes on
        // this surface instead of leaking through to whatever is behind it.
        child: Material(
          color: AdminColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: AdminColors.border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(title, style: AdminTheme.heading(20)),
                const SizedBox(height: 16),
                Flexible(child: SingleChildScrollView(child: child)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget adminFieldLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label,
          style: AdminTheme.body(12,
              color: AdminColors.textSecondary, weight: FontWeight.w700)),
    );

Widget adminTextField({
  required TextEditingController controller,
  String? hint,
  TextInputType? keyboardType,
  int maxLines = 1,
}) {
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    maxLines: maxLines,
    style: AdminTheme.body(14, color: AdminColors.textPrimary),
    decoration: InputDecoration(hintText: hint),
  );
}

Widget adminSaveButton({required String label, required VoidCallback onTap, bool loading = false}) {
  return FilledButton(
    onPressed: loading ? null : onTap,
    style: FilledButton.styleFrom(
      backgroundColor: AdminColors.green,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label, style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
  );
}

Widget adminFormError(String message) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(message, style: AdminTheme.body(12, color: AdminColors.danger, weight: FontWeight.w700)),
    );

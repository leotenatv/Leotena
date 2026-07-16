import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../theme/admin_theme.dart';

/// Shows a confirmation dialog before deleting. Returns true if confirmed.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String itemName,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AdminColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35))),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AdminColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AdminTheme.heading(17))),
        ],
      ),
      content: Text(
        'Una uhakika unataka kufuta "$itemName"? Hatua hii haiwezi kutenduliwa.',
        style: AdminTheme.body(13, color: AdminColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Ghairi', style: AdminTheme.body(13, color: AdminColors.textHint)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
          child: Text('Futa', style: AdminTheme.body(13, color: Colors.white, weight: FontWeight.w800)),
        ),
      ],
    ),
  );
  return ok == true;
}

void showDeletedSnackBar(BuildContext context, String itemName) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"$itemName" imefutwa', style: AdminTheme.body(13, color: Colors.white)),
      backgroundColor: AdminColors.surfaceLight,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AdminTheme.body(13, color: Colors.white)),
      backgroundColor: AdminColors.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Runs a fire-and-forget API call (toggles, reorders) and surfaces any
/// [ApiException] as a SnackBar instead of letting it become an unhandled
/// async error.
Future<void> runWithErrorSnackBar(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on ApiException catch (e) {
    if (context.mounted) showErrorSnackBar(context, e.message);
  }
}

Future<void> deleteWithConfirm(
  BuildContext context, {
  required String dialogTitle,
  required String itemName,
  required Future<void> Function() onDelete,
}) async {
  if (!await confirmDelete(context, title: dialogTitle, itemName: itemName)) return;
  try {
    await onDelete();
    if (context.mounted) showDeletedSnackBar(context, itemName);
  } on ApiException catch (e) {
    if (context.mounted) showErrorSnackBar(context, 'Imeshindwa kufuta: ${e.message}');
  }
}

class DeleteIconButton extends StatelessWidget {
  final VoidCallback onDelete;
  final double size;

  const DeleteIconButton({super.key, required this.onDelete, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onDelete,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size + 14, minHeight: size + 14),
      icon: Icon(Icons.delete_outline_rounded, color: AdminColors.danger, size: size),
      tooltip: 'Futa',
    );
  }
}

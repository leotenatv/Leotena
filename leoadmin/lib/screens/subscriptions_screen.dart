import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final list = state.subscriptions;
    final ok = list.where((s) => s.success).length;
    final fail = list.length - ok;

    return AdminPage(
      toolbar: [
        StatusBadge('$ok OK', color: AdminColors.green),
        StatusBadge('$fail Imeshindwa', color: AdminColors.danger),
        const Spacer(),
        TextButton(
          onPressed: () => context.read<AdminState>().setSection('pricing'),
          child: Text('Bei', style: AdminTheme.body(13, color: AdminColors.green, weight: FontWeight.w800)),
        ),
      ],
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final s = list[i];
          return AdminListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (s.success ? AdminColors.green : AdminColors.danger).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                s.success ? Icons.check_rounded : Icons.close_rounded,
                color: s.success ? AdminColors.green : AdminColors.danger,
              ),
            ),
            title: s.user,
            subtitle: '${s.packageName} · ${s.amount} · ${s.date}',
            actions: [
              DeleteIconButton(
                onDelete: () => deleteWithConfirm(
                  context,
                  dialogTitle: 'Futa rekodi',
                  itemName: s.user,
                  onDelete: () => context.read<AdminState>().deleteSubscription(s.id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

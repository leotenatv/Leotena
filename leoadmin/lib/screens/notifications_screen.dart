import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

/// "Arifa" — broadcast push notifications to every registered device, with
/// a history of what was sent and how many devices actually received it.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final logs = state.notifications;

    return AdminPage(
      toolbar: [
        Text('${logs.length} arifa', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Tuma Arifa',
          onTap: () => _openComposer(context),
        ),
      ],
      child: logs.isEmpty
          ? Center(child: Text('Bado hakuna arifa zilizotumwa', style: AdminTheme.body(13, color: AdminColors.textHint)))
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final n = logs[i];
                return AdminListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AdminColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_rounded, color: AdminColors.green),
                  ),
                  title: n.title,
                  subtitle: n.body,
                  badges: [
                    StatusBadge('${n.successCount} zimefika', color: AdminColors.green),
                    if (n.failureCount > 0) StatusBadge('${n.failureCount} zimeshindwa', color: AdminColors.danger),
                    StatusBadge(DateFormat('d MMM, HH:mm').format(n.createdAt.toLocal()), color: AdminColors.textHint),
                  ],
                  actions: [
                    DeleteIconButton(
                      onDelete: () => deleteWithConfirm(
                        context,
                        dialogTitle: 'Futa arifa',
                        itemName: n.title,
                        onDelete: () => context.read<AdminState>().deleteNotification(n.id),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _openComposer(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var sending = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: 'Tuma Arifa kwa Watumiaji Wote',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminFieldLabel('Kichwa'),
            adminTextField(controller: title, hint: 'Kituo kipya kimeongezwa!'),
            const SizedBox(height: 14),
            adminFieldLabel('Ujumbe'),
            adminTextField(controller: body, hint: 'Angalia mechi ya leo moja kwa moja…', maxLines: 3),
            const SizedBox(height: 8),
            Text(
              'Itatumwa kwa sauti kwa vifaa vyote hai vilivyosajiliwa kupokea arifa.',
              style: AdminTheme.body(11, color: AdminColors.textHint),
            ),
            const SizedBox(height: 14),
            if (formError != null) adminFormError(formError!),
            adminSaveButton(
              label: 'Tuma',
              loading: sending,
              onTap: () async {
                if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
                setLocal(() {
                  sending = true;
                  formError = null;
                });
                try {
                  final state = context.read<AdminState>();
                  await state.sendNotification(title.text.trim(), body.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                } on ApiException catch (e) {
                  setLocal(() {
                    sending = false;
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

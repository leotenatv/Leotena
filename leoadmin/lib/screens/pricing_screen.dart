import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final plans = state.pricingPlans;

    return AdminPage(
      toolbar: [
        Text('${plans.length} bei', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => _openEditor(context, state.newPlanDraft(), isNew: true),
        ),
      ],
      child: ListView.builder(
        itemCount: plans.length,
        itemBuilder: (_, i) {
          final p = plans[i];
          return AdminListTile(
            leading: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AdminColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(p.priceLabel.split(' ').last, style: AdminTheme.body(11, color: AdminColors.green, weight: FontWeight.w800)),
            ),
            title: p.name,
            subtitle: '${p.days} siku · ${p.note}',
            badges: [
              if (p.popular) const StatusBadge('Maarufu', color: AdminColors.green),
              StatusBadge(p.active ? 'Hai' : 'Zimwa', color: p.active ? AdminColors.green : AdminColors.textHint),
            ],
            actions: [
              IconButton(
                tooltip: 'Hariri',
                onPressed: () => _openEditor(context, p, isNew: false),
                icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
              ),
              Switch(
                value: p.active,
                activeThumbColor: AdminColors.green,
                onChanged: (_) =>
                    runWithErrorSnackBar(context, () => context.read<AdminState>().togglePlanActive(p.id)),
              ),
              DeleteIconButton(
                onDelete: () => deleteWithConfirm(
                  context,
                  dialogTitle: 'Futa bei',
                  itemName: p.name,
                  onDelete: () => context.read<AdminState>().deletePlan(p.id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, PricingPlan plan, {required bool isNew}) async {
    final name = TextEditingController(text: plan.name);
    final price = TextEditingController(text: plan.price);
    final days = TextEditingController(text: '${plan.days}');
    final note = TextEditingController(text: plan.note);
    var popular = plan.popular;
    var active = plan.active;
    var saving = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: isNew ? 'Bei mpya' : 'Hariri bei',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminFieldLabel('Jina'),
            adminTextField(controller: name, hint: 'Wiki 1'),
            const SizedBox(height: 14),
            adminFieldLabel('Bei (TSh)'),
            adminTextField(controller: price, hint: '5,000', keyboardType: TextInputType.text),
            const SizedBox(height: 14),
            adminFieldLabel('Siku'),
            adminTextField(controller: days, hint: '30', keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            adminFieldLabel('Maelezo'),
            adminTextField(controller: note, hint: 'Ufikiaji kamili…'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Maarufu', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: popular,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => popular = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Hai', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: active,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => active = v),
            ),
            const SizedBox(height: 12),
            if (formError != null) adminFormError(formError!),
            adminSaveButton(
              label: isNew ? 'Ongeza' : 'Hifadhi',
              loading: saving,
              onTap: () async {
                final d = int.tryParse(days.text.trim()) ?? plan.days;
                final next = plan.copyWith(
                  name: name.text.trim().isEmpty ? plan.name : name.text.trim(),
                  price: price.text.trim().isEmpty ? plan.price : price.text.trim(),
                  days: d,
                  note: note.text.trim(),
                  popular: popular,
                  active: active,
                );
                if (isNew && next.name.isEmpty) return;
                setLocal(() {
                  saving = true;
                  formError = null;
                });
                final state = context.read<AdminState>();
                try {
                  if (isNew) {
                    await state.addPlan(next);
                  } else {
                    await state.updatePlan(next);
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

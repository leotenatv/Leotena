import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

class CarouselScreen extends StatelessWidget {
  const CarouselScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final slides = state.slides;

    return AdminPage(
      toolbar: [
        Text('${slides.length} slaidi', style: AdminTheme.body(14, color: AdminColors.textSecondary, weight: FontWeight.w700)),
        const Spacer(),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => _openEditor(context, state.newSlideDraft(), isNew: true),
        ),
      ],
      child: slides.isEmpty
          ? Center(child: Text('Hakuna slaidi', style: AdminTheme.body(13, color: AdminColors.textHint)))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: slides.length,
              onReorderItem: (oldIndex, newIndex) =>
                  runWithErrorSnackBar(context, () => context.read<AdminState>().reorderSlide(oldIndex, newIndex)),
              itemBuilder: (_, i) => _SlideTile(
                key: ValueKey(slides[i].id),
                slide: slides[i],
                index: i,
                onEdit: () => _openEditor(context, slides[i], isNew: false),
              ),
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, AdminCarouselSlide slide, {required bool isNew}) async {
    final title = TextEditingController(text: slide.title);
    final thumbnail = TextEditingController(text: slide.imageUrl);
    var saving = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: isNew ? 'Slaidi mpya' : 'Hariri slaidi',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            adminFieldLabel('Jina'),
            adminTextField(controller: title, hint: 'Kivuli cha Mwisho'),
            const SizedBox(height: 14),
            adminFieldLabel('URL ya Picha (Thumbnail)'),
            adminTextField(controller: thumbnail, hint: 'https://image.leotena.com/…jpg'),
            const SizedBox(height: 18),
            if (formError != null) adminFormError(formError!),
            adminSaveButton(
              label: isNew ? 'Ongeza' : 'Hifadhi',
              loading: saving,
              onTap: () async {
                final next = slide.copyWith(
                  title: title.text.trim(),
                  imageUrl: thumbnail.text.trim(),
                );
                if (next.title.isEmpty) return;
                setLocal(() {
                  saving = true;
                  formError = null;
                });
                final state = context.read<AdminState>();
                try {
                  if (isNew) {
                    await state.addSlide(next);
                  } else {
                    await state.updateSlide(next);
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

class _SlideTile extends StatelessWidget {
  final AdminCarouselSlide slide;
  final int index;
  final VoidCallback onEdit;

  const _SlideTile({super.key, required this.slide, required this.index, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final s = slide;

    return AdminListTile(
      dragHandle: ReorderableDragStartListener(
        index: index,
        child: const Icon(Icons.drag_indicator_rounded, color: AdminColors.textHint),
      ),
      leading: _SlideThumb(slide: s),
      title: s.title,
      badges: [
        StatusBadge('#${index + 1}', color: AdminColors.textSecondary),
        if (!s.active) const StatusBadge('Zimwa', color: AdminColors.textHint),
      ],
      actions: [
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
        ),
        Switch(
          value: s.active,
          activeThumbColor: AdminColors.green,
          onChanged: (_) =>
              runWithErrorSnackBar(context, () => context.read<AdminState>().toggleSlideActive(s.id)),
        ),
        DeleteIconButton(
          onDelete: () => deleteWithConfirm(
            context,
            dialogTitle: 'Futa slaidi',
            itemName: s.title,
            onDelete: () => context.read<AdminState>().deleteSlide(s.id),
          ),
        ),
      ],
    );
  }
}

/// Shows the slide thumbnail when set, falling back to a gradient tile with
/// the title's first letter while it loads or if the URL fails.
class _SlideThumb extends StatelessWidget {
  final AdminCarouselSlide slide;
  const _SlideThumb({required this.slide});

  @override
  Widget build(BuildContext context) {
    final s = slide;
    final fallback = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: s.gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        s.title.isNotEmpty ? s.title[0].toUpperCase() : '?',
        style: AdminTheme.body(16, color: Colors.white, weight: FontWeight.w800),
      ),
    );

    if (s.imageUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        s.imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

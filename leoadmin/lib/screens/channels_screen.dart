import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/admin_models.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_widgets.dart';
import '../widgets/confirm_delete.dart';

/// "Vituo" — the single page for every playable channel, whether it's a
/// live TV feed or a movie (movies are just channels with category=movies).
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _categoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final q = state.channelQuery.toLowerCase();
    final all = state.channels;
    final filtered = all.where((c) {
      final matchesQuery = q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);
      final matchesCategory = _categoryFilter == 'all' || c.category == _categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();

    final canReorder = q.isEmpty && _categoryFilter == 'all';

    return AdminPage(
      toolbar: [
        Expanded(child: SearchField(hint: 'Tafuta kituo…', onChanged: state.setChannelQuery)),
        const SizedBox(width: 12),
        AdminPrimaryButton(
          label: 'Ongeza',
          onTap: () => _openEditor(context, state.newChannelDraft(), isNew: true),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CategoryChips(
            selected: _categoryFilter,
            onSelect: (v) => setState(() => _categoryFilter = v),
          ),
          const SizedBox(height: 12),
          if (!canReorder)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Futa utafutaji na uchague "Zote" ili kupanga vituo kwa kubeba',
                style: AdminTheme.body(11, color: AdminColors.textHint),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('Hakuna vituo', style: AdminTheme.body(13, color: AdminColors.textHint)))
                : canReorder
                    ? ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: filtered.length,
                        onReorderItem: (oldIndex, newIndex) => runWithErrorSnackBar(
                            context, () => context.read<AdminState>().reorderChannel(oldIndex, newIndex)),
                        itemBuilder: (_, i) => _ChannelTile(
                          key: ValueKey(filtered[i].id),
                          channel: filtered[i],
                          index: i,
                          draggable: true,
                          onEdit: () => _openEditor(context, filtered[i], isNew: false),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _ChannelTile(
                          key: ValueKey(filtered[i].id),
                          channel: filtered[i],
                          index: i,
                          draggable: false,
                          onEdit: () => _openEditor(context, filtered[i], isNew: false),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, AdminChannel channel, {required bool isNew}) async {
    final name = TextEditingController(text: channel.name);
    final url = TextEditingController(text: channel.url);
    final thumbnail = TextEditingController(text: channel.imageUrl);
    final clearKey = TextEditingController(text: channel.clearKey);
    final genre = TextEditingController(text: channel.genre ?? '');
    final year = TextEditingController(text: channel.year ?? '');
    final rating = TextEditingController(text: channel.rating ?? '');
    final duration = TextEditingController(text: channel.duration ?? '');
    final resolution = TextEditingController(text: channel.resolution ?? '');
    final language = TextEditingController(text: channel.language ?? '');
    final director = TextEditingController(text: channel.director ?? '');
    final description = TextEditingController(text: channel.description ?? '');
    var category = kChannelCategories.contains(channel.category) ? channel.category : 'football';
    var drm = channel.drm;
    var premium = channel.premium;
    var live = channel.live;
    var active = channel.active;
    var saving = false;
    String? formError;

    await showAdminSheet(
      context: context,
      title: isNew ? 'Kituo kipya' : 'Hariri kituo',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isNew) ...[
              Text('ID: ${channel.id}', style: AdminTheme.body(11, color: AdminColors.textHint, weight: FontWeight.w700)),
              const SizedBox(height: 10),
            ],
            adminFieldLabel('Jina'),
            adminTextField(controller: name, hint: 'Pwani Sports'),
            const SizedBox(height: 14),
            adminFieldLabel('Kategoria'),
            DropdownButtonFormField<String>(
              initialValue: category,
              dropdownColor: AdminColors.surfaceLight,
              style: AdminTheme.body(14, color: AdminColors.textPrimary),
              items: kChannelCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(kCategoryLabels[c] ?? c)))
                  .toList(),
              onChanged: (v) => setLocal(() => category = v ?? category),
            ),
            if (category == 'movies') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Aina (Genre)'),
                        adminTextField(controller: genre, hint: 'Vitendo'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Mwaka'),
                        adminTextField(controller: year, hint: '2026', keyboardType: TextInputType.number),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Ukadiriaji'),
                        adminTextField(controller: rating, hint: '8.9'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Muda'),
                        adminTextField(controller: duration, hint: '2h 14m'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Ubora'),
                        adminTextField(controller: resolution, hint: '4K'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        adminFieldLabel('Lugha'),
                        adminTextField(controller: language, hint: 'Kiswahili'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              adminFieldLabel('Mkurugenzi'),
              adminTextField(controller: director, hint: 'N. Mwakalinga'),
              const SizedBox(height: 14),
              adminFieldLabel('Maelezo'),
              adminTextField(controller: description, hint: 'Maelezo mafupi ya filamu…', maxLines: 3),
            ],
            const SizedBox(height: 14),
            adminFieldLabel('URL ya Kituo'),
            adminTextField(controller: url, hint: 'https://stream.leotena.com/live/…m3u8'),
            const SizedBox(height: 14),
            adminFieldLabel('URL ya Picha (Thumbnail)'),
            adminTextField(controller: thumbnail, hint: 'https://image.leotena.com/…jpg'),
            const SizedBox(height: 14),
            adminFieldLabel('DRM'),
            DropdownButtonFormField<ChannelDrm>(
              initialValue: drm,
              dropdownColor: AdminColors.surfaceLight,
              style: AdminTheme.body(14, color: AdminColors.textPrimary),
              items: ChannelDrm.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(kChannelDrmLabels[d] ?? d.name)))
                  .toList(),
              onChanged: (v) => setLocal(() => drm = v ?? drm),
            ),
            if (drm == ChannelDrm.widevine) ...[
              const SizedBox(height: 8),
              Text(
                'Widevine hupata leseni moja kwa moja kutoka kwa URL ya kituo — hakuna haja ya kuweka data zaidi.',
                style: AdminTheme.body(11, color: AdminColors.textHint),
              ),
            ],
            if (drm == ChannelDrm.clearkey) ...[
              const SizedBox(height: 14),
              adminFieldLabel('Funguo ya ClearKey (keyId:key)'),
              adminTextField(controller: clearKey, hint: '9eb4050deb18485bbba2e9358c988e39:6dc75f6d…'),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Malipo', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: premium,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => premium = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('LIVE', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: live,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => live = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Hai', style: AdminTheme.body(14, color: AdminColors.textPrimary)),
              value: active,
              activeThumbColor: AdminColors.green,
              onChanged: (v) => setLocal(() => active = v),
            ),
            if (formError != null) adminFormError(formError!),
            adminSaveButton(
              label: isNew ? 'Ongeza' : 'Hifadhi',
              loading: saving,
              onTap: () async {
                final next = channel.copyWith(
                  name: name.text.trim(),
                  category: category,
                  url: url.text.trim(),
                  imageUrl: thumbnail.text.trim(),
                  drm: drm,
                  clearKey: drm == ChannelDrm.clearkey ? clearKey.text.trim() : '',
                  premium: premium,
                  live: live,
                  active: active,
                  genre: category == 'movies' ? genre.text.trim() : null,
                  year: category == 'movies' ? year.text.trim() : null,
                  rating: category == 'movies' ? rating.text.trim() : null,
                  duration: category == 'movies' ? duration.text.trim() : null,
                  resolution: category == 'movies' ? resolution.text.trim() : null,
                  language: category == 'movies' ? language.text.trim() : null,
                  director: category == 'movies' ? director.text.trim() : null,
                  description: category == 'movies' ? description.text.trim() : null,
                );
                if (next.name.isEmpty) return;
                setLocal(() {
                  saving = true;
                  formError = null;
                });
                final state = context.read<AdminState>();
                try {
                  if (isNew) {
                    await state.addChannel(next);
                  } else {
                    await state.updateChannel(next);
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

class _CategoryChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _CategoryChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final options = ['all', ...kChannelCategories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = options[i];
          final label = v == 'all' ? 'Zote' : (kCategoryLabels[v] ?? v);
          final active = v == selected;
          return ChoiceChip(
            label: Text(label),
            selected: active,
            onSelected: (_) => onSelect(v),
            showCheckmark: false,
            labelStyle: AdminTheme.body(12, color: active ? Colors.white : AdminColors.textSecondary, weight: FontWeight.w700),
            selectedColor: AdminColors.green,
            backgroundColor: AdminColors.surfaceLight.withValues(alpha: 0.45),
            side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
          );
        },
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final AdminChannel channel;
  final int index;
  final bool draggable;
  final VoidCallback onEdit;

  const _ChannelTile({
    super.key,
    required this.channel,
    required this.index,
    required this.draggable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final cat = kCategoryLabels[c.category] ?? c.category;

    return AdminListTile(
      dragHandle: draggable
          ? ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_indicator_rounded, color: AdminColors.textHint),
            )
          : null,
      leading: _ChannelThumb(channel: c),
      title: c.name,
      subtitle: cat,
      badges: [
        StatusBadge('ID ${c.id}', color: AdminColors.textSecondary),
        if (c.live) const StatusBadge('LIVE', color: AdminColors.green),
        StatusBadge(c.premium ? 'MALIPO' : 'BURE', color: c.premium ? AdminColors.warning : AdminColors.info),
        StatusBadge(
          kChannelDrmLabels[c.drm] ?? c.drm.name,
          color: c.drm == ChannelDrm.none ? AdminColors.textHint : AdminColors.info,
        ),
        if (!c.active) const StatusBadge('Zimwa', color: AdminColors.textHint),
      ],
      footer: c.url.isEmpty
          ? null
          : Row(
              children: [
                const Icon(Icons.link_rounded, size: 13, color: AdminColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    c.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdminTheme.body(11, color: AdminColors.textHint),
                  ),
                ),
              ],
            ),
      actions: [
        IconButton(
          tooltip: 'Nakili URL',
          onPressed: c.url.isEmpty
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: c.url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL imenakiliwa'), duration: Duration(seconds: 1)),
                  );
                },
          icon: const Icon(Icons.copy_rounded, color: AdminColors.textSecondary, size: 18),
        ),
        IconButton(
          tooltip: 'Hariri',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, color: AdminColors.textSecondary, size: 20),
        ),
        DeleteIconButton(
          onDelete: () => deleteWithConfirm(
            context,
            dialogTitle: 'Futa kituo',
            itemName: c.name,
            onDelete: () => context.read<AdminState>().deleteChannel(c.id),
          ),
        ),
      ],
    );
  }
}

/// Channel avatar: shows the thumbnail image when set, falling back to a
/// gradient tile with the channel's initials (also used while it loads or
/// if the URL fails to load).
class _ChannelThumb extends StatelessWidget {
  final AdminChannel channel;
  const _ChannelThumb({required this.channel});

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final fallback = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: c.gradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(c.initials, style: AdminTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
    );

    if (c.imageUrl.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        c.imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}

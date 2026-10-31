import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/account_status_bar.dart';
import '../widgets/app_backdrop.dart';
import '../widgets/channel_art.dart';
import 'desktop_payment.dart';
import 'desktop_player.dart';
import 'desktop_shimmer.dart';
import 'desktop_window.dart';
import 'tv_layout.dart';

bool desktopCatalogWaiting(AppState state) =>
    state.channels.isEmpty &&
    (state.loadingContent || state.contentError != null);

const _categories = <(String, IconData, String)>[
  ('zote', Icons.grid_view_rounded, 'Zote'),
  ('movies', Icons.movie_rounded, 'Movies'),
  ('tamthilia', Icons.theater_comedy_rounded, 'Tamthilia'),
  ('football', Icons.sports_soccer_rounded, 'Football'),
  ('wanyama', Icons.pets_rounded, 'Wanyama'),
  ('katuni', Icons.animation_rounded, 'Katuni'),
  ('burudani', Icons.celebration_rounded, 'Burudani'),
];

/// Home is a channel wall, then a watch layout with the list on the left
/// and the player on the right. Phones never build this. Windows and
/// television do.
class DesktopShell extends StatefulWidget {
  const DesktopShell({super.key});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  final _focus = FocusNode();
  bool _watching = false;
  bool _fullscreen = false;
  Timer? _catalogRetry;

  @override
  void initState() {
    super.initState();
    _catalogRetry = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (!desktopCatalogWaiting(state) || state.loadingContent) return;
      state.refreshContent();
    });
  }

  @override
  void dispose() {
    _catalogRetry?.cancel();
    DesktopWindow.setFullScreen(false);
    _focus.dispose();
    super.dispose();
  }

  DateTime get _eatNow => DateTime.now().toUtc().add(const Duration(hours: 3));

  String get _greeting {
    final hour = _eatNow.hour;
    if (hour >= 5 && hour < 12) return 'Habari za asubuhi';
    if (hour >= 12 && hour < 16) return 'Habari za mchana';
    if (hour >= 16 && hour < 19) return 'Habari za jioni';
    return 'Habari za usiku';
  }

  Future<void> _setFullscreen(bool enabled) async {
    if (_fullscreen == enabled) return;
    setState(() => _fullscreen = enabled);
    if (TvLayout.active) {
      await SystemChrome.setEnabledSystemUIMode(
        enabled ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
      return;
    }
    await DesktopWindow.setFullScreen(enabled);
  }

  Future<void> _goHome() async {
    final wasFullscreen = _fullscreen;
    setState(() {
      _fullscreen = false;
      _watching = false;
    });
    if (!mounted) return;
    context.read<AppState>().stop();
    if (wasFullscreen) await DesktopWindow.setFullScreen(false);
  }

  Future<void> _openChannel(Channel channel) async {
    final state = context.read<AppState>();
    if (state.channelLocked(channel)) {
      final paid = await DesktopPayment.show(context);
      if (!mounted || !paid) return;
      if (context.read<AppState>().channelLocked(channel)) return;
    }
    if (!mounted) return;
    context.read<AppState>().play(PlaybackSource.fromChannel(channel));
    setState(() => _watching = true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _typing()) {
      FocusManager.instance.primaryFocus?.unfocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      _setFullscreen(!_fullscreen);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_fullscreen) {
        _setFullscreen(false);
        return KeyEventResult.handled;
      }
      if (_watching) {
        _goHome();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _typing() {
    final current = FocusManager.instance.primaryFocus?.context;
    if (current == null) return false;
    return current.widget is EditableText ||
        current.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_watching && !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_fullscreen) {
          _setFullscreen(false);
          return;
        }
        if (_watching) _goHome();
      },
      child: Focus(
      focusNode: _focus,
      autofocus: !TvLayout.active,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: AppBackdrop.fill(
          child: Column(
            children: [
              if (!_fullscreen) const AccountStatusBar(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _watching
                      ? _WatchLayout(
                          key: const ValueKey('watch'),
                          fullscreen: _fullscreen,
                          onBack: _goHome,
                          onToggleFullscreen: () => _setFullscreen(!_fullscreen),
                          onOpen: _openChannel,
                        )
                      : _HomeBrowse(
                          key: const ValueKey('home'),
                          greeting: _greeting,
                          onOpen: _openChannel,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _HomeBrowse extends StatefulWidget {
  final String greeting;
  final ValueChanged<Channel> onOpen;

  const _HomeBrowse({
    super.key,
    required this.greeting,
    required this.onOpen,
  });

  @override
  State<_HomeBrowse> createState() => _HomeBrowseState();
}

class _HomeBrowseState extends State<_HomeBrowse> {
  final _searchCtrl = TextEditingController();
  String _category = 'zote';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Channel> _visible(List<Channel> channels) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return channels.where((channel) {
      if (_category != 'zote' && channel.category != _category) return false;
      if (query.isEmpty) return true;
      return channel.name.toLowerCase().contains(query) ||
          channel.program.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _pay() => DesktopPayment.show(context);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final channels = _visible(state.channels);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeBar(
          greeting: widget.greeting,
          subscribed: state.subscribed,
          searchCtrl: _searchCtrl,
          onSearch: () => setState(() {}),
          onPay: _pay,
          onRefresh: () => state.refreshContent(),
        ),
        const SizedBox(height: 8),
        _CategoryStrip(
          selected: _category,
          onSelect: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: desktopCatalogWaiting(state)
              ? const DesktopChannelGridShimmer()
              : channels.isEmpty
                  ? _EmptyChannels(
                      message: 'Hakuna chaneli',
                      onRefresh: () => state.refreshContent(),
                    )
                  : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 225,
                    mainAxisExtent: 258,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: channels.length,
                  itemBuilder: (_, index) {
                    final channel = channels[index];
                    final locked = state.channelLocked(channel);
                    return _ChannelCard(
                      channel: channel,
                      locked: locked,
                      autofocus: index == 0,
                      onTap: () => widget.onOpen(channel),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _HomeBar extends StatelessWidget {
  final String greeting;
  final bool subscribed;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch;
  final VoidCallback onPay;
  final VoidCallback onRefresh;

  const _HomeBar({
    required this.greeting,
    required this.subscribed,
    required this.searchCtrl,
    required this.onSearch,
    required this.onPay,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/branding/app_icon.png',
                width: 46, height: 46, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leotena', style: AppTheme.heading(22)),
                const SizedBox(height: 2),
                Text(greeting,
                    style: AppTheme.body(13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: _SearchField(controller: searchCtrl, onChanged: onSearch),
            ),
          ),
          const SizedBox(width: 12),
          _IconTool(
              tooltip: 'Refresh',
              icon: Icons.refresh_rounded,
              onTap: onRefresh),
          if (!subscribed) ...[
            const SizedBox(width: 12),
            _PayButton(onTap: onPay),
          ],
        ],
      ),
    );
  }
}

class _WatchLayout extends StatefulWidget {
  final bool fullscreen;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final ValueChanged<Channel> onOpen;

  const _WatchLayout({
    super.key,
    required this.fullscreen,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onOpen,
  });

  @override
  State<_WatchLayout> createState() => _WatchLayoutState();
}

class _WatchLayoutState extends State<_WatchLayout> {
  final _searchCtrl = TextEditingController();
  final _playingKey = GlobalKey();
  String _category = 'zote';

  String? _revealedId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _revealPlaying() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _playingKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(target,
          alignment: 0.3, duration: const Duration(milliseconds: 240));
    });
  }

  List<Channel> _visible(List<Channel> channels) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return channels.where((channel) {
      if (_category != 'zote' && channel.category != _category) return false;
      if (query.isEmpty) return true;
      return channel.name.toLowerCase().contains(query) ||
          channel.program.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final source = state.nowPlaying;
    final channels = _visible(state.channels);
    if (state.nowChannelId != _revealedId) {
      _revealedId = state.nowChannelId;
      _revealPlaying();
    }

    return Row(
      children: [
        if (!widget.fullscreen)
          SizedBox(
            width: 340,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                border:
                    const Border(right: BorderSide(color: Color(0xFFD7E8F6))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/branding/app_icon.png',
                              width: 34, height: 34, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text('Vituo', style: AppTheme.heading(18))),
                        Text(
                          '${channels.length}',
                          style: AppTheme.body(13,
                              color: AppColors.textHint,
                              weight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CategoryStrip(
                    selected: _category,
                    dense: true,
                    onSelect: (value) => setState(() => _category = value),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: desktopCatalogWaiting(state)
                        ? const DesktopRailShimmer()
                        : channels.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Hakuna chaneli',
                                    textAlign: TextAlign.center,
                                    style: AppTheme.body(13,
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              )
                            : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                            itemCount: channels.length,
                            itemBuilder: (_, index) {
                              final channel = channels[index];
                              final selected = state.nowChannelId == channel.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _RailTile(
                                  key: selected
                                      ? _playingKey
                                      : ValueKey(channel.id),
                                  channel: channel,
                                  selected: selected,
                                  locked: state.channelLocked(channel),
                                  autofocus: index == 0,
                                  onTap: () => widget.onOpen(channel),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: source == null
              ? const ColoredBox(
                  color: Color(0xFF07111F),
                  child: Center(
                    child: Text(
                      'Chagua kituo kuanza kutazama',
                      style: TextStyle(
                          color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              : DesktopPlayerPane(
                  source: source,
                  fullscreen: widget.fullscreen,
                  onBack: widget.onBack,
                  onToggleFullscreen: widget.onToggleFullscreen,
                ),
        ),
      ],
    );
  }
}

class _ChannelCard extends StatefulWidget {
  final Channel channel;
  final bool locked;
  final bool autofocus;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.locked,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: _Pressable(
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        child: AnimatedScale(
          scale: _hover ? 1.025 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.shadow(
                  blur: _hover ? 28 : 18,
                  y: _hover ? 14 : 8,
                  opacity: _hover ? 0.22 : 0.14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ChannelVisual(channel: channel),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xE60F2748)],
                        stops: [0.42, 1],
                      ),
                    ),
                  ),
                  if (widget.locked)
                    ColoredBox(
                        color: const Color(0xFF0F2748).withValues(alpha: 0.28)),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.program,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(11, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          channel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.body(15,
                              color: Colors.white, weight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child:
                        widget.locked ? const _LockChip() : const _FreeChip(),
                  ),
                  if (_hover)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(
                              BorderSide(color: AppColors.green, width: 2.4)),
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailTile extends StatefulWidget {
  final Channel channel;
  final bool selected;
  final bool locked;
  final bool autofocus;
  final VoidCallback onTap;

  const _RailTile({
    super.key,
    required this.channel,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final selected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: _Pressable(
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.green.withValues(alpha: 0.12)
                : _hover
                    ? AppColors.section
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.green : Colors.transparent,
                width: 1.6),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 46,
                  child: _ChannelVisual(channel: channel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(13.5,
                          color: AppColors.textPrimary,
                          weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.program,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(11, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              if (widget.locked)
                const Icon(Icons.lock_rounded,
                    size: 16, color: AppColors.navyMid)
              else if (selected)
                const Icon(Icons.equalizer_rounded,
                    size: 16, color: AppColors.greenDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelVisual extends StatelessWidget {
  final Channel channel;
  const _ChannelVisual({required this.channel});

  @override
  Widget build(BuildContext context) {
    if (channel.imageUrl.trim().isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: channel.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(channel.logo,
              style: AppTheme.body(16,
                  color: Colors.white, weight: FontWeight.w800)),
        ),
      );
    }
    return ChannelArt(channel: channel, fit: BoxFit.cover);
  }
}

class _CategoryStrip extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final bool dense;

  const _CategoryStrip({
    required this.selected,
    required this.onSelect,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 28),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = _categories[index];
          final on = item.$1 == selected;
          return _Pressable(
            onTap: () => onSelect(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: on ? AppColors.navy : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    on ? null : AppColors.shadow(blur: 12, y: 4, opacity: 0.08),
              ),
              child: Row(
                children: [
                  Icon(item.$2,
                      size: 15,
                      color: on ? AppColors.green : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    item.$3,
                    style: AppTheme.body(12.5,
                        color: on ? Colors.white : AppColors.textPrimary,
                        weight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: AppTheme.body(13.5,
          color: AppColors.textPrimary, weight: FontWeight.w700),
      cursorColor: AppColors.navy,
      decoration: InputDecoration(
        hintText: 'Tafuta chaneli',
        hintStyle: AppTheme.body(13, color: AppColors.textHint),
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textHint, size: 20),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD6E8F6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(14),
            boxShadow: AppColors.greenGlow(),
          ),
          child: Text('Lipa TSh 5,000',
              style: AppTheme.body(13.5,
                  color: Colors.white, weight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _Pressable extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool autofocus;

  const _Pressable({
    required this.onTap,
    required this.child,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!TvLayout.active) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return InkWell(
      onTap: onTap,
      autofocus: autofocus,
      canRequestFocus: true,
      borderRadius: BorderRadius.circular(16),
      focusColor: AppColors.green.withValues(alpha: 0.18),
      child: child,
    );
  }
}

class _IconTool extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _IconTool(
      {required this.tooltip, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: AppColors.navyMid, size: 20)),
        ),
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  const _LockChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 12, color: AppColors.navy),
          const SizedBox(width: 4),
          Text('Malipo',
              style: AppTheme.body(10.5,
                  color: AppColors.navy, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FreeChip extends StatelessWidget {
  const _FreeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.green, borderRadius: BorderRadius.circular(20)),
      child: Text('Bure',
          style: AppTheme.body(10.5,
              color: Colors.white, weight: FontWeight.w800)),
    );
  }
}

class _EmptyChannels extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;

  const _EmptyChannels({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.live_tv_rounded, color: AppColors.navyMid, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: AppTheme.body(14, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRefresh,
            child: Text('Refresh',
                style: AppTheme.body(14,
                    color: AppColors.greenDark, weight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

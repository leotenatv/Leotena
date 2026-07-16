import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/cards.dart';
import '../widgets/channel_art.dart';
import 'player_screen.dart';
import 'search_screen.dart';
import '../widgets/premium_lock_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pageCtrl = PageController();
  int _banner = 0;
  String _selectedCategory = 'zote';

  static const _categories = <(String, IconData, String)>[
    ('zote', Icons.grid_view_rounded, 'Zote'),
    ('movies', Icons.movie_rounded, 'Movies'),
    ('tamthilia', Icons.theater_comedy_rounded, 'Tamthilia'),
    ('football', Icons.sports_soccer_rounded, 'Football'),
    ('wanyama', Icons.pets_rounded, 'Wanyama'),
    ('katuni', Icons.animation_rounded, 'Katuni'),
    ('burudani', Icons.celebration_rounded, 'Burudani'),
  ];

  @override
  void initState() {
    super.initState();
    _autoSlide();
  }

  void _autoSlide() {
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      final next = (_banner + 1) % context.read<AppState>().banners.length;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      _autoSlide();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _requireSubscriptionOr(VoidCallback play) {
    if (!context.read<AppState>().subscribed) {
      PremiumLockModal.show(context);
      return;
    }
    play();
  }

  /// Chaneli za Bure — free content, always playable.
  void _playMovie(Movie m) {
    context.read<AppState>().play(PlaybackSource.fromMovie(m));
    PlayerScreen.open(context);
  }

  /// Category rows (Movies, Tamthilia, …) — premium; payment if not subscribed, else play now.
  void _openPremiumMovie(Movie m) {
    _requireSubscriptionOr(() => _playMovie(m));
  }

  void _openChannel(Channel c) {
    final state = context.read<AppState>();
    if (state.channelLocked(c)) {
      PremiumLockModal.show(context);
      return;
    }
    state.play(PlaybackSource.fromChannel(c));
    PlayerScreen.open(context);
  }

  bool _show(String key) => _selectedCategory == 'zote' || _selectedCategory == key;

  List<Channel> _channelsBy(String key) =>
      context.read<AppState>().channels.where((c) => c.category == key).toList();

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: ListView(
          padding: EdgeInsets.only(top: r.topContent, bottom: r.bottomNavClearance),
          children: [
            _header(r),
            SizedBox(height: r.sectionGap),
            _carousel(r),
            SizedBox(height: r.sectionGap),
            _chips(r),
            SizedBox(height: r.sectionGap),
            if (_show('zote') && _selectedCategory == 'zote') ...[
              SectionHeader('Chaneli za Bure', onAction: () {}),
              _continueRow(r),
              SizedBox(height: r.sectionGap),
            ],
            if (_show('football')) _channelWideRow(r, 'Football', _channelsBy('football')),
            if (_show('tamthilia')) _posterRow(r, 'Tamthilia', context.watch<AppState>().comedy),
            if (_show('movies')) _posterRow(r, 'Movies', context.watch<AppState>().newlyAdded),
            if (_show('burudani')) _channelWideRow(r, 'Burudani', _channelsBy('burudani')),
            if (_show('wanyama')) _channelPosterRow(r, 'Wanyama', _channelsBy('wanyama')),
            if (_show('katuni')) _channelPosterRow(r, 'Katuni', _channelsBy('katuni')),
          ],
        ),
      ),
    );
  }

  Widget _header(R r) {
    final avatar = r.headerAvatar;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Habari za asubuhi 👋',
                    style: AppTheme.body(r.sp(13), color: AppColors.textHint, weight: FontWeight.w700)),
                Consumer<AppState>(
                  builder: (_, s, __) => Text('Karibu, ${s.userName}', style: AppTheme.heading(r.sp(22))),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => SearchScreen.open(context),
            child: Container(
              width: avatar,
              height: avatar,
              decoration: BoxDecoration(
                color: AppColors.section,
                borderRadius: BorderRadius.circular(15),
                boxShadow: AppColors.shadow(blur: 18, y: 8, opacity: 0.25),
              ),
              child: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: r.sp(22)),
            ),
          ),
          SizedBox(width: r.sp(12)),
          Container(
            width: avatar,
            height: avatar,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navyMid, AppColors.navy]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Consumer<AppState>(
              builder: (_, s, __) =>
                  Text(s.userInitial, style: AppTheme.body(r.sp(15), color: Colors.white, weight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carousel(R r) {
    final banners = context.watch<AppState>().banners;
    return Column(
      children: [
        SizedBox(
          height: r.carouselHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.pageGutter - 2),
            child: PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _banner = i),
              itemCount: banners.length,
              itemBuilder: (_, i) => _bannerCard(r, banners[i]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) {
            final active = i == _banner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 22 : 6,
              decoration: BoxDecoration(
                color: active ? AppColors.green : const Color(0xFFC9DEF0),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _bannerCard(R r, Movie m) {
    final radius = r.sp(26);
    return GestureDetector(
      onTap: () => _playMovie(m),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MovieArt(movie: m, borderRadius: BorderRadius.circular(radius), fit: BoxFit.fill),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [const Color(0xFF0F2748).withValues(alpha: 0.82), Colors.transparent],
                  stops: const [0.08, 0.6],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(r.sp(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('🔥 Zinazovuma sasa',
                        style: AppTheme.body(r.sp(11), color: Colors.white, weight: FontWeight.w700)),
                  ),
                  SizedBox(height: r.sp(8)),
                  Text(m.title, style: AppTheme.heading(r.sp(r.isCompact ? 20 : 25), color: Colors.white)),
                  SizedBox(height: r.sp(6)),
                  Text(
                    '⭐ ${m.rating}',
                    style: AppTheme.body(r.sp(12), color: Colors.white.withValues(alpha: 0.85), weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(R r) {
    return SizedBox(
      height: r.chipHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final item = _categories[i];
          final active = _selectedCategory == item.$1;
          final color = active ? Colors.white : AppColors.textSecondary;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = item.$1),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.sp(14)),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.navy : AppColors.section,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.shadow(blur: 16, y: 8, opacity: 0.20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$2, size: r.sp(16), color: color),
                  const SizedBox(width: 6),
                  Text(item.$3, style: AppTheme.body(r.sp(12.5), color: color, weight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _continueRow(R r) {
    final items = context.watch<AppState>().continueWatching;
    const progs = [0.62, 0.28, 0.85];
    return SizedBox(
      height: r.continueRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: r.sp(14)),
        itemBuilder: (_, i) =>
            ContinueCard(movie: items[i], progress: progs[i], onTap: () => _playMovie(items[i])),
      ),
    );
  }

  Widget _posterRow(R r, String title, List<Movie> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.sectionGap),
        SectionHeader(title, onAction: () {}),
        SizedBox(
          height: r.posterRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: r.sp(14)),
            itemBuilder: (_, i) => MoviePosterCard(movie: items[i], onTap: () => _openPremiumMovie(items[i])),
          ),
        ),
      ],
    );
  }

  /// Same card size/style as Chaneli za Bure.
  Widget _channelWideRow(R r, String title, List<Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.sectionGap),
        SectionHeader(title, onAction: () {}),
        SizedBox(
          height: r.continueRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: r.sp(14)),
            itemBuilder: (_, i) => ChannelWideCard(channel: items[i], onTap: () => _openChannel(items[i])),
          ),
        ),
      ],
    );
  }

  /// Same portrait poster layout as Movies / Tamthilia.
  Widget _channelPosterRow(R r, String title, List<Channel> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.sectionGap),
        SectionHeader(title, onAction: () {}),
        SizedBox(
          height: r.posterRowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: r.sp(14)),
            itemBuilder: (_, i) => ChannelPosterCard(channel: items[i], onTap: () => _openChannel(items[i])),
          ),
        ),
      ],
    );
  }
}

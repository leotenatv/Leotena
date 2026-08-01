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
      final banners = context.read<AppState>().banners;
      if (banners.isEmpty) {
        _autoSlide();
        return;
      }
      final next = (_banner + 1) % banners.length;
      _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
      _autoSlide();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Tanzania (EAT = UTC+3) wall-clock time for greetings.
  DateTime get _eatNow {
    final utc = DateTime.now().toUtc();
    return utc.add(const Duration(hours: 3));
  }

  String get _tanzaniaGreeting {
    final h = _eatNow.hour;
    if (h >= 5 && h < 12) return 'Habari za asubuhi';
    if (h >= 12 && h < 16) return 'Habari za mchana';
    if (h >= 16 && h < 19) return 'Habari za jioni';
    return 'Habari za usiku';
  }

  void _playMovie(Movie m) {
    context.read<AppState>().play(PlaybackSource.fromMovie(m));
    PlayerScreen.open(context);
  }

  void _openMovie(Movie m) {
    final state = context.read<AppState>();
    if (state.movieLocked(m)) {
      PremiumLockModal.show(context);
      return;
    }
    _playMovie(m);
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
    final freeChannels = context.watch<AppState>().freeChannels;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () => context.read<AppState>().refreshContent(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: r.topContent, bottom: r.bottomNavClearance),
            children: [
              _header(r),
              SizedBox(height: r.sectionGap),
              _carousel(r),
              SizedBox(height: r.sectionGap),
              _chips(r),
              SizedBox(height: r.sectionGap),
              if (_show('zote') && _selectedCategory == 'zote' && freeChannels.isNotEmpty) ...[
                SectionHeader('Chaneli za Bure', onAction: () {}),
                _freeChannelsRow(r, freeChannels),
                SizedBox(height: r.sectionGap),
              ],
              if (_show('football')) _channelWideRow(r, 'Football', _channelsBy('football')),
              if (_show('tamthilia')) ...[
                _channelWideRow(r, 'Tamthilia', _channelsBy('tamthilia')),
                _posterRow(r, 'Tamthilia', context.watch<AppState>().moviesByCategory('tamthilia')),
              ],
              if (_show('movies')) _posterRow(r, 'Movies', context.watch<AppState>().moviesByCategory('movies')),
              if (_show('burudani')) ...[
                _channelWideRow(r, 'Burudani', _channelsBy('burudani')),
                _posterRow(r, 'Burudani', context.watch<AppState>().moviesByCategory('burudani')),
              ],
              if (_show('wanyama')) ...[
                _channelPosterRow(r, 'Wanyama', _channelsBy('wanyama')),
                _posterRow(r, 'Wanyama', context.watch<AppState>().moviesByCategory('wanyama')),
              ],
              if (_show('katuni')) ...[
                _channelPosterRow(r, 'Katuni', _channelsBy('katuni')),
                _posterRow(r, 'Katuni', context.watch<AppState>().moviesByCategory('katuni')),
              ],
            ],
          ),
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
            child: Text(
              '$_tanzaniaGreeting 👋',
              style: AppTheme.heading(r.sp(22)),
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
    if (banners.isEmpty) return const SizedBox.shrink();
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

  void _openBanner(CarouselBanner banner) {
    final movie = context.read<AppState>().movieForBanner(banner);
    if (movie != null) {
      _openMovie(movie);
      return;
    }
  }

  Widget _bannerCard(R r, CarouselBanner banner) {
    final radius = r.sp(26);
    return GestureDetector(
      onTap: () => _openBanner(banner),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterArt(
              imageUrl: banner.imageUrl,
              gradient: banner.gradient,
              borderRadius: BorderRadius.circular(radius),
              fit: BoxFit.fill,
            ),
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
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  banner.title,
                  style: AppTheme.heading(r.sp(r.isCompact ? 20 : 25), color: Colors.white),
                ),
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

  Widget _freeChannelsRow(R r, List<Channel> items) {
    return SizedBox(
      height: r.continueRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.pageGutter),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: r.sp(14)),
        itemBuilder: (_, i) => ChannelWideCard(channel: items[i], onTap: () => _openChannel(items[i])),
      ),
    );
  }

  Widget _posterRow(R r, String title, List<Movie> items) {
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
            itemBuilder: (_, i) => MoviePosterCard(movie: items[i], onTap: () => _openMovie(items[i])),
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

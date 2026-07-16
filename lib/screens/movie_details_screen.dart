import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/channel_art.dart';
import 'player_screen.dart';
import '../widgets/premium_lock_modal.dart';

class MovieDetailsScreen extends StatelessWidget {
  final Movie movie;
  const MovieDetailsScreen({super.key, required this.movie});

  void _play(BuildContext context) {
    final state = context.read<AppState>();
    if (movie.premium && !state.subscribed) {
      PremiumLockModal.show(context);
      return;
    }
    state.play(PlaybackSource.fromMovie(movie));
    PlayerScreen.open(context);
  }

  @override
  Widget build(BuildContext context) {
    final related = context.watch<AppState>().related(movie.id);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // Backdrop hero.
          SizedBox(
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MovieArt(movie: movie, height: 400),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0.4), Colors.transparent], stops: const [0.02, 0.28, 0.6]),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _glassBtn(Icons.chevron_left_rounded, () => Navigator.of(context).maybePop()),
                        Row(children: [
                          Consumer<AppState>(
                            builder: (_, s, __) => _glassBtn(
                              s.isFavorite(movie.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              () => context.read<AppState>().toggleFavorite(movie.id),
                              color: s.isFavorite(movie.id) ? Colors.redAccent : AppColors.navy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _glassBtn(Icons.ios_share_rounded, () {}),
                        ]),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 22, right: 22, bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (movie.premium) const Padding(padding: EdgeInsets.only(bottom: 10), child: GreenBadge('MALIPO')),
                      Text(movie.title, style: AppTheme.heading(30)),
                      const SizedBox(height: 9),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _meta('⭐ ${movie.rating}', bg: AppColors.green.withValues(alpha: 0.13), fg: AppColors.greenDark),
                        _meta(movie.year), _meta(movie.duration), _meta(movie.resolution),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: PrimaryButton(label: 'Tazama Sasa', icon: Icons.play_arrow_rounded, onTap: () => _play(context))),
                  const SizedBox(width: 12),
                  Container(
                    width: 54, height: 54,
                    decoration: BoxDecoration(color: AppColors.section, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.shadow(blur: 20, y: 10, opacity: 0.25)),
                    child: const Icon(Icons.download_rounded, color: AppColors.textSecondary),
                  ),
                ]),
                const SizedBox(height: 16),
                Wrap(spacing: 9, runSpacing: 9, children: movie.genres.map((g) => _meta(g, bg: AppColors.bgSoft, fg: AppColors.navyMid)).toList()),
                const SizedBox(height: 16),
                Text(movie.description, style: AppTheme.body(13.5).copyWith(height: 1.65)),
                const SizedBox(height: 18),
                Row(children: [
                  _fact('Mkurugenzi', movie.director),
                  const SizedBox(width: 22),
                  _fact('Lugha', movie.language),
                  const SizedBox(width: 22),
                  _fact('Mwaka', movie.year),
                ]),
                const SizedBox(height: 24),
                Text('Inayohusiana', style: AppTheme.heading(16)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 228,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 13),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MovieDetailsScreen(movie: related[i]))),
                      child: SizedBox(
                        width: 132,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: MovieArt(movie: related[i], width: 132, height: 188),
                          ),
                          const SizedBox(height: 8),
                          Text(related[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(12.5, color: AppColors.textPrimary, weight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, {Color color = AppColors.navy}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(14), boxShadow: AppColors.shadow(blur: 18, y: 8, opacity: 0.3)),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _meta(String text, {Color bg = AppColors.bgSoft, Color fg = AppColors.textSecondary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Text(text, style: AppTheme.body(11, color: fg, weight: FontWeight.w700)),
    );
  }

  Widget _fact(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(11, color: AppColors.textHint, weight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, style: AppTheme.body(13.5, color: AppColors.textPrimary, weight: FontWeight.w700)),
      ],
    );
  }
}

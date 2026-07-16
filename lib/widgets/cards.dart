import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'common.dart';
import 'channel_art.dart';

/// Vertical poster card used in horizontal home rows.
class MoviePosterCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;
  final double? width;
  const MoviePosterCard({super.key, required this.movie, required this.onTap, this.width});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final w = width ?? r.posterWidth;
    final posterHeight = w * 1.45;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(r.sp(20)),
              child: SizedBox(
                width: w,
                height: posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MovieArt(
                      movie: movie,
                      width: w,
                      height: posterHeight,
                      borderRadius: BorderRadius.circular(r.sp(20)),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [const Color(0xFF0F2748).withOpacity(0.55), Colors.transparent],
                          stops: const [0, 0.55],
                        ),
                      ),
                    ),
                    if (movie.premium)
                      const Positioned(top: 10, left: 10, child: GreenBadge('MALIPO')),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('⭐ ${movie.rating}',
                            style: AppTheme.body(r.sp(11), color: Colors.white, weight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              movie.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(r.sp(14), color: AppColors.textPrimary, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wide "continue watching" card with a green progress bar.
class ContinueCard extends StatelessWidget {
  final Movie movie;
  final double progress; // 0..1
  final VoidCallback onTap;
  const ContinueCard({super.key, required this.movie, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final w = r.continueCardWidth;
    final h = r.continueRowHeight - 10;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.sp(22)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MovieArt(movie: movie, width: w, height: h),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [const Color(0xFF0F2748).withOpacity(0.72), Colors.transparent],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: r.sp(38),
                  height: r.sp(38),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: r.sp(24)),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(r.sp(14.5), color: Colors.white, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation(AppColors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide landscape channel card — same proportions as Chaneli za Bure.
class ChannelWideCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  const ChannelWideCard({super.key, required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final w = r.continueCardWidth;
    final h = r.continueRowHeight - 10;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.sp(22)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ChannelArt(channel: channel, width: w, height: h),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [const Color(0xFF0F2748).withOpacity(0.72), Colors.transparent],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: GreenBadge(channel.premium ? 'MALIPO' : 'BURE'),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: r.sp(38),
                  height: r.sp(38),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: r.sp(24)),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(r.sp(14.5), color: Colors.white, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.program,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(r.sp(12), color: Colors.white.withOpacity(0.78), weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portrait channel poster — same layout as Movies / Tamthilia.
class ChannelPosterCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  const ChannelPosterCard({super.key, required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final w = r.posterWidth;
    final posterHeight = w * 1.45;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(r.sp(20)),
              child: SizedBox(
                width: w,
                height: posterHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ChannelArt(
                      channel: channel,
                      width: w,
                      height: posterHeight,
                      borderRadius: BorderRadius.circular(r.sp(20)),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [const Color(0xFF0F2748).withOpacity(0.55), Colors.transparent],
                          stops: const [0, 0.55],
                        ),
                      ),
                    ),
                    if (channel.premium)
                      const Positioned(top: 10, left: 10, child: GreenBadge('MALIPO')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(r.sp(14), color: AppColors.textPrimary, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tall channel card with title overlay — used for Burudani rails.
class ChannelMiniCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  const ChannelMiniCard({super.key, required this.channel, required this.onTap, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final cardWidth = width ?? r.channelCardWidth;
    final cardHeight = height ?? r.channelCardHeight;
    return SizedBox(
      width: cardWidth,
      height: cardHeight,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.sp(22)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ChannelArt(
                channel: channel,
                width: cardWidth,
                height: cardHeight,
                borderRadius: BorderRadius.circular(22),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF0F2748).withOpacity(0.88),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.55],
                  ),
                ),
              ),
              const Positioned(
                top: 12,
                left: 12,
                child: GreenBadge('● LIVE'),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GreenBadge(channel.premium ? 'MALIPO' : 'BURE'),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(15, color: Colors.white, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.program,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(12, color: Colors.white.withOpacity(0.78), weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

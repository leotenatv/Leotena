import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Network poster/thumbnail with gradient fallback.
class PosterArt extends StatelessWidget {
  final String imageUrl;
  final List<Color> gradient;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final Widget? fallbackChild;

  const PosterArt({
    super.key,
    required this.imageUrl,
    required this.gradient,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
    this.fallbackChild,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 350),
          placeholder: (_, __) => _fallback(showLoader: true),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }

  Widget _fallback({bool showLoader = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54),
              )
            : fallbackChild,
      ),
    );
  }
}

/// Network-backed channel artwork with gradient fallback.
class ChannelArt extends StatelessWidget {
  final Channel channel;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const ChannelArt({
    super.key,
    required this.channel,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.fill,
  });

  @override
  Widget build(BuildContext context) {
    return PosterArt(
      imageUrl: channel.imageUrl,
      gradient: channel.gradient,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: fit,
      fallbackChild: Text(
        channel.logo,
        style: AppTheme.body(18, color: Colors.white, weight: FontWeight.w800),
      ),
    );
  }
}

/// Movie poster artwork.
class MovieArt extends StatelessWidget {
  final Movie movie;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const MovieArt({
    super.key,
    required this.movie,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return PosterArt(
      imageUrl: movie.imageUrl,
      gradient: movie.gradient,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fit: fit,
      fallbackChild: Icon(Icons.movie_rounded, color: Colors.white.withOpacity(0.7), size: 36),
    );
  }
}

/// Full-bleed backdrop for the player surface.
class MediaBackdrop extends StatelessWidget {
  final String? imageUrl;
  final List<Color> gradient;

  const MediaBackdrop({
    super.key,
    required this.imageUrl,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 400),
          placeholder: (_, __) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
          errorWidget: (_, __, ___) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.12),
                Colors.black.withOpacity(0.42),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

@Deprecated('Use MediaBackdrop')
typedef ChannelBackdrop = MediaBackdrop;

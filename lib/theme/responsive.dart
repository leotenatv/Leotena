import 'package:flutter/material.dart';

/// App-wide responsive metrics derived from the current media query.
///
/// Baseline design width is 390 (common phone). Scale clamps keep layouts
/// readable on tiny phones and comfortable on tablets / large phones.
class R {
  R._(this.size, this.padding, this.viewInsets, this.viewPadding);

  final Size size;
  final EdgeInsets padding;
  final EdgeInsets viewInsets;
  final EdgeInsets viewPadding;

  factory R.of(BuildContext context) {
    final mq = MediaQuery.of(context);
    return R._(mq.size, mq.padding, mq.viewInsets, mq.viewPadding);
  }

  double get width => size.width;
  double get height => size.height;
  double get shortest => size.shortestSide;

  bool get isCompact => width < 360;
  bool get isPhone => width < 600;
  bool get isTablet => width >= 600;
  bool get isLarge => width >= 900;

  /// Typography / spacing scale vs 390-wide baseline.
  double get scale {
    final raw = width / 390.0;
    if (isCompact) return raw.clamp(0.82, 0.95);
    if (isTablet) return raw.clamp(1.0, 1.22);
    return raw.clamp(0.92, 1.12);
  }

  double sp(double value) => value * scale;
  double dp(double value) => value * scale;

  double get pageGutter => isCompact ? 14.0 : (isTablet ? 28.0 : 20.0);
  double get sectionGap => isCompact ? 14.0 : 18.0;
  /// Extra top spacing under the status bar. Status inset is handled by RootShell.
  double get topContent => isCompact ? 6.0 : 8.0;
  double get bottomNavClearance => 100.0 + viewPadding.bottom;

  double get maxContentWidth {
    if (isLarge) return 860;
    if (isTablet) return 720;
    return double.infinity;
  }

  double get carouselHeight {
    final h = height * (isTablet ? 0.44 : (isCompact ? 0.46 : 0.48));
    return h.clamp(isCompact ? 280.0 : 320.0, isTablet ? 520.0 : 440.0);
  }

  double get continueRowHeight => isCompact ? 148.0 : (isTablet ? 180.0 : 168.0);
  double get continueCardWidth => isCompact ? 240.0 : (isTablet ? 310.0 : 280.0);

  double get posterWidth => isCompact ? 138.0 : (isTablet ? 188.0 : 168.0);
  double get posterRowHeight => posterWidth * 1.45 + 42;

  double get channelCardWidth => isCompact ? 200.0 : (isTablet ? 260.0 : 240.0);
  double get channelCardHeight => channelCardWidth * 1.25;
  double get channelRowHeight => channelCardHeight + 8;

  double get chipHeight => isCompact ? 36.0 : 40.0;
  double get headerAvatar => isCompact ? 40.0 : 44.0;

  double get modalCardMaxH {
    final kb = viewInsets.bottom;
    final avail = height - kb - padding.top - 96;
    if (kb > 40) return avail.clamp(240.0, 520.0);
    return (height * (isTablet ? 0.58 : 0.62)).clamp(380.0, isTablet ? 620.0 : 560.0);
  }

  double get modalViewport => isTablet ? 0.55 : (isCompact ? 0.86 : 0.78);
}

/// Centers page content on large screens and applies horizontal gutters.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final ScrollPhysics? physics;

  const ResponsivePage({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.maxContentWidth),
        child: Padding(
          padding: padding ?? EdgeInsets.symmetric(horizontal: r.pageGutter),
          child: child,
        ),
      ),
    );
    if (!scrollable) return content;
    return SingleChildScrollView(physics: physics, child: content);
  }
}

/// Clamps system text scaling so huge accessibility scales don't explode layouts.
MediaQueryData clampTextScale(MediaQueryData data) {
  final scale = data.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25);
  return data.copyWith(textScaler: scale);
}

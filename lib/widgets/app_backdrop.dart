import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft sky / ice backdrop with gentle shine — matches navy text + green accents.
///
/// Brand stays light (never black). Layer behind scroll content; keep cards white.
class AppBackdrop extends StatelessWidget {
  final Widget? child;

  const AppBackdrop({super.key, this.child});

  /// Full-screen stack: painted atmosphere + [child] on top.
  static Widget fill({Key? key, required Widget child}) {
    return Stack(
      key: key,
      fit: StackFit.expand,
      children: [
        const AppBackdrop(),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.bgHighlight,
                  AppColors.bg,
                  AppColors.bgSoft,
                  AppColors.bg,
                ],
                stops: [0.0, 0.32, 0.72, 1.0],
              ),
            ),
          ),
          // Soft top shine (sky light)
          Positioned(
            top: -size.height * 0.12,
            left: -size.width * 0.15,
            child: _ShineOrb(
              diameter: size.width * 1.15,
              colors: [
                AppColors.shine.withValues(alpha: 0.95),
                AppColors.bgHighlight.withValues(alpha: 0.35),
                Colors.transparent,
              ],
            ),
          ),
          // Cool navy mist (depth, matches text)
          Positioned(
            top: size.height * 0.18,
            right: -size.width * 0.35,
            child: _ShineOrb(
              diameter: size.width * 0.95,
              colors: [
                AppColors.navyMid.withValues(alpha: 0.06),
                AppColors.bgSoft.withValues(alpha: 0.4),
                Colors.transparent,
              ],
            ),
          ),
          // Subtle green glow near bottom (brand accent, not neon)
          Positioned(
            bottom: -size.height * 0.08,
            left: -size.width * 0.2,
            child: _ShineOrb(
              diameter: size.width * 0.9,
              colors: [
                AppColors.green.withValues(alpha: 0.07),
                AppColors.bgSoft.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ),
          ),
          // Fine top-edge sheen for status / header area
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _ShineOrb extends StatelessWidget {
  final double diameter;
  final List<Color> colors;

  const _ShineOrb({required this.diameter, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: colors,
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

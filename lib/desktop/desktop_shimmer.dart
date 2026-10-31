import 'package:flutter/material.dart';

/// Sliding highlight used for every desktop loading state.
class DesktopShimmer extends StatefulWidget {
  final Widget child;
  final bool dark;

  const DesktopShimmer({super.key, required this.child, this.dark = false});

  @override
  State<DesktopShimmer> createState() => _DesktopShimmerState();
}

class _DesktopShimmerState extends State<DesktopShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.dark ? const Color(0xFF12263F) : const Color(0xFFD7E8F5);
    final shine = widget.dark ? const Color(0xFF1E3D63) : const Color(0xFFF5FBFF);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, child) {
        final dx = -1.2 + (_sweep.value * 2.4);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(dx - 0.6, -0.2),
              end: Alignment(dx + 0.6, 0.2),
              colors: [base, shine, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(rect);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBone extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final bool dark;

  const ShimmerBone({
    super.key,
    this.width,
    this.height,
    this.radius = 16,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF16304C) : const Color(0xFFD7E8F5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Channel-wall placeholder. Stays up while the catalog cannot load.
class DesktopChannelGridShimmer extends StatelessWidget {
  const DesktopChannelGridShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopShimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 225,
          mainAxisExtent: 258,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => const ShimmerBone(radius: 22),
      ),
    );
  }
}

/// Left-hand channel list placeholder.
class DesktopRailShimmer extends StatelessWidget {
  const DesktopRailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const ShimmerBone(height: 62, radius: 16),
      ),
    );
  }
}

/// Full player surface while a stream is still opening.
class DesktopPlayerShimmer extends StatelessWidget {
  const DesktopPlayerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF07111F),
      child: DesktopShimmer(
        dark: true,
        child: SizedBox.expand(
          child: ColoredBox(color: Color(0xFF10243C)),
        ),
      ),
    );
  }
}

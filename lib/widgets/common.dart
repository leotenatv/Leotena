import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';

/// Floating, soft-shadowed rounded card — the core surface of the app.
class FloatingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const FloatingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = AppRadii.card,
    this.color = AppColors.card,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppColors.shadow(),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return _PressableScale(onTap: onTap!, child: card);
  }
}

/// Scales slightly on press — used to make every tappable card feel alive.
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Green pill badge (Premium / Malipo / LIVE etc).
class GreenBadge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;
  const GreenBadge(
    this.text, {
    super.key,
    this.color = AppColors.green,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 3),
          ],
          Text(text, style: AppTheme.body(9.5, color: textColor, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Premium channel badge: MALIPO until paid, then Imelipiwa with verified tick.
class PremiumChannelBadge extends StatelessWidget {
  const PremiumChannelBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final paid = context.watch<AppState>().subscribed;
    if (paid) {
      return const GreenBadge('Imelipiwa', icon: Icons.verified_rounded);
    }
    return const GreenBadge('MALIPO');
  }
}

/// Channel access badge: BURE for free, MALIPO / Imelipiwa for premium.
class ChannelAccessBadge extends StatelessWidget {
  final bool premium;
  const ChannelAccessBadge({super.key, required this.premium});

  @override
  Widget build(BuildContext context) {
    if (!premium) return const GreenBadge('BURE');
    return const PremiumChannelBadge();
  }
}

/// Section header: bold title + "Zote" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.leading, this.onAction});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Expanded(child: Text(title, style: AppTheme.heading(r.sp(18)))),
          GestureDetector(
            onTap: onAction,
            child: Text('Zote', style: AppTheme.body(r.sp(12.5), color: AppColors.green, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// A small pulsing dot used for LIVE indicators.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, this.color = AppColors.green, this.size = 8});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_c),
      child: ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.15).animate(_c),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// Animated audio equalizer (3 bars) for the "now playing" channel.
class Equalizer extends StatefulWidget {
  final Color color;
  final double height;
  const Equalizer({super.key, this.color = AppColors.green, this.height = 16});
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with TickerProviderStateMixin {
  late final List<AnimationController> _cs = List.generate(
    3,
    (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true)
      ..value = i * 0.25,
  );
  @override
  void dispose() {
    for (final c in _cs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.2),
          child: AnimatedBuilder(
            animation: _cs[i],
            builder: (_, __) => Container(
              width: 3,
              height: widget.height * (0.35 + 0.65 * _cs[i].value),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        );
      }),
    );
  }
}

/// Filled green button used across the app.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.greenGlow(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
            Text(label, style: AppTheme.body(15, color: Colors.white, weight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

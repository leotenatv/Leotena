import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'root_shell.dart';

/// Animated splash: scaling logo, pulsing dots, fade to Home. Also where the
/// app first talks to the backend — content and device registration load
/// here before navigating in, since there's no more static fallback data.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _logo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Deferred to a microtask: _boot() calls setState()/AppState methods
    // that notifyListeners() before their first await, and initState() runs
    // synchronously during the very first build — doing that mid-build throws.
    Future.microtask(() {
      if (mounted) _boot();
    });
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    final state = context.read<AppState>();
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 2400));
    await Future.wait([state.bootstrap(), state.ensureDeviceRegistered(), minDelay]);
    if (!mounted) return;
    if (state.contentError != null) {
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const RootShell()),
    ));
  }

  @override
  void dispose() {
    _logo.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgSoft, AppColors.bg, AppColors.bgSoft],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(parent: _logo, curve: Curves.easeOutBack),
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, -7 * _float.value),
                    child: child,
                  ),
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyMid]),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: AppColors.shadow(blur: 50, y: 26, opacity: 0.5),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.play_arrow_rounded, color: AppColors.green, size: 56),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FadeTransition(
                opacity: _logo,
                child: Text('Leotena', style: AppTheme.heading(30)),
              ),
              if (_failed) ...[
                const SizedBox(height: 28),
                Text(
                  'Imeshindwa kuunganisha na seva',
                  style: AppTheme.body(13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _boot,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Jaribu tena', style: AppTheme.body(14, color: Colors.white, weight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

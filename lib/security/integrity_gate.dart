import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'client_integrity.dart';

/// Holds the first screen until the device is clear of sniffers and proxies.
class IntegrityGate extends StatefulWidget {
  final Widget child;
  const IntegrityGate({super.key, required this.child});

  @override
  State<IntegrityGate> createState() => _IntegrityGateState();
}

class _IntegrityGateState extends State<IntegrityGate> with WidgetsBindingObserver {
  bool? _blocked;
  Timer? _recheck;
  bool _busy = false;

  bool get _widgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (_widgetTest) {
      _blocked = false;
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _check();
    _recheck = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    _recheck?.cancel();
    if (!_widgetTest) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final blocked = await clientIntegrityBlocked();
      if (!mounted) return;
      setState(() => _blocked = blocked);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked == null) {
      return const ColoredBox(color: AppColors.bg);
    }
    if (_blocked == true) {
      return _IntegrityBlock(onRetry: _check);
    }
    return widget.child;
  }
}

class _IntegrityBlock extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _IntegrityBlock({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: AppColors.shadow(blur: 24, y: 12, opacity: 0.16),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Leotena imezuiwa',
                      textAlign: TextAlign.center,
                      style: AppTheme.heading(26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      integrityBlockMessage,
                      textAlign: TextAlign.center,
                      style: AppTheme.body(15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 26),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onRetry,
                      child: Text(
                        'Jaribu tena',
                        style: AppTheme.body(15, color: Colors.white, weight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

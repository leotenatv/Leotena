import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import 'home_screen.dart';
import 'ratiba_screen.dart';
import 'mtumiaji_screen.dart';

/// Hosts the 3 main tabs with a floating, animated bottom navigation bar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _tabs = [
    _TabDef(Icons.home_outlined, Icons.home_rounded, 'Nyumbani'),
    _TabDef(Icons.calendar_today_outlined, Icons.calendar_month_rounded, 'Ratiba'),
    _TabDef(Icons.person_outline_rounded, Icons.person_rounded, 'Mtumiaji'),
  ];

  final _pages = const [HomeScreen(), RatibaScreen(), MtumiajiScreen()];

  @override
  Widget build(BuildContext context) {
    final statusTop = MediaQuery.viewPaddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBody: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.only(top: statusTop),
                child: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(_index), child: _pages[_index]),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _FloatingNav(
                        index: _index,
                        tabs: _tabs,
                        onTap: (i) => setState(() => _index = i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: statusTop,
              child: const ColoredBox(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef(this.icon, this.activeIcon, this.label);
}

class _FloatingNav extends StatelessWidget {
  final int index;
  final List<_TabDef> tabs;
  final ValueChanged<int> onTap;
  const _FloatingNav({required this.index, required this.tabs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final barH = r.isCompact ? 64.0 : 70.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.pageGutter, 0, r.pageGutter, bottom + (r.isCompact ? 10 : 14)),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: r.isTablet ? 420 : 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: barH,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD6E8F6), width: 1.2),
                  boxShadow: [
                    ...AppColors.shadow(blur: 28, y: 14, opacity: 0.18),
                    BoxShadow(
                      color: AppColors.navy.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slot = constraints.maxWidth / tabs.length;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          left: slot * index,
                          top: 0,
                          bottom: 0,
                          width: slot,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [AppColors.navy, AppColors.navyMid],
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.navy.withOpacity(0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(tabs.length, (i) {
                            final active = i == index;
                            return Expanded(
                              child: _NavItem(
                                tab: tabs[i],
                                active: active,
                                onTap: () => onTap(i),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _TabDef tab;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.tab, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = R.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: AppColors.green.withOpacity(0.12),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: r.sp(4)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  active ? tab.activeIcon : tab.icon,
                  size: r.sp(22),
                  color: active ? Colors.white : Colors.black,
                ),
              ),
              SizedBox(height: r.sp(3)),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                style: AppTheme.body(
                  r.sp(active ? 11.5 : 10.5),
                  color: active ? Colors.white : Colors.black,
                  weight: active ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(height: r.sp(2)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                height: 3,
                width: active ? 14 : 0,
                decoration: BoxDecoration(
                  color: active ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/admin_repository.dart';
import '../state/admin_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_sidebar.dart';
import 'analytics_screen.dart';
import 'channels_screen.dart';
import 'carousel_screen.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'ratiba_screen.dart';
import 'settings_screen.dart';
import 'subscriptions_screen.dart';
import 'pricing_screen.dart';
import 'users_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  Widget _screen(String id) {
    switch (id) {
      case 'users':
        return const UsersScreen();
      case 'carousel':
        return const CarouselScreen();
      case 'channels':
        return const ChannelsScreen();
      case 'ratiba':
        return const RatibaScreen();
      case 'pricing':
        return const PricingScreen();
      case 'subscriptions':
        return const SubscriptionsScreen();
      case 'notifications':
        return const NotificationsScreen();
      case 'analytics':
        return const AnalyticsScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminState>();
    final meta = state.sectionMeta(AdminRepository.navItems);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: AdminColors.bg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: AdminColors.surface,
              child: AdminSidebar(
                activeId: state.section,
                onSelect: (id) {
                  state.setSection(id);
                  Navigator.pop(context);
                },
                onLogout: () {
                  Navigator.pop(context);
                  state.logout();
                },
              ),
            ),
      body: Row(
        children: [
          if (wide)
            AdminSidebar(
              activeId: state.section,
              onSelect: state.setSection,
              onLogout: state.logout,
            ),
          Expanded(
            child: Builder(
              builder: (innerContext) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminHeader(
                  title: meta?.label ?? 'Dashibodi',
                  onMenu: wide ? null : () => Scaffold.of(innerContext).openDrawer(),
                ),
                Expanded(child: _screen(state.section)),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/admin_models.dart';

/// Navigation only — content/stats come from the API via [AdminState].
class AdminRepository {
  static const navItems = [
    AdminNavItem('dashboard', 'Dashibodi', Icons.dashboard_rounded),
    AdminNavItem('users', 'Watumiaji', Icons.people_rounded),
    AdminNavItem('carousel', 'Slaidi', Icons.view_carousel_rounded),
    AdminNavItem('channels', 'Vituo', Icons.live_tv_rounded),
    AdminNavItem('ratiba', 'Ratiba', Icons.schedule_rounded),
    AdminNavItem('pricing', 'Bei', Icons.sell_rounded),
    AdminNavItem('subscriptions', 'Malipo', Icons.payments_rounded),
    AdminNavItem('notifications', 'Arifa', Icons.notifications_rounded),
    AdminNavItem('analytics', 'Takwimu', Icons.bar_chart_rounded),
    AdminNavItem('settings', 'Mipangilio', Icons.settings_rounded),
  ];
}

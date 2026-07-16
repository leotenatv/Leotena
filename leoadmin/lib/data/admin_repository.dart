import 'package:flutter/material.dart';
import '../models/admin_models.dart';
import '../theme/admin_theme.dart';

class AdminRepository {
  static const stats = DashboardStats(
    totalUsers: 45829,
    premiumUsers: 12450,
    revenueTzs: 'TZS 284.5M',
    adRevenueTzs: 'TZS 89.2M',
    userGrowthPct: 12.5,
    premiumGrowthPct: 8.3,
    revenueGrowthPct: 15.8,
  );

  static const weeklyUsers = [4200.0, 5100.0, 5800.0, 6200.0, 7100.0, 7800.0, 8400.0];

  static const navItems = [
    AdminNavItem('dashboard', 'Dashibodi', Icons.dashboard_rounded),
    AdminNavItem('users', 'Watumiaji', Icons.people_rounded),
    AdminNavItem('carousel', 'Slaidi', Icons.view_carousel_rounded),
    AdminNavItem('channels', 'Vituo', Icons.live_tv_rounded),
    AdminNavItem('ratiba', 'Ratiba', Icons.schedule_rounded),
    AdminNavItem('pricing', 'Bei', Icons.sell_rounded),
    AdminNavItem('subscriptions', 'Malipo', Icons.payments_rounded),
    AdminNavItem('analytics', 'Takwimu', Icons.bar_chart_rounded),
    AdminNavItem('settings', 'Mipangilio', Icons.settings_rounded),
  ];

  static const activities = [
    ActivityItem(title: 'Malipo ya Premium', subtitle: 'Amani Joseph — Mwezi 1', time: 'Dakika 2', color: AdminColors.green),
    ActivityItem(title: 'Filamu Mpya', subtitle: 'Moto wa Usiku', time: 'Dakika 15', color: AdminColors.info),
    ActivityItem(title: 'Kituo LIVE', subtitle: 'Pwani Sports', time: 'Saa 1', color: AdminColors.warning),
    ActivityItem(title: 'Mtumiaji Mpya', subtitle: 'Grace Kimaro', time: 'Saa 3', color: AdminColors.navyMid),
  ];

  static const topContent = [
    TopContentItem(title: 'Simba vs Yanga', subtitle: 'Football', views: '145.2K', growthPct: 25, icon: Icons.sports_soccer, gradient: [Color(0xFF0A7D4A), Color(0xFF19B26B)]),
    TopContentItem(title: 'Kivuli cha Mwisho', subtitle: 'Movies', views: '98.7K', growthPct: 18, icon: Icons.movie_rounded, gradient: [Color(0xFF0F2748), Color(0xFF3A86C9)]),
    TopContentItem(title: 'Simba wa Serengeti', subtitle: 'Wanyama', views: '87.3K', growthPct: 32, icon: Icons.pets_rounded, gradient: [Color(0xFF1D4A82), Color(0xFF19B26B)]),
    TopContentItem(title: 'Habari za Jioni', subtitle: 'Burudani', views: '76.8K', growthPct: 15, icon: Icons.live_tv_rounded, gradient: [Color(0xFF143A6B), Color(0xFF2C6DB5)]),
  ];
}

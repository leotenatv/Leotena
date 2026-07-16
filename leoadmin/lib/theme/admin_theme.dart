import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  static const bg = Color(0xFF06122A);
  static const surface = Color(0xFF0F2748);
  static const surfaceLight = Color(0xFF143A6B);
  static const border = Color(0xFF1D4A82);
  static const green = Color(0xFF19B26B);
  static const greenDark = Color(0xFF0A7D4A);
  static const navyMid = Color(0xFF1D4A82);
  static const textPrimary = Color(0xFFF4FAFF);
  static const textSecondary = Color(0xFF8FB4D6);
  static const textHint = Color(0xFF3A5573);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF3B82F6);
}

class AdminTheme {
  static ThemeData dark() {
    final base = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AdminColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.green,
        secondary: AdminColors.navyMid,
        surface: AdminColors.surface,
      ),
      useMaterial3: true,
      dividerColor: AdminColors.border.withValues(alpha: 0.4),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: AdminColors.surface, elevation: 0),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AdminColors.border.withValues(alpha: 0.35)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surfaceLight.withValues(alpha: 0.45),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        hintStyle: GoogleFonts.plusJakartaSans(color: AdminColors.textHint, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AdminColors.textPrimary,
        displayColor: AdminColors.textPrimary,
      ),
    );
  }

  static TextStyle heading(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? AdminColors.textPrimary, letterSpacing: -0.3);

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? AdminColors.textSecondary);
}

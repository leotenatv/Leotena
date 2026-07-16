import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design language for Leotena.
///
/// Palette rules (per brand):
/// - Backgrounds: white / very-soft light blue. Never black.
/// - Text: dark navy / medium navy / soft-blue hint.
/// - Accent (buttons, success, progress, premium badge): green.
/// - Every card carries a soft dark-navy shadow with large rounded corners.
class AppColors {
  static const Color bg = Color(0xFFFFFFFF); // primary background
  static const Color bgSoft = Color(0xFFEAF6FF); // secondary background
  static const Color section = Color(0xFFF4FAFF); // very soft section
  static const Color card = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F2748); // dark navy
  static const Color textSecondary = Color(0xFF3A5573); // medium navy
  static const Color textHint = Color(0xFF8FB4D6); // soft blue

  static const Color green = Color(0xFF19B26B); // accent / success / progress
  static const Color greenDark = Color(0xFF0A7D4A);

  static const Color navyDeep = Color(0xFF06122A);
  static const Color navy = Color(0xFF0F2748);
  static const Color navyMid = Color(0xFF1D4A82);

  /// Soft dark-navy elevation shadow used on every floating card.
  static List<BoxShadow> shadow({double blur = 30, double y = 16, double opacity = 0.22}) => [
        BoxShadow(
          color: const Color(0xFF0F2748).withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
          spreadRadius: -blur * 0.5,
        ),
      ];

  static List<BoxShadow> greenGlow() => [
        BoxShadow(
          color: green.withValues(alpha: 0.5),
          blurRadius: 24,
          offset: const Offset(0, 12),
          spreadRadius: -8,
        ),
      ];
}

class AppRadii {
  static const double card = 20;
  static const double cardLg = 26;
  static const double pill = 16;
  static const double sheet = 28;
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyMid,
        primary: AppColors.navy,
        secondary: AppColors.green,
        background: AppColors.bg,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Heading font (Sora) helper.
  static TextStyle heading(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.sora(fontSize: size, fontWeight: weight, color: color ?? AppColors.textPrimary, letterSpacing: -0.4);

  static TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color ?? AppColors.textSecondary);
}

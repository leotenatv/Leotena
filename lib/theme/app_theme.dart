import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design language for Leotena.
///
/// Palette rules (per brand):
/// - Backgrounds: soft ice / sky mist with gentle shine. Never black.
/// - Text: dark navy / medium navy / soft-blue hint.
/// - Accent (buttons, success, progress, premium badge): green.
/// - Every card carries a soft dark-navy shadow with large rounded corners.
class AppColors {
  static const Color bg = Color(0xFFF3F9FF); // soft ice primary
  static const Color bgHighlight = Color(0xFFFAFDFF); // near-white shine
  static const Color bgSoft = Color(0xFFDCEEF9); // cool sky wash
  static const Color section = Color(0xFFEAF4FC); // frosted chips / tiles
  static const Color card = Color(0xFFFFFFFF);
  static const Color shine = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F2748); // dark navy
  static const Color textSecondary = Color(0xFF3A5573); // medium navy
  static const Color textHint = Color(0xFF8FB4D6); // soft blue

  static const Color green = Color(0xFF19B26B); // accent / success / progress
  static const Color greenDark = Color(0xFF0A7D4A);

  static const Color navyDeep = Color(0xFF06122A);
  static const Color navy = Color(0xFF0F2748);
  static const Color navyMid = Color(0xFF1D4A82);

  /// Soft dark-navy elevation shadow used on every floating card.
  static List<BoxShadow> shadow({double blur = 30, double y = 16, double opacity = 0.18}) => [
        BoxShadow(
          color: const Color(0xFF0F2748).withValues(alpha: opacity),
          blurRadius: blur,
          offset: Offset(0, y),
          spreadRadius: -blur * 0.5,
        ),
      ];

  static List<BoxShadow> greenGlow() => [
        BoxShadow(
          color: green.withValues(alpha: 0.45),
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
        surface: AppColors.bg,
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

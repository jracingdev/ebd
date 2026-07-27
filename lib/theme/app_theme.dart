import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta recuperada do protótipo JSX / screenshots do APK.
class AppColors {
  static const cream = Color(0xFFF7F2E7);
  static const ink = Color(0xFF2B2318);
  static const green = Color(0xFF2F5D50);
  static const gold = Color(0xFFB8892B);
  static const muted = Color(0xFF8B8378);
  static const danger = Color(0xFF9B2C2C);
  static const brown = Color(0xFF4A3728);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.green,
        secondary: AppColors.gold,
        surface: AppColors.cream,
        brightness: Brightness.light,
      ),
    );
    return base.copyWith(
      textTheme: GoogleFonts.libreCaslonTextTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      primaryTextTheme:
          GoogleFonts.libreCaslonTextTextTheme(base.primaryTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.brown,
        backgroundColor: Colors.white,
        labelStyle: const TextStyle(color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

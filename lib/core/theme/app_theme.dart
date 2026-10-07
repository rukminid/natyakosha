import 'package:flutter/material.dart';

/// Palette inspired by temple silk and gold: maroon, gold, ivory.
class AppColors {
  AppColors._();

  static const maroon = Color(0xFF7B1E3A);
  static const gold = Color(0xFFC9A227);
  static const ivory = Color(0xFFFBF6EE);
  static const ink = Color(0xFF2B1B17);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFC62828);
  static const info = Color(0xFF1565C0);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon,
      primary: AppColors.maroon,
      secondary: AppColors.gold,
      surface: AppColors.ivory,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ivory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.maroon,
      brightness: Brightness.dark,
      secondary: AppColors.gold,
    );
    return ThemeData(colorScheme: scheme);
  }

  /// Shared text-field look; used by form widgets instead of a theme so it
  /// stays stable across Flutter versions.
  static InputDecoration input(String label, {String? hint, Widget? prefixIcon, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: prefixIcon,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}

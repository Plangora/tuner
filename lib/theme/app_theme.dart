import 'package:flutter/material.dart';

/// Cyberpunk color palette and theme for the Tuner app.
///
/// A dark, neon aesthetic: near-black backgrounds with glowing
/// cyan/magenta/purple accents.
class AppColors {
  AppColors._();

  static const background = Color(0xFF08060F);
  static const surface = Color(0xFF120C1E);

  static const cyan = Color(0xFF00F5FF);
  static const magenta = Color(0xFFFF2CDF);
  static const purple = Color(0xFF9D4EDD);

  /// In tune.
  static const success = Color(0xFF39FF14);

  /// Flat (below target pitch).
  static const flat = cyan;

  /// Sharp (above target pitch).
  static const sharp = magenta;

  static const error = Color(0xFFFF3860);

  static const trackInactive = Color(0xFF2A2438);
}

class AppTheme {
  AppTheme._();

  /// Adds a soft neon glow behind a widget using layered shadows.
  static List<BoxShadow> glow(Color color, {double blurRadius = 24}) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: blurRadius),
      BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: blurRadius * 2),
    ];
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      brightness: Brightness.dark,
      primary: AppColors.cyan,
      secondary: AppColors.magenta,
      tertiary: AppColors.purple,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.cyan,
        centerTitle: true,
        elevation: 0,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.cyan,
          side: const BorderSide(color: AppColors.cyan, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Design tokens — the single source of truth for spacing, radii, and the
/// brand palette. Keeps every screen visually consistent.
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
}

/// Brand palette. A warm orange accent on clean neutrals (RestroBit style).
class AppColors {
  AppColors._();

  static const brand = Color(0xFFF97316); // orange 500
  static const brandDark = Color(0xFFEA580C); // orange 600
  static const brandLight = Color(0xFFFB923C); // orange 400
  static const accent = Color(0xFF10B981); // emerald 500 (secondary actions)

  // Semantic
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // Light neutrals
  static const lightBg = Color(0xFFF5F6FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE6E8F0);
  static const lightText = Color(0xFF0F172A);
  static const lightMuted = Color(0xFF64748B);

  // Dark neutrals
  static const darkBg = Color(0xFF0E1320);
  static const darkSurface = Color(0xFF161D2E);
  static const darkElevated = Color(0xFF1C2438);
  static const darkBorder = Color(0xFF283048);
  static const darkText = Color(0xFFF1F5F9);
  static const darkMuted = Color(0xFF94A3B8);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
  );
}

/// Convenience accessors for theme-aware custom colors (border, muted text)
/// that aren't part of the standard [ColorScheme].
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get borderColor =>
      isDark ? AppColors.darkBorder : AppColors.lightBorder;
  Color get mutedColor => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

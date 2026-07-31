import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// App theming. A cohesive, modern SaaS look — soft neutral canvas, crisp
/// bordered cards (not heavy shadows), rounded fields, and a consistent
/// indigo accent. Both light and dark are hand-tuned.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFEDD5),
      onPrimaryContainer: Color(0xFF7C2D12),
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD1FAE5),
      onSecondaryContainer: Color(0xFF064E3B),
      tertiary: AppColors.warning,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFEF3C7),
      onTertiaryContainer: Color(0xFF78350F),
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      surfaceContainerHighest: Color(0xFFEEF0F6),
      onSurfaceVariant: AppColors.lightMuted,
      outline: AppColors.lightBorder,
      outlineVariant: Color(0xFFEDEEF4),
    );
    return _build(scheme, AppColors.lightBg);
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.brandLight,
      onPrimary: Color(0xFF431407),
      primaryContainer: Color(0xFF7C2D12),
      onPrimaryContainer: Color(0xFFFFEDD5),
      secondary: AppColors.accent,
      onSecondary: Color(0xFF022C22),
      secondaryContainer: Color(0xFF064E3B),
      onSecondaryContainer: Color(0xFFD1FAE5),
      tertiary: Color(0xFFFBBF24),
      onTertiary: Color(0xFF3A2A05),
      tertiaryContainer: Color(0xFF5B3D0A),
      onTertiaryContainer: Color(0xFFFEF3C7),
      error: Color(0xFFF87171),
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFEE2E2),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.darkElevated,
      onSurfaceVariant: AppColors.darkMuted,
      outline: AppColors.darkBorder,
      outlineVariant: Color(0xFF222A40),
    );
    return _build(scheme, AppColors.darkBg);
  }

  static ThemeData _build(ColorScheme scheme, Color canvas) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : const Color(0xFFF3F4F9),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: scheme.onSurfaceVariant,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.field,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkElevated : const Color(0xFFEFF1F7),
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.lightText,
        contentTextStyle: TextStyle(
            color: isDark ? AppColors.darkText : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.field),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    TextStyle h(double size, FontWeight w, {double spacing = -0.3}) => TextStyle(
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          color: scheme.onSurface,
          height: 1.2,
        );
    return base.copyWith(
      headlineMedium: h(28, FontWeight.w800),
      headlineSmall: h(23, FontWeight.w700),
      titleLarge: h(19, FontWeight.w700),
      titleMedium: h(16, FontWeight.w600, spacing: -0.1),
      titleSmall: h(14, FontWeight.w600, spacing: 0),
      bodyLarge: TextStyle(fontSize: 15, color: scheme.onSurface, height: 1.4),
      bodyMedium: TextStyle(fontSize: 14, color: scheme.onSurface, height: 1.4),
      bodySmall: TextStyle(
          fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.35),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }
}

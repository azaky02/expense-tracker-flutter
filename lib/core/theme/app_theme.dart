import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        colorScheme: const ColorScheme.light(
          primary: AppColors.navy800,
          onPrimary: AppColors.white,
          secondary: AppColors.teal600,
          onSecondary: AppColors.white,
          tertiary: AppColors.orange600,
          surface: AppColors.white,
          onSurface: AppColors.grey900,
          surfaceContainerHighest: AppColors.grey100,
          error: AppColors.red500,
          onError: AppColors.white,
          outline: AppColors.grey200,
        ),
        scaffoldBackground: AppColors.grey50,
        extension: AppSemanticColors.light,
      );

  static ThemeData get dark => _build(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.navy700,
          onPrimary: AppColors.white,
          secondary: AppColors.teal500,
          onSecondary: AppColors.white,
          tertiary: AppColors.orange600,
          surface: AppColors.grey800,
          onSurface: AppColors.grey50,
          surfaceContainerHighest: AppColors.grey700,
          error: AppColors.red500,
          onError: AppColors.white,
          outline: AppColors.grey700,
        ),
        scaffoldBackground: AppColors.grey900,
        extension: AppSemanticColors.dark,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required AppSemanticColors extension,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [extension],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: extension.chip,
        selectedColor: extension.chipSelected,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: extension.chipSelectedText),
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.secondary,
        unselectedItemColor: AppColors.grey400,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

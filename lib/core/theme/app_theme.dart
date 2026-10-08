import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_semantic_colors.dart';
import 'ds_tokens.dart';

/// Light and dark themes with the same identity (UI/UX Master Document §3).
/// Arabic text uses Cairo; amounts use Inter through `AmountText`.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: DS.primary,
          onPrimary: Colors.white,
          primaryContainer: DS.primarySoft,
          onPrimaryContainer: DS.navy,
          secondary: DS.success,
          onSecondary: Colors.white,
          tertiary: DS.warning,
          onTertiary: Colors.white,
          error: DS.danger,
          onError: Colors.white,
          surface: DS.surface,
          onSurface: DS.text,
          onSurfaceVariant: DS.textMuted,
          surfaceContainerHighest: DS.surfaceAlt,
          surfaceContainerHigh: DS.surfaceAlt,
          surfaceContainer: DS.surface,
          outline: DS.border,
          outlineVariant: DS.border,
        ),
        background: DS.background,
        semantic: AppSemanticColors.light,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: DS.primaryDark,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFF1B2C55),
          onPrimaryContainer: DS.textDark,
          secondary: Color(0xFF22C55E),
          onSecondary: Colors.white,
          tertiary: DS.warning,
          onTertiary: Colors.black,
          error: Color(0xFFF87171),
          onError: Colors.black,
          surface: DS.surfaceDark,
          onSurface: DS.textDark,
          onSurfaceVariant: DS.textMutedDark,
          surfaceContainerHighest: DS.surfaceAltDark,
          surfaceContainerHigh: DS.surfaceAltDark,
          surfaceContainer: DS.surfaceDark,
          outline: DS.borderDark,
          outlineVariant: DS.borderDark,
        ),
        background: DS.backgroundDark,
        semantic: AppSemanticColors.dark,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required AppSemanticColors semantic,
  }) {
    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
    final text = GoogleFonts.cairoTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radius));
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radius),
          side: BorderSide(color: scheme.outline.withValues(alpha: brightness == Brightness.dark ? 1 : 0.6)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, space: 1),
      listTileTheme: ListTileThemeData(shape: rounded),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.chip,
        selectedColor: semantic.chipSelected,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: semantic.chipSelectedText),
        checkmarkColor: semantic.chipSelectedText,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: rounded,
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
          shape: rounded,
          textStyle: text.titleSmall,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary, textStyle: text.labelLarge),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          backgroundColor: scheme.surface,
          side: BorderSide(color: scheme.outline),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radius), borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radius), borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(DS.radius), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const CircleBorder(),
        elevation: 4,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(color: scheme.surface, elevation: 8, shadowColor: Colors.black26),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusLg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.radiusLg)),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: rounded),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, linearTrackColor: scheme.surfaceContainerHighest),
    );
  }
}

import 'package:flutter/material.dart';

import 'ds_tokens.dart';

/// Tokens that don't fit ColorScheme's built-in slots: chart palette, per-card-brand
/// color rotation, and income/expense semantic colors. Read via
/// `Theme.of(context).extension<AppSemanticColors>()!`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.expense,
    required this.income,
    required this.cash,
    required this.chip,
    required this.chipSelected,
    required this.chipSelectedText,
    required this.warningSurface,
    required this.dangerSurface,
    required this.chartPalette,
    required this.cardColorRotation,
  });

  final Color expense;
  final Color income;
  final Color cash;
  final Color chip;
  final Color chipSelected;
  final Color chipSelectedText;
  final Color warningSurface;
  final Color dangerSurface;
  final List<Color> chartPalette;
  final List<Color> cardColorRotation;

  static const light = AppSemanticColors(
    expense: DS.danger,
    income: DS.success,
    cash: DS.navy,
    chip: DS.surfaceAlt,
    chipSelected: DS.primary,
    chipSelectedText: Colors.white,
    warningSurface: DS.warningSoft,
    dangerSurface: DS.dangerSoft,
    chartPalette: DS.palette,
    cardColorRotation: [
      Color(0xFF0A2A66),
      Color(0xFF0E8C7F),
      Color(0xFF7C3AED),
      Color(0xFF1250C4),
      Color(0xFFB45309),
      Color(0xFF334155),
    ],
  );

  static const dark = AppSemanticColors(
    expense: Color(0xFFF87171),
    income: Color(0xFF4ADE80),
    cash: Color(0xFF13306B),
    chip: DS.surfaceAltDark,
    chipSelected: DS.primaryDark,
    chipSelectedText: Colors.white,
    warningSurface: Color(0xFF3A2A0A),
    dangerSurface: Color(0xFF3A1414),
    chartPalette: DS.palette,
    cardColorRotation: [
      Color(0xFF13306B),
      Color(0xFF0E6E64),
      Color(0xFF5B21B6),
      Color(0xFF1E40AF),
      Color(0xFF92400E),
      Color(0xFF334155),
    ],
  );

  @override
  AppSemanticColors copyWith({
    Color? expense,
    Color? income,
    Color? cash,
    Color? chip,
    Color? chipSelected,
    Color? chipSelectedText,
    Color? warningSurface,
    Color? dangerSurface,
    List<Color>? chartPalette,
    List<Color>? cardColorRotation,
  }) {
    return AppSemanticColors(
      expense: expense ?? this.expense,
      income: income ?? this.income,
      cash: cash ?? this.cash,
      chip: chip ?? this.chip,
      chipSelected: chipSelected ?? this.chipSelected,
      chipSelectedText: chipSelectedText ?? this.chipSelectedText,
      warningSurface: warningSurface ?? this.warningSurface,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      chartPalette: chartPalette ?? this.chartPalette,
      cardColorRotation: cardColorRotation ?? this.cardColorRotation,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return t < 0.5 ? this : other;
  }
}

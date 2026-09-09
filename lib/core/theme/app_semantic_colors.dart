import 'package:flutter/material.dart';

import 'app_colors.dart';

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
    expense: AppColors.red600,
    income: AppColors.teal700,
    cash: AppColors.navy900,
    chip: AppColors.grey100,
    chipSelected: AppColors.teal600,
    chipSelectedText: AppColors.white,
    warningSurface: AppColors.orange100,
    dangerSurface: AppColors.red100,
    chartPalette: [
      AppColors.teal600,
      AppColors.orange600,
      AppColors.navy600,
      AppColors.red500,
      AppColors.grey400,
      AppColors.brown600,
      AppColors.teal500,
      AppColors.grey300,
    ],
    cardColorRotation: [
      AppColors.navy700,
      AppColors.teal600,
      AppColors.brown600,
      AppColors.navy600,
      AppColors.teal700,
      AppColors.brown700,
    ],
  );

  static const dark = AppSemanticColors(
    expense: AppColors.red500,
    income: AppColors.teal500,
    cash: AppColors.navy900,
    chip: AppColors.grey700,
    chipSelected: AppColors.teal600,
    chipSelectedText: AppColors.white,
    warningSurface: AppColors.brown700,
    dangerSurface: AppColors.brown700,
    chartPalette: [
      AppColors.teal500,
      AppColors.orange600,
      AppColors.navy600,
      AppColors.red500,
      AppColors.grey400,
      AppColors.brown600,
      AppColors.teal600,
      AppColors.grey500,
    ],
    cardColorRotation: [
      AppColors.navy600,
      AppColors.teal500,
      AppColors.brown600,
      AppColors.navy700,
      AppColors.teal700,
      AppColors.brown700,
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

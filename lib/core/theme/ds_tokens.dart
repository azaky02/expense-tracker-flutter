import 'package:flutter/material.dart';

/// Masarefy design tokens (UI/UX Master Document §3): deep navy primary, green success,
/// red expense/danger, amber warning, very light gray background, white cards with soft shadow,
/// 12–16 px radius, 8 px grid. Feature code reads colours through the theme, not from here.
class DS {
  DS._();

  // Brand
  static const navy = Color(0xFF0A2A66); // headers, hero surfaces
  static const primary = Color(0xFF1250C4); // buttons, selection, links
  static const primarySoft = Color(0xFFE7EEFC);
  static const teal = Color(0xFF0E8C7F);

  // Semantic
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFE6F6EC);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3DC);

  // Neutrals (light)
  static const background = Color(0xFFF4F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF0F3F8);
  static const border = Color(0xFFE3E8F0);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);

  // Neutrals (dark) — same identity, darker surfaces
  static const backgroundDark = Color(0xFF0B1220);
  static const surfaceDark = Color(0xFF121B2E);
  static const surfaceAltDark = Color(0xFF1B2640);
  static const borderDark = Color(0xFF26324D);
  static const textDark = Color(0xFFE6EAF2);
  static const textMutedDark = Color(0xFF94A3B8);
  static const primaryDark = Color(0xFF4C84F0);

  // Shape & spacing
  static const radius = 14.0;
  static const radiusLg = 18.0;
  static const gap = 8.0;

  /// Hero gradient for the balance card (dashboard) and the onboarding screen.
  static const heroGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF0E7C6B), Color(0xFF0A3D7A)],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A2A66), Color(0xFF1250C4)],
  );

  static List<BoxShadow> softShadow(Brightness b) => b == Brightness.dark
      ? const []
      : const [BoxShadow(color: Color(0x14102A5C), blurRadius: 16, offset: Offset(0, 4))];

  /// Rotating accent colours for icons, categories, charts and accounts.
  static const palette = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF64748B),
  ];
}

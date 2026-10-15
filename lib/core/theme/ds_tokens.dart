import 'package:flutter/material.dart';

/// Masarefy identity: deep emerald green with a gold accent on calm, light backgrounds.
/// Green = income and positive balances, red = expenses and alerts only, amber = "soon".
/// The dark theme keeps the same meanings and layout. Feature code reads colours through the
/// theme where it can.
class DS {
  DS._();

  // Brand
  static const navy = Color(0xFF0A3B28); // deepest green: headers, hero surfaces
  static const primary = Color(0xFF0F5C3E); // emerald: buttons, selection, links, icons
  static const primarySoft = Color(0xFFE4F1EA);
  static const teal = Color(0xFF13805A);
  static const gold = Color(0xFFC9A13B); // accent: highlights, the welcome coin, key figures
  static const goldLight = Color(0xFFE9CB73);
  static const goldSoft = Color(0xFFF7EFD8);

  // Semantic
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFE3F4E8);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDECEC);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF3DC);

  // Neutrals (light)
  static const background = Color(0xFFF4F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEDF2EE);
  static const border = Color(0xFFDDE5DF);
  static const text = Color(0xFF12201A);
  static const textMuted = Color(0xFF5E6E65);

  // Neutrals (dark) — same identity, darker surfaces
  static const backgroundDark = Color(0xFF0A120E);
  static const surfaceDark = Color(0xFF121C17);
  static const surfaceAltDark = Color(0xFF1A2721);
  static const borderDark = Color(0xFF283830);
  static const textDark = Color(0xFFEAF1EC);
  static const textMutedDark = Color(0xFFA3B4AA);
  static const primaryDark = Color(0xFF3FBF86);

  // Shape & spacing
  static const radius = 14.0;
  static const radiusLg = 18.0;
  static const gap = 8.0;

  /// Hero gradient for the balance card (dashboard) and the onboarding screen.
  static const heroGradient = LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color(0xFF13734D), Color(0xFF0A3B28)],
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF07291C), Color(0xFF0F5C3E)],
  );

  /// Gold for coins and highlights.
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3DA8A), Color(0xFFC9A13B), Color(0xFF9A7420)],
  );

  static List<BoxShadow> softShadow(Brightness b) =>
      b == Brightness.dark ? const [] : const [BoxShadow(color: Color(0x120A3B28), blurRadius: 16, offset: Offset(0, 4))];

  /// Rotating accent colours for icons, categories, charts and accounts.
  /// Muted, brand-friendly set (categories and charts still need distinct colours).
  static const palette = [
    Color(0xFF0F5C3E),
    Color(0xFFC9A13B),
    Color(0xFF2F7D8C),
    Color(0xFF8C5A2B),
    Color(0xFF5B7F3A),
    Color(0xFFB4533C),
    Color(0xFF4A5D7A),
    Color(0xFF6B7280),
  ];
}

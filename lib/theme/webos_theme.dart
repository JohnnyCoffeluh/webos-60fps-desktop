import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WebOSTheme {
  static const Color background = Color(0xFF080C14);
  static const Color surface = Color(0xFF0F172A);
  static const Color surfaceElevated = Color(0xFF1E293B);
  static const Color surfaceBorder = Color(0x3338BDF8);

  static const Color primary = Color(0xFF38BDF8); // Cyan
  static const Color secondary = Color(0xFF818CF8); // Indigo
  static const Color accent = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        surface: surface,
        error: error,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFFF1F5F9),
        displayColor: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFE2E8F0)),
    );
  }
}

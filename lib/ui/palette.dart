import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Muted dark greys plus one accent.
class Palette {
  final Color bg;
  final Color fg;
  final Color muted;
  final Color hair;
  final Color accent;
  final Color onAccent;

  const Palette({
    required this.bg,
    required this.fg,
    required this.muted,
    required this.hair,
    required this.accent,
    required this.onAccent,
  });

  static const dark = Palette(
    bg: Color(0xFF2E2E2E),
    fg: Color(0xFFE2E2E2),
    muted: Color(0xFF7C7C7C),
    hair: Color(0xFF4C4C4C),
    accent: Color(0xFFC8404F),
    onAccent: Color(0xFFF6F6F6),
  );

  static Palette of(BuildContext context) => dark;

  /// Thin display numerals (level strip, circle label).
  TextStyle thin(double size, {Color? color}) => GoogleFonts.barlow(
    fontSize: size,
    fontWeight: FontWeight.w200,
    color: color ?? fg,
  );

  /// Body text.
  TextStyle body(double size, {Color? color, double spacing = 0}) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? fg,
        letterSpacing: spacing,
      );

  /// Heavy condensed headings (answer buttons, settings sections).
  TextStyle heavy(double size, {Color? color}) =>
      GoogleFonts.barlowSemiCondensed(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? fg,
        height: 1,
      );
}

ThemeData buildTheme() {
  const p = Palette.dark;
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: Brightness.dark,
      surface: p.bg,
    ),
    splashFactory: InkSparkle.splashFactory,
    useMaterial3: true,
  );
}

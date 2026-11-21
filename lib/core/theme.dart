import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Frame Police theme — the V7 palette: near-black space, amber accent.
///
/// PHASE 1 uses a single theme (the V7 dark palette the screens were
/// designed in). It is structured for the phase-2 dark/light swap: the
/// palette lives in [FpPalette], and [AppTheme] builds a [ThemeData]
/// from a palette. Phase 2 adds a second palette (e.g.
/// `FpPalette.light`) and a mode switch — no screen code changes, because
/// screens read colours from `Theme.of(context)` and [FpPalette.current]
/// helpers, never from hardcoded values.
///
/// Colour tokens come from the V7 design source
/// (`v7_framepolice.py`): BG0 #0B0D10, amber #F5A524 → orange #F97316.
class FpPalette {
  const FpPalette({
    required this.background0,
    required this.background1,
    required this.background2,
    required this.ink,
    required this.secondary,
    required this.muted,
    required this.amber,
    required this.orange,
    required this.green,
    required this.red,
    required this.redDeep,
    required this.pink,
    required this.cyan,
    required this.glass,
    required this.glassStrong,
    required this.hairline,
  });

  /// The single v0.1 palette — the V7 animated-essence look.
  static const FpPalette v7 = FpPalette(
    background0: Color(0xFF0B0D10),
    background1: Color(0xFF161B22),
    background2: Color(0xFF1F2937),
    ink: Color(0xFFFFFFFF),
    secondary: Color(0xFFFDE68A),
    muted: Color(0xFFFBBF24),
    amber: Color(0xFFF5A524),
    orange: Color(0xFFF97316),
    green: Color(0xFF34D399),
    red: Color(0xFFF87171),
    redDeep: Color(0xFFEF4444),
    pink: Color(0xFFF472B6),
    cyan: Color(0xFF67E8F9),
    glass: Color(0x14FFFFFF),
    glassStrong: Color(0x21FFFFFF),
    hairline: Color(0x26FFFFFF),
  );

  final Color background0;
  final Color background1;
  final Color background2;
  final Color ink;
  final Color secondary;
  final Color muted;
  final Color amber;
  final Color orange;
  final Color green;
  final Color red;
  final Color redDeep;
  final Color pink;
  final Color cyan;
  final Color glass;
  final Color glassStrong;
  final Color hairline;

  /// Amber → orange gradient used for primary CTAs and the badge.
  LinearGradient get accentGradient => LinearGradient(
        colors: [amber, orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Faint white text (60% opacity) for secondary copy.
  Color get faint => ink.withValues(alpha: 0.6);
}

class AppTheme {
  AppTheme._();

  /// The current palette. Phase 2 swaps this for a mode-aware lookup.
  static const FpPalette palette = FpPalette.v7;

  /// The single v0.1 theme, built from [palette].
  static ThemeData get data => _build(palette);

  static ThemeData _build(FpPalette p) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: p.amber,
        onPrimary: p.background0,
        secondary: p.orange,
        surface: p.background1,
        onSurface: p.ink,
        error: p.red,
      ),
      scaffoldBackgroundColor: p.background0,
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.inter(
        fontSize: 30, fontWeight: FontWeight.w800, color: p.ink, height: 1.1,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24, fontWeight: FontWeight.w800, color: p.ink, height: 1.15,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20, fontWeight: FontWeight.w700, color: p.ink,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w600, color: p.ink,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: p.ink, height: 1.5),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: p.ink, height: 1.5),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: p.faint, height: 1.5),
      labelLarge: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w600, color: p.ink,
      ),
    );
    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background0,
        foregroundColor: p.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w700, color: p.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.glass,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.amber,
          foregroundColor: p.background0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.glass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.amber),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: p.faint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.background0
              : p.faint,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.amber
              : p.glassStrong,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.background1,
        selectedItemColor: p.amber,
        unselectedItemColor: p.faint,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.background1,
        selectedIconTheme: IconThemeData(color: p.amber),
        unselectedIconTheme: IconThemeData(color: p.faint),
        selectedLabelTextStyle:
            GoogleFonts.inter(fontSize: 12, color: p.amber),
        unselectedLabelTextStyle:
            GoogleFonts.inter(fontSize: 12, color: p.faint),
        indicatorColor: p.glassStrong,
      ),
      dividerColor: p.hairline,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.background2,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: p.ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// Monospace text style (JetBrains Mono) for timecodes, values, YAML.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? palette.secondary,
      );
}

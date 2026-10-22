import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet resmi ZPP Reload: Electric Blue #1778FF (utama), Emerald Green #22C55E (aksen), putih.
class Brand {
  static const deep = Color(0xFF062E75);
  static const primary = Color(0xFF1778FF);
  static const primaryLight = Color(0xFFE8F1FF);
  static const accent = Color(0xFF22C55E);
  static const accentLight = Color(0xFFBBF7D0);
  static const background = Color(0xFFF4F7FC);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deep, Color(0xFF0B4FC4), primary],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4ADE80), accent, Color(0xFF15A34A)],
  );

  static List<BoxShadow> get softShadow => [
    BoxShadow(color: deep.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
  ];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    primary: Brand.primary,
    secondary: Brand.accent,
    surface: Colors.white,
  );
  final text = GoogleFonts.plusJakartaSansTextTheme().apply(bodyColor: Brand.ink, displayColor: Brand.ink);
  final radius = BorderRadius.circular(14);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F4F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Brand.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.primary,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: Color(0xFFD5DEEC)),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Brand.primary,
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Brand.primaryLight,
      elevation: 8,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Brand.primary : Brand.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Brand.primary : Brand.muted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.deep,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFEDF1F7), space: 1),
  );
}

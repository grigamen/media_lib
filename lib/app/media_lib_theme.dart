import "package:flutter/material.dart";

ThemeData buildMediaLibTheme(Brightness brightness) {
  const seed = Color(0xFF6E52C8);
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
    useMaterial3: true,
  );
  final scheme = base.colorScheme;
  return base.copyWith(
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF12121B) : const Color(0xFFF1EFF4),
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF272735) : const Color(0xFFE2DDEA),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor:
          isDark ? const Color(0xFF151520) : const Color(0xFFF1EFF4),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          color: scheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
      indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.3 : 0.18),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor:
          isDark ? const Color(0xFF2B2B3B) : const Color(0xFFE0DCE8),
      selectedColor: scheme.primary,
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: isDark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? const Color(0xFF1B1B27) : Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      ),
    ),
  );
}

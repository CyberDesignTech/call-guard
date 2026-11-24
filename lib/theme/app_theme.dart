import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData themeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final canvas = isDark ? const Color(0xFF101722) : const Color(0xFFF5F7FB);
    final surface = isDark ? const Color(0xFF192434) : Colors.white;
    final ink = isDark ? const Color(0xFFF0F4FC) : const Color(0xFF17243B);
    final primary = isDark ? const Color(0xFFA8B9FF) : const Color(0xFF4263EB);
    final line = isDark ? const Color(0xFF2B394E) : const Color(0xFFE8ECF3);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4263EB),
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? const Color(0xFF17243B) : Colors.white,
          surface: surface,
          onSurface: ink,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF29384D)
            : const Color(0xFF17243B),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}

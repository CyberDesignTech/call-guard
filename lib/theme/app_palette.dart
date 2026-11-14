import 'package:flutter/material.dart';

abstract final class AppPalette {
  static bool isDark = false;

  static Color get ink =>
      isDark ? const Color(0xFFF0F4FC) : const Color(0xFF17243B);
  static Color get muted =>
      isDark ? const Color(0xFFA2AEC2) : const Color(0xFF748198);
  static const blue = Color(0xFF4263EB);
  static Color get bluePale =>
      isDark ? const Color(0xFF273653) : const Color(0xFFEEF2FF);
  static const green = Color(0xFF15966A);
  static const greenPale = Color(0xFFE8F7F0);
  static const amber = Color(0xFFE29A27);
  static const amberPale = Color(0xFFFFF5E4);
  static const red = Color(0xFFD95757);
  static const redPale = Color(0xFFFFEEEE);
  static Color get canvas =>
      isDark ? const Color(0xFF101722) : const Color(0xFFF5F7FB);
  static Color get surface => isDark ? const Color(0xFF192434) : Colors.white;
  static Color get line =>
      isDark ? const Color(0xFF2B394E) : const Color(0xFFE8ECF3);
  static const navy = Color(0xFF172744);

  static Color accent(Color color) {
    if (!isDark) return color;
    if (color == green) return const Color(0xFF64D7A7);
    if (color == red) return const Color(0xFFFF9292);
    if (color == amber) return const Color(0xFFFFC96E);
    if (color == blue) return const Color(0xFFA8B9FF);
    if (color == const Color(0xFF7663D9)) return const Color(0xFFB7A8FF);
    return color;
  }

  static Color accentSurface(Color color) {
    if (!isDark) {
      if (color == green) return greenPale;
      if (color == red) return redPale;
      if (color == amber) return amberPale;
      if (color == blue) return bluePale;
      if (color == muted) return const Color(0xFFF0F2F6);
      return const Color(0xFFF0EDFF);
    }
    if (color == green) return const Color(0xFF1D3D34);
    if (color == red) return const Color(0xFF452B32);
    if (color == amber) return const Color(0xFF44371F);
    if (color == blue) return const Color(0xFF273653);
    if (color == muted) return const Color(0xFF293547);
    return const Color(0xFF342D50);
  }
}

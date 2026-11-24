import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class Tag extends StatelessWidget {
  const Tag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.isDark ? AppPalette.accentSurface(color) : background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.accent(color),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

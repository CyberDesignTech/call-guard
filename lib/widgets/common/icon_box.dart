import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class IconBox extends StatelessWidget {
  const IconBox({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 43,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppPalette.isDark ? AppPalette.accentSurface(color) : background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppPalette.accent(color), size: 20),
    );
  }
}

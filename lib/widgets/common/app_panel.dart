import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class AppPanel extends StatelessWidget {
  const AppPanel({required this.child, this.color, this.borderColor});

  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppPalette.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: borderColor ?? AppPalette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2345),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

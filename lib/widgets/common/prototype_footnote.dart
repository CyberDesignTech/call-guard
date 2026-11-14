import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class PrototypeFootnote extends StatelessWidget {
  const PrototypeFootnote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 13, color: AppPalette.muted),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.muted, fontSize: 9),
          ),
        ),
      ],
    );
  }
}

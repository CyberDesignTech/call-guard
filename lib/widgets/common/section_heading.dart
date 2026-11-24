import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class SectionHeading extends StatelessWidget {
  const SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppPalette.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: AppPalette.muted, fontSize: 11)),
      ],
    );
  }
}

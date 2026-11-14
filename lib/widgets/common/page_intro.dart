import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class PageIntro extends StatelessWidget {
  const PageIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: AppPalette.accent(AppPalette.blue),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.25,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: AppPalette.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: AppPalette.muted, fontSize: 12)),
      ],
    );
  }
}

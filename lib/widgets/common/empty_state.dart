import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.muted, fontSize: 12),
      ),
    ),
  );
}

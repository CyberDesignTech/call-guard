import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class ProtectionWarning extends StatefulWidget {
  const ProtectionWarning({
    super.key,
    required this.message,
    this.containerKey,
  });

  final String message;
  final Key? containerKey;

  @override
  State<ProtectionWarning> createState() => ProtectionWarningState();
}

class ProtectionWarningState extends State<ProtectionWarning> {
  Timer? _highlightTimer;
  bool _highlighted = false;

  void highlight() {
    _highlightTimer?.cancel();
    setState(() => _highlighted = true);
    _highlightTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _highlighted = false);
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    key: widget.containerKey,
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _highlighted
          ? Color.lerp(AppPalette.amberPale, AppPalette.amber, 0.16)
          : AppPalette.amberPale,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: _highlighted
            ? AppPalette.amber
            : AppPalette.amber.withValues(alpha: 0.35),
        width: _highlighted ? 2 : 1,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.shield_outlined,
          size: 19,
          color: AppPalette.accent(AppPalette.amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.message,
            style: TextStyle(color: AppPalette.ink, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

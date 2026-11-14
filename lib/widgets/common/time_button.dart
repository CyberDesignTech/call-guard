import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

class TimeButton extends StatelessWidget {
  const TimeButton({
    required this.caption,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  final String caption;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        side: BorderSide(color: AppPalette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppPalette.canvas,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: AppPalette.accent(AppPalette.blue)),
              const SizedBox(width: 5),
              Text(
                caption,
                style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.65,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

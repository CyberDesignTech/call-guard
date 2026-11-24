import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Bottom information banner with an inline link to app information.
class AppInfoFootnote extends StatelessWidget {
  const AppInfoFootnote({
    required this.message,
    required this.linkLabel,
    required this.onSupport,
  });

  final String message;
  final String linkLabel;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.bluePale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: AppPalette.accent(AppPalette.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    height: 1.35,
                  ),
                ),
                InkWell(
                  onTap: onSupport,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      linkLabel,
                      style: TextStyle(
                        color: AppPalette.accent(AppPalette.blue),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        decoration: TextDecoration.underline,
                        decorationColor: AppPalette.accent(AppPalette.blue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

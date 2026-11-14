import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_palette.dart';
import 'app_panel.dart';
import 'icon_box.dart';
import 'tag.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({
    required this.strings,
    required this.phone,
    required this.caption,
    required this.reason,
    required this.tint,
    required this.pale,
    required this.icon,
    required this.onDelete,
    required this.onAdd,
    required this.addLabel,
  });

  final AppStrings strings;
  final String phone;
  final String caption;
  final String reason;
  final Color tint;
  final Color pale;
  final IconData icon;
  final VoidCallback onDelete;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBox(icon: icon, color: tint, background: pale),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phone,
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        style: TextStyle(color: AppPalette.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Tag(label: reason, color: tint, background: pale),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                  label: Text(addLabel),
                  style: TextButton.styleFrom(
                    foregroundColor: AppPalette.accent(AppPalette.blue),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.call('deleteCallLog'),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppPalette.muted,
                    size: 19,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

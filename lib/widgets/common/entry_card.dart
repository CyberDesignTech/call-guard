import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/list_entry.dart';
import '../../theme/app_palette.dart';
import 'app_panel.dart';
import 'icon_box.dart';
import 'tag.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({
    required this.entry,
    required this.strings,
    required this.onDelete,
  });

  final ListEntry entry;
  final AppStrings strings;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            IconBox(
              icon: entry.icon,
              color: entry.tint,
              background: entry.pale,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.titleKey == null
                        ? entry.title
                        : strings.call(entry.titleKey!),
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Tag(
              label: entry.badgeKey == null
                  ? entry.badge
                  : strings.call(entry.badgeKey!),
              color: entry.tint,
              background: entry.pale,
            ),
            const SizedBox(width: 3),
            IconButton(
              tooltip: strings.call('delete'),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: AppPalette.muted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

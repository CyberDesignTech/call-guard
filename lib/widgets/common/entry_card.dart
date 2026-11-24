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
    this.expiryLabel,
    this.onMakePermanent,
  });

  final ListEntry entry;
  final AppStrings strings;
  final VoidCallback onDelete;
  final String? expiryLabel;
  final VoidCallback? onMakePermanent;

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
                  if (expiryLabel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_bottom_rounded,
                          size: 13,
                          color: AppPalette.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            expiryLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppPalette.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
            if (onMakePermanent != null)
              PopupMenuButton<String>(
                tooltip: strings.call('temporaryRuleMenu'),
                onSelected: (value) {
                  if (value == 'permanent') onMakePermanent!();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'permanent',
                    child: Text(strings.call('makePermanent')),
                  ),
                ],
                icon: Icon(Icons.more_vert_rounded, color: AppPalette.muted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 36,
                ),
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

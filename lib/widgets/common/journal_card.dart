import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_palette.dart';
import 'app_panel.dart';
import 'icon_box.dart';
import 'tag.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({
    required this.strings,
    required this.phone,
    this.contactName = '',
    required this.caption,
    required this.reason,
    required this.tint,
    required this.pale,
    required this.icon,
    this.onDelete,
    this.onAdd,
    this.addLabel,
  });

  final AppStrings strings;
  final String phone;
  final String contactName;
  final String caption;
  final String reason;
  final Color tint;
  final Color pale;
  final IconData icon;
  final VoidCallback? onDelete;
  final VoidCallback? onAdd;
  final String? addLabel;

  Future<void> _copyNumber(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(strings.call('numberCopied'))));
  }

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
                        contactName.trim().isEmpty ? phone : contactName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (contactName.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (onAdd != null && addLabel != null)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                    label: Text(addLabel!),
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
                  tooltip: strings.call('copyNumber'),
                  onPressed: () => _copyNumber(context),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  icon: Icon(
                    Icons.copy_rounded,
                    color: AppPalette.accent(AppPalette.blue),
                    size: 18,
                  ),
                ),
                if (onDelete != null)
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

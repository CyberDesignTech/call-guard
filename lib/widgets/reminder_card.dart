import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/reminder.dart';
import '../theme/app_palette.dart';
import 'common/app_panel.dart';
import 'common/icon_box.dart';
import 'common/localized_value.dart';
import 'common/tag.dart';
import 'common/thin_divider.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    required this.reminder,
    required this.strings,
    required this.dateLabel,
    required this.repeatLabel,
    required this.onCall,
    required this.onEditTime,
    required this.onToggleDone,
    required this.onDelete,
  });

  final Reminder reminder;
  final AppStrings strings;
  final String dateLabel;
  final String? repeatLabel;
  final VoidCallback onCall;
  final VoidCallback onEditTime;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

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
                IconBox(
                  icon: Icons.person_outline_rounded,
                  color: AppPalette.accent(AppPalette.blue),
                  background: AppPalette.bluePale,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.contactName.isEmpty
                            ? strings.call('reminderNew')
                            : localizedValue(strings, reminder.contactName),
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reminder.phone,
                        style: TextStyle(color: AppPalette.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (repeatLabel != null) ...[
                        Tag(
                          label: repeatLabel!,
                          color: AppPalette.blue,
                          background: AppPalette.bluePale,
                        ),
                        const SizedBox(height: 3),
                      ],
                      Tooltip(
                        message: strings.call('editReminderTime'),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onEditTime,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 15,
                                    color: AppPalette.accent(AppPalette.blue),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      dateLabel,
                                      textAlign: TextAlign.right,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppPalette.accent(
                                          AppPalette.blue,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.edit_calendar_outlined,
                                    size: 13,
                                    color: AppPalette.muted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: ThinDivider(),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reminder.note.isEmpty
                        ? strings.call('reminderNewNote')
                        : localizedValue(strings, reminder.note),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: Text(strings.call('callButton')),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Tooltip(
                  message: strings.call(
                    reminder.isDone ? 'restoreReminder' : 'markReminderDone',
                  ),
                  child: InkWell(
                    onTap: onToggleDone,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reminder.isDone
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: reminder.isDone
                                ? AppPalette.green
                                : AppPalette.muted,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.call(
                              reminder.isDone
                                  ? 'reminderDoneStatus'
                                  : 'markReminderDone',
                            ),
                            style: TextStyle(
                              color: reminder.isDone
                                  ? AppPalette.green
                                  : AppPalette.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: strings.call('delete'),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: AppPalette.muted,
                    size: 18,
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

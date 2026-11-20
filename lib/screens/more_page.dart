import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../models/call_log_entry.dart';
import '../models/recent_call_log_entry.dart';
import '../models/reminder.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/contact_picker.dart';
import '../widgets/common/journal_card.dart';
import '../widgets/common/localized_value.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/repeat_fields.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/reminder_card.dart';

class MorePage extends StatefulWidget {
  const MorePage({
    required this.database,
    required this.onStub,
    required this.strings,
    required this.isActive,
    required this.statusIndicatorEnabled,
    required this.onStatusIndicatorChanged,
    this.journalOpenRequest = 0,
    this.callHandledRequest = 0,
  });

  final DatabaseHelper database;
  final VoidCallback onStub;
  final AppStrings strings;
  final bool isActive;
  final bool statusIndicatorEnabled;
  final ValueChanged<bool> onStatusIndicatorChanged;
  final int journalOpenRequest;
  final int callHandledRequest;

  @override
  State<MorePage> createState() => MorePageState();
}

class MorePageState extends State<MorePage> with WidgetsBindingObserver {
  int _segment = 0;
  List<Reminder> _reminders = [];
  List<CallLogEntry> _logs = [];
  bool _loading = true;
  bool _notificationsGranted = false;
  Timer? _refreshTimer;
  final _screeningChannel = CallScreeningChannel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.journalOpenRequest > 0) _segment = 1;
    _reload();
    _refreshNotificationStatus();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        if (_segment == 1) {
          unawaited(_reloadLogs());
        } else {
          unawaited(_reloadReminders());
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant MorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journalOpenRequest != widget.journalOpenRequest &&
        widget.journalOpenRequest > 0) {
      setState(() => _segment = 1);
      unawaited(_reload());
    }
    if (oldWidget.callHandledRequest != widget.callHandledRequest) {
      unawaited(_reload());
    }
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_refreshNotificationStatus());
      unawaited(_reload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNotificationStatus());
      if (widget.isActive) {
        if (_segment == 1) {
          unawaited(_reloadLogs());
        } else {
          unawaited(_reloadReminders());
        }
      }
    }
  }

  Future<void> _reload() async {
    final reminderRows = await widget.database.getReminders();
    final logRows = await widget.database.getCallLogs();
    if (!mounted) return;
    setState(() {
      _reminders = reminderRows.map(_reminderFromRow).toList();
      _logs = logRows.map(_logFromRow).toList();
      _loading = false;
    });
  }

  Future<void> _reloadLogs() async {
    final logRows = await widget.database.getCallLogs();
    if (!mounted) return;
    setState(() {
      _logs = logRows.map(_logFromRow).toList();
      _loading = false;
    });
  }

  Future<void> _reloadReminders() async {
    final reminderRows = await widget.database.getReminders();
    if (!mounted) return;
    setState(() {
      _reminders = reminderRows.map(_reminderFromRow).toList();
      _loading = false;
    });
  }

  Future<void> _refreshNotificationStatus() async {
    try {
      final permissions = await _screeningChannel.checkPermissions();
      if (!mounted) return;
      setState(() => _notificationsGranted = permissions.notificationsGranted);
      if (permissions.notificationsGranted) {
        await _screeningChannel.restorePendingReminders();
      }
    } on PlatformException {
      // Non-Android platforms do not expose Android notification permissions.
    } on MissingPluginException {
      // The status check is provided by the Android MethodChannel.
    }
  }

  Future<void> _requestNotificationAccess() async {
    try {
      final granted = await _screeningChannel.requestNotificationPermission();
      if (granted) {
        await widget.database.setSetting(
          'notification_permission_prompted',
          true,
        );
        await _screeningChannel.restorePendingReminders();
      }
    } on PlatformException {
      // Refresh below displays the effective setting after returning from Android settings.
    } on MissingPluginException {
      // Notification permission requests are available only on Android.
    }
    await _refreshNotificationStatus();
  }

  Reminder _reminderFromRow(Map<String, Object?> row) => Reminder(
    id: row['id'] as int,
    phone: row['phone'] as String,
    contactName: row['contact_name'] as String? ?? '',
    remindAt: row['remind_at'] as int,
    note: row['note'] as String? ?? '',
    isDone: (row['is_done'] as int? ?? 0) != 0,
    repeatType: row['repeat_type'] as String? ?? 'none',
    repeatInterval: (row['repeat_interval'] as int? ?? 1).clamp(1, 365).toInt(),
  );

  CallLogEntry _logFromRow(Map<String, Object?> row) => CallLogEntry(
    id: row['id'] as int,
    phone: row['phone'] as String,
    contactName: row['contact_name'] as String? ?? '',
    reason: row['reason'] as String,
    timestamp: row['timestamp'] as int,
  );

  String _dateTimeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDay = DateTime(date.year, date.month, date.day);
    final difference = reminderDay.difference(today).inDays;
    final dayLabel = switch (difference) {
      0 => widget.strings.call('today'),
      1 => widget.strings.call('tomorrow'),
      -1 => widget.strings.call('yesterday'),
      _ => _dateLabel(date),
    };
    return '$dayLabel · ${_timeLabel(TimeOfDay.fromDateTime(date))}';
  }

  String? _repeatLabel(Reminder reminder) => switch (reminder.repeatType) {
    'daily' => widget.strings.call('repeatDaily'),
    'weekly' => widget.strings.call('repeatWeekly'),
    'custom' =>
      widget.strings
          .call('repeatEveryDays')
          .replaceAll('{count}', reminder.repeatInterval.toString()),
    _ => null,
  };

  Future<void> _toggleReminder(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;
    final isDone = !reminder.isDone;
    await widget.database.updateReminderDone(id, isDone);
    try {
      if (isDone) {
        await _screeningChannel.cancelReminder(id);
      } else {
        await _screeningChannel.scheduleReminder(
          id: id,
          remindAt: reminder.remindAt,
        );
      }
    } on PlatformException {
      // The database remains authoritative if AlarmManager is unavailable.
    } on MissingPluginException {
      // Scheduling is available only on Android.
    }
    await _reload();
  }

  Future<void> _deleteReminder(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;
    try {
      await _screeningChannel.cancelReminder(id);
    } on PlatformException {
      // Still remove the database row if the native scheduler cannot be reached.
    } on MissingPluginException {
      // Scheduling is available only on Android.
    }
    await widget.database.deleteReminder(id);
    await _reload();
  }

  Future<void> _editReminderTime(Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;
    final current = DateTime.fromMillisecondsSinceEpoch(reminder.remindAt);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selectedDate == null || !mounted) return;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (selectedTime == null || !mounted) return;
    final repeatRule = await _pickRepeatRule(
      repeatType: reminder.repeatType,
      repeatInterval: reminder.repeatInterval,
    );
    if (repeatRule == null || !mounted) return;

    final updatedReminderAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    ).millisecondsSinceEpoch;
    await widget.database.updateReminderSchedule(
      id: id,
      remindAt: updatedReminderAt,
      repeatType: repeatRule.type,
      repeatInterval: repeatRule.interval,
    );
    try {
      if (reminder.isDone) {
        await _screeningChannel.cancelReminder(id);
      } else {
        await _screeningChannel.scheduleReminder(
          id: id,
          remindAt: updatedReminderAt,
        );
      }
    } on PlatformException {
      // The saved date is restored and re-scheduled when the app starts.
    } on MissingPluginException {
      // AlarmManager scheduling is available only on Android.
    }
    await _reloadReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('reminderTimeUpdated'))),
      );
  }

  Future<RepeatRule?> _pickRepeatRule({
    required String repeatType,
    required int repeatInterval,
  }) async {
    var selectedType = repeatType;
    final intervalController = TextEditingController(
      text: repeatInterval.clamp(1, 365).toString(),
    );
    final dialogRoute = DialogRoute<RepeatRule>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(widget.strings.call('repeatTitle')),
          content: RepeatFields(
            strings: widget.strings,
            repeatType: selectedType,
            intervalController: intervalController,
            onRepeatTypeChanged: (value) =>
                setDialogState(() => selectedType = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(widget.strings.call('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                RepeatRule(
                  type: selectedType,
                  interval: selectedType == 'custom'
                      ? _repeatIntervalValue(intervalController.text)
                      : 1,
                ),
              ),
              child: Text(widget.strings.call('save')),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialogRoute);
    await dialogRoute.completed;
    intervalController.dispose();
    return result;
  }

  int _repeatIntervalValue(String raw) =>
      (int.tryParse(raw) ?? 1).clamp(1, 365).toInt();

  Future<void> _dialReminder(String phoneNumber) async {
    try {
      await _screeningChannel.openDialer(phoneNumber);
    } on PlatformException {
      widget.onStub();
    } on MissingPluginException {
      widget.onStub();
    }
  }

  Future<void> _requestNotificationPermissionOnce() async {
    final settings = await widget.database.getSettings();
    if (settings['notification_permission_prompted'] == 'true') return;

    var granted = false;
    try {
      granted = await _screeningChannel.requestNotificationPermission();
    } on PlatformException {
      // Reminders remain scheduled even if notifications cannot be authorized.
    } on MissingPluginException {
      // Notification permission requests are available only on Android.
    }
    await widget.database.setSetting('notification_permission_prompted', true);
    await _refreshNotificationStatus();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(widget.strings.call('notificationsPermissionNeeded')),
          ),
        );
    }
  }

  bool _isBlockedReason(String reason) => const {
    'silent_schedule',
    'hidden_number',
    'country_block',
    'international_block',
    'blacklist',
    'short_number_block',
    'operator_block',
    'non_contacts',
    'not_in_contacts',
    'allowlist_only',
    'driving_mode',
  }.contains(reason);

  Future<void> _quickAddFromLog(CallLogEntry entry) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.strings.call('quickAddTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                entry.phone,
                style: TextStyle(color: AppPalette.muted),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: Text(widget.strings.call('quickAddAllowlist')),
              onTap: () => Navigator.pop(dialogContext, 'permanent'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_bottom_rounded),
              title: Text(widget.strings.call('quickAddTemporaryHour')),
              onTap: () => Navigator.pop(dialogContext, 'hour'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hourglass_bottom_rounded),
              title: Text(widget.strings.call('quickAddTemporaryDay')),
              onTap: () => Navigator.pop(dialogContext, 'day'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final number = normalizePhoneNumber(entry.phone);
    if (number.isEmpty) return;
    final expiresAt = switch (choice) {
      'hour' =>
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
      'day' =>
        DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
      _ => null,
    };
    final existing = await widget.database.getPhoneRules('white');
    final existingRule = existing
        .where(
          (row) =>
              normalizePhoneNumber(row['phone'] as String? ?? '') == number,
        )
        .firstOrNull;
    if (choice == 'permanent' && existingRule != null) {
      final id = existingRule['id'] as int?;
      if (id != null && existingRule['expires_at'] != null) {
        await widget.database.makePhoneRulePermanent(id);
      }
    } else if (existingRule == null) {
      await widget.database.insertPhoneRule(
        phone: number,
        label: entry.contactName.trim().isEmpty ? null : entry.contactName,
        listType: 'white',
        expiresAt: expiresAt,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('quickAddSuccess'))),
      );
  }

  Future<void> _deleteCallLog(CallLogEntry entry) async {
    await widget.database.deleteCallLog(entry.id);
    await _reloadLogs();
  }

  Future<void> _confirmClearCallLogs() async {
    if (_logs.isEmpty) return;
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: AppPalette.accent(AppPalette.red),
        ),
        title: Text(widget.strings.call('clearJournalTitle')),
        content: Text(widget.strings.call('clearJournalMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(widget.strings.call('cancel')),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(widget.strings.call('clearJournalConfirm')),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;
    await widget.database.clearCallLogs();
    await _reloadLogs();
  }

  Future<void> _createReminder() async {
    final phoneController = TextEditingController();
    final contactNameController = TextEditingController();
    final noteController = TextEditingController();
    final repeatIntervalController = TextEditingController(text: '3');
    var repeatType = 'none';
    var selectedDate = DateTime.now().add(const Duration(days: 1));
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);

    final dialogRoute = DialogRoute<Reminder>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.notifications_active_outlined,
            color: AppPalette.blue,
          ),
          title: Text(widget.strings.call('newReminderTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('phoneNumber'),
                    hintText: widget.strings.call('phoneNumberHint'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('optionalName'),
                    hintText: widget.strings.call('nameExample'),
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final contact = await pickContactFromPhoneBook(
                      context: dialogContext,
                      strings: widget.strings,
                      channel: _screeningChannel,
                    );
                    if (contact == null || !dialogContext.mounted) return;
                    phoneController.text = contact.phone ?? '';
                    contactNameController.text = contact.name ?? '';
                  },
                  icon: const Icon(Icons.contacts_outlined, size: 18),
                  label: Text(widget.strings.call('pickFromContacts')),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (date != null)
                            setDialogState(() => selectedDate = date);
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(_dateLabel(selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null)
                          setDialogState(() => selectedTime = time);
                      },
                      child: Text(_timeLabel(selectedTime)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionHeading(
                  title: widget.strings.call('repeatTitle'),
                  subtitle: widget.strings.call('repeatHint'),
                ),
                const SizedBox(height: 6),
                RepeatFields(
                  strings: widget.strings,
                  repeatType: repeatType,
                  intervalController: repeatIntervalController,
                  onRepeatTypeChanged: (value) =>
                      setDialogState(() => repeatType = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('note'),
                    hintText: widget.strings.call('noteHint'),
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(widget.strings.call('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final phone = phoneController.text.trim();
                if (phone.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  Reminder(
                    phone: phone,
                    contactName: contactNameController.text.trim().isEmpty
                        ? '@reminderNew'
                        : contactNameController.text.trim(),
                    remindAt: DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    ).millisecondsSinceEpoch,
                    note: noteController.text.trim().isEmpty
                        ? '@reminderNewNote'
                        : noteController.text.trim(),
                    repeatType: repeatType,
                    repeatInterval: repeatType == 'custom'
                        ? _repeatIntervalValue(repeatIntervalController.text)
                        : 1,
                  ),
                );
              },
              child: Text(widget.strings.call('create')),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(
      context,
      rootNavigator: true,
    ).push(dialogRoute);
    await dialogRoute.completed;

    phoneController.dispose();
    contactNameController.dispose();
    noteController.dispose();
    repeatIntervalController.dispose();
    if (result != null && mounted) {
      final reminderId = await widget.database.insertReminder(
        phone: result.phone,
        contactName: result.contactName,
        remindAt: result.remindAt,
        note: result.note,
        repeatType: result.repeatType,
        repeatInterval: result.repeatInterval,
      );
      await _requestNotificationPermissionOnce();
      try {
        await _screeningChannel.scheduleReminder(
          id: reminderId,
          remindAt: result.remindAt,
        );
      } on PlatformException {
        // The reminder is persisted and can still be scheduled after app restart.
      } on MissingPluginException {
        // AlarmManager scheduling is available only on Android.
      }
      await _reload();
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          PageIntro(
            eyebrow: widget.strings.call('moreEyebrow'),
            title: widget.strings.moreTitle,
            subtitle: widget.strings.call('moreSubtitle'),
          ),
          const SizedBox(height: 17),
          AppPanel(
            child: RuleSwitch(
              icon: Icons.shield_outlined,
              title: widget.strings.call('statusIndicatorTitle'),
              subtitle: widget.strings.call('statusIndicatorSubtitle'),
              value: widget.statusIndicatorEnabled,
              onChanged: widget.onStatusIndicatorChanged,
              iconColor: AppPalette.blue,
              iconBackground: AppPalette.bluePale,
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment<int>(
                value: 0,
                icon: Icon(Icons.notifications_none_rounded, size: 17),
                label: Text(widget.strings.call('remindersSegment')),
              ),
              ButtonSegment<int>(
                value: 1,
                icon: Icon(Icons.receipt_long_outlined, size: 17),
                label: Text(widget.strings.call('journalSegment')),
              ),
            ],
            selected: {_segment},
            onSelectionChanged: (selection) {
              setState(() => _segment = selection.first);
              if (selection.first == 1) {
                unawaited(_reloadLogs());
              } else {
                unawaited(_reloadReminders());
              }
            },
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 5, vertical: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (_segment == 0) ..._reminderContent() else ..._journalContent(),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                Text(
                  widget.strings.call('copyrightLine'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.52),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.strings.call('footerCollective'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.52),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _reminderContent() => [
    if (!_notificationsGranted) ...[
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppPalette.accentSurface(AppPalette.amber),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: AppPalette.accent(AppPalette.amber).withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: AppPalette.accent(AppPalette.amber),
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.strings.call('notificationReminderBanner'),
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            FilledButton.icon(
              onPressed: _requestNotificationAccess,
              icon: const Icon(Icons.notifications_active_outlined, size: 17),
              label: Text(widget.strings.call('grantNotificationPermission')),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
    ],
    SectionHeading(
      title: widget.strings.call('scheduledCalls'),
      subtitle: widget.strings.call('remindersLocalHint'),
    ),
    const SizedBox(height: 11),
    if (_loading)
      const Center(child: CircularProgressIndicator())
    else if (_reminders.isEmpty)
      EmptyState(label: widget.strings.call('noReminders'))
    else
      ..._reminders.map(
        (reminder) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ReminderCard(
            reminder: reminder,
            strings: widget.strings,
            dateLabel: _dateTimeLabel(reminder.remindAt),
            repeatLabel: _repeatLabel(reminder),
            onCall: () => _dialReminder(reminder.phone),
            onEditTime: () => _editReminderTime(reminder),
            onToggleDone: () => _toggleReminder(reminder),
            onDelete: () => _deleteReminder(reminder),
          ),
        ),
      ),
    const SizedBox(height: 2),
    FilledButton.icon(
      onPressed: _createReminder,
      icon: const Icon(Icons.add_rounded),
      label: Text(widget.strings.call('createReminder')),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(51),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    ),
  ];

  List<Widget> _journalContent() => [
    Row(
      children: [
        Expanded(
          child: SectionHeading(
            title: widget.strings.call('recentBlocks'),
            subtitle: widget.strings.call('journalDemoHint'),
          ),
        ),
        IconButton(
          tooltip: widget.strings.call('refresh'),
          onPressed: _reloadLogs,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    if (_logs.isNotEmpty)
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _confirmClearCallLogs,
          icon: const Icon(Icons.delete_sweep_outlined, size: 17),
          label: Text(widget.strings.call('clearJournal')),
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.accent(AppPalette.red),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    const SizedBox(height: 11),
    if (_loading)
      const Center(child: CircularProgressIndicator())
    else if (_logs.isEmpty)
      EmptyState(label: widget.strings.call('noLogs'))
    else
      ..._logs.map((entry) {
        final tint = switch (entry.reason) {
          'silent_schedule' => const Color(0xFF7663D9),
          'hidden_number' => AppPalette.amber,
          'country_block' ||
          'international_block' ||
          'blacklist' ||
          'short_number_block' => AppPalette.red,
          'operator_block' => const Color(0xFFE07A2E),
          'non_contacts' || 'not_in_contacts' => const Color(0xFFE07A2E),
          'allowlist_only' => const Color(0xFFE07A2E),
          'driving_mode' => AppPalette.red,
          'country_allow' ||
          'operator_allow' ||
          'allowlist' ||
          'emergency_repeat' ||
          'emergency_service' => AppPalette.green,
          _ => AppPalette.blue,
        };
        final icon = switch (entry.reason) {
          'silent_schedule' => Icons.notifications_off_outlined,
          'hidden_number' => Icons.visibility_off_outlined,
          'country_block' => Icons.public_rounded,
          'international_block' => Icons.language_rounded,
          'operator_block' => Icons.cell_tower_rounded,
          'non_contacts' || 'not_in_contacts' => Icons.person_off_outlined,
          'allowlist_only' => Icons.playlist_add_check_rounded,
          'driving_mode' => Icons.directions_car_rounded,
          'short_number_block' => Icons.dialpad_rounded,
          'country_allow' => Icons.public_rounded,
          'operator_allow' => Icons.cell_tower_rounded,
          'allowlist' => Icons.person_outline_rounded,
          'emergency_repeat' => Icons.phone_callback_rounded,
          'emergency_service' => Icons.emergency_rounded,
          'blacklist' => Icons.block_rounded,
          _ => Icons.check_circle_outline_rounded,
        };
        final canQuickAdd =
            _isBlockedReason(entry.reason) &&
            !entry.phone.startsWith('@') &&
            normalizePhoneNumber(entry.phone).isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: JournalCard(
            strings: widget.strings,
            phone: localizedValue(widget.strings, entry.phone),
            contactName: entry.contactName,
            caption: _dateTimeLabel(entry.timestamp),
            reason: localizedValue(widget.strings, entry.reason),
            tint: tint,
            pale: AppPalette.accentSurface(tint),
            icon: icon,
            onDelete: () => _deleteCallLog(entry),
            onAdd: canQuickAdd ? () => _quickAddFromLog(entry) : null,
            addLabel: canQuickAdd
                ? widget.strings.call('quickAddToList')
                : null,
          ),
        );
      }),
  ];
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/app_info_footnote.dart';
import '../widgets/common/dark_pill.dart';
import '../widgets/common/call_log_picker_sheet.dart';
import '../widgets/common/contact_picker.dart';
import '../widgets/common/icon_box.dart';
import '../widgets/common/localized_value.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/shield_phone_logo.dart';
import '../widgets/common/tag.dart';
import '../widgets/common/thin_divider.dart';
import '../widgets/system_call_permissions_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.database,
    required this.isActive,
    required this.strings,
    required this.protectionEnabled,
    required this.onProtectionChanged,
    required this.drivingMode,
    required this.onDrivingModeChanged,
    required this.blockUnknown,
    required this.onBlockUnknownChanged,
    required this.blockNonContacts,
    required this.onBlockNonContactsChanged,
    required this.blockInternational,
    required this.onBlockInternationalChanged,
    required this.blockShortNumbers,
    required this.onBlockShortNumbersChanged,
    required this.manualSilenceEnabled,
    required this.onManualSilenceChanged,
    required this.manualMessengerMute,
    required this.onManualMessengerMuteChanged,
    required this.onTest,
    required this.onSupport,
  });

  final DatabaseHelper database;
  final bool isActive;
  final AppStrings strings;
  final bool protectionEnabled;
  final ValueChanged<bool> onProtectionChanged;
  final bool drivingMode;
  final ValueChanged<bool> onDrivingModeChanged;
  final bool blockUnknown;
  final ValueChanged<bool> onBlockUnknownChanged;
  final bool blockNonContacts;
  final ValueChanged<bool> onBlockNonContactsChanged;
  final bool blockInternational;
  final ValueChanged<bool> onBlockInternationalChanged;
  final bool blockShortNumbers;
  final ValueChanged<bool> onBlockShortNumbersChanged;
  final bool manualSilenceEnabled;
  final ValueChanged<bool> onManualSilenceChanged;
  final bool manualMessengerMute;
  final ValueChanged<bool> onManualMessengerMuteChanged;
  final VoidCallback onTest;
  final VoidCallback onSupport;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _screeningChannel = CallScreeningChannel();
  List<Map<String, Object?>> _temporaryRules = [];
  Timer? _temporaryRulesTimer;
  bool _dndPolicyAccessGranted = false;
  bool _pendingMessengerMuteEnable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reloadTemporaryRules());
    unawaited(_refreshDndPolicyAccess());
    _temporaryRulesTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (widget.isActive &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_reloadTemporaryRules());
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_reloadTemporaryRules());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.isActive) unawaited(_reloadTemporaryRules());
      unawaited(_refreshDndPolicyAccess());
    }
  }

  Future<void> _refreshDndPolicyAccess() async {
    var granted = false;
    try {
      granted = await _screeningChannel.isDndPolicyAccessGranted();
    } on PlatformException {
      // Do Not Disturb access is an optional Android policy permission.
    } on MissingPluginException {
      // The quick mute remains available on platforms without Android APIs.
    }
    if (!mounted) return;
    final enablePendingMute = granted && _pendingMessengerMuteEnable;
    setState(() {
      _dndPolicyAccessGranted = granted;
      if (_pendingMessengerMuteEnable) _pendingMessengerMuteEnable = false;
    });
    if (enablePendingMute) {
      widget.onManualMessengerMuteChanged(true);
    } else if (granted && widget.manualMessengerMute) {
      try {
        await _screeningChannel.syncDndState();
      } on PlatformException {
        // DND synchronization is retried after another mode change.
      } on MissingPluginException {
        // System DND is only available through the Android bridge.
      }
    }
  }

  Future<void> _openDndPolicyAccessSettings() async {
    try {
      await _screeningChannel.openDndPolicyAccessSettings();
    } on PlatformException {
      // The system access page is optional and Android-specific.
    } on MissingPluginException {
      // Keep the home screen usable without the Android method channel.
    }
  }

  Future<void> _changeManualMessengerMute(bool enabled) async {
    if (!enabled) {
      widget.onManualMessengerMuteChanged(false);
      return;
    }

    var granted = false;
    try {
      granted = await _screeningChannel.isDndPolicyAccessGranted();
    } on PlatformException {
      // Fall through to the explanatory permission dialog.
    } on MissingPluginException {
      // Fall through to the explanatory permission dialog.
    }
    if (!mounted) return;
    setState(() => _dndPolicyAccessGranted = granted);
    if (granted) {
      widget.onManualMessengerMuteChanged(true);
      return;
    }

    setState(() => _pendingMessengerMuteEnable = true);
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(widget.strings.call('dndSyncTitle')),
        content: Text(widget.strings.call('dndAccessWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(widget.strings.call('closeLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(widget.strings.call('dndGrantAccess')),
          ),
        ],
      ),
    );

    if (openSettings == true) {
      try {
        final opened = await _screeningChannel.openDndPolicyAccessSettings();
        if (!opened && mounted) {
          setState(() => _pendingMessengerMuteEnable = false);
        }
      } on PlatformException {
        if (mounted) setState(() => _pendingMessengerMuteEnable = false);
      } on MissingPluginException {
        if (mounted) setState(() => _pendingMessengerMuteEnable = false);
      }
    } else if (mounted) {
      setState(() => _pendingMessengerMuteEnable = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _temporaryRulesTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadTemporaryRules() async {
    final rows = await widget.database.getActiveTemporaryPhoneRules();
    var contactsGranted = false;
    if (rows.any(
      (row) =>
          (row['label'] as String? ?? '').isEmpty ||
          row['label'] == '@newNumber',
    )) {
      try {
        contactsGranted =
            (await _screeningChannel.checkPermissions()).readContacts;
      } on PlatformException {
        // Contact names are an optional enhancement for local temporary rules.
      } on MissingPluginException {
        // Temporary rules remain available outside Android.
      }
    }
    final rules = <Map<String, Object?>>[];
    for (final row in rows) {
      var contactName = '';
      final label = row['label'] as String? ?? '';
      if (contactsGranted && (label.isEmpty || label == '@newNumber')) {
        try {
          contactName =
              await _screeningChannel.lookupContactName(
                row['phone'] as String,
              ) ??
              '';
        } on PlatformException {
          // Keep displaying the number if the contact provider is unavailable.
        } on MissingPluginException {
          // Contact resolution is only implemented by the Android bridge.
        }
      }
      rules.add({...row, 'resolved_contact_name': contactName});
    }
    if (!mounted) return;
    setState(() => _temporaryRules = rules);
  }

  String _remainingTime(int expiresAt) {
    final remaining = Duration(
      milliseconds: expiresAt - DateTime.now().millisecondsSinceEpoch,
    );
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;
    final labels = <String>[];
    if (days > 0) {
      labels.add('$days ${widget.strings.call('durationDaysShort')}');
    }
    if (hours > 0 || days > 0) {
      labels.add('$hours ${widget.strings.call('durationHoursShort')}');
    }
    if (days == 0 && minutes > 0) {
      labels.add('$minutes ${widget.strings.call('durationMinutesShort')}');
    }
    if (labels.isEmpty)
      labels.add('1 ${widget.strings.call('durationMinutesShort')}');
    return labels.join(' ');
  }

  String _dateTimeLabel(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date).format(context)}';

  Future<void> _addTemporaryRule() async {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    var listType = 'white';
    var selectedPeriod = 'oneHour';
    var expiresAt = DateTime.now().add(const Duration(hours: 1));
    final now = DateTime.now();

    Future<void> selectCustomExpiry(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final date = await showDatePicker(
        context: dialogContext,
        initialDate: DateTime.now().add(const Duration(hours: 1)),
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(now.year + 5),
      );
      if (date == null || !dialogContext.mounted) return;
      final time = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.fromDateTime(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      if (time == null || !dialogContext.mounted) return;
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!selected.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(widget.strings.call('temporaryDateMustBeFuture')),
            ),
          );
        return;
      }
      setDialogState(() {
        selectedPeriod = 'custom';
        expiresAt = selected;
      });
    }

    final draft = await showDialog<_TemporaryRuleDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(Icons.hourglass_bottom_rounded),
          title: Text(widget.strings.call('temporaryRuleDialogTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('phoneNumber'),
                    hintText: widget.strings.call('phoneNumberHint'),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                _numberSourceButtons(
                  dialogContext: dialogContext,
                  phoneController: phoneController,
                  nameController: nameController,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('optionalName'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.strings.call('temporaryActionLabel'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'white',
                      label: Text(widget.strings.call('temporaryAllowAction')),
                    ),
                    ButtonSegment(
                      value: 'black',
                      label: Text(widget.strings.call('temporaryBlockAction')),
                    ),
                  ],
                  selected: {listType},
                  onSelectionChanged: (selected) {
                    if (selected.isNotEmpty) {
                      setDialogState(() => listType = selected.first);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  widget.strings.call('temporaryPeriodLabel'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _periodChip(
                      context: context,
                      label: widget.strings.call('temporaryOneHour'),
                      period: 'oneHour',
                      duration: const Duration(hours: 1),
                      selectedPeriod: selectedPeriod,
                      onSelect: (period, duration) => setDialogState(() {
                        selectedPeriod = period;
                        expiresAt = DateTime.now().add(duration);
                      }),
                    ),
                    _periodChip(
                      context: context,
                      label: widget.strings.call('temporaryThreeHours'),
                      period: 'threeHours',
                      duration: const Duration(hours: 3),
                      selectedPeriod: selectedPeriod,
                      onSelect: (period, duration) => setDialogState(() {
                        selectedPeriod = period;
                        expiresAt = DateTime.now().add(duration);
                      }),
                    ),
                    _periodChip(
                      context: context,
                      label: widget.strings.call('temporary24Hours'),
                      period: 'oneDay',
                      duration: const Duration(hours: 24),
                      selectedPeriod: selectedPeriod,
                      onSelect: (period, duration) => setDialogState(() {
                        selectedPeriod = period;
                        expiresAt = DateTime.now().add(duration);
                      }),
                    ),
                    _periodChip(
                      context: context,
                      label: widget.strings.call('temporarySevenDays'),
                      period: 'sevenDays',
                      duration: const Duration(days: 7),
                      selectedPeriod: selectedPeriod,
                      onSelect: (period, duration) => setDialogState(() {
                        selectedPeriod = period;
                        expiresAt = DateTime.now().add(duration);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () =>
                      selectCustomExpiry(dialogContext, setDialogState),
                  icon: const Icon(Icons.event_outlined, size: 17),
                  label: Text(
                    selectedPeriod == 'custom'
                        ? widget.strings
                              .call('temporaryUntil')
                              .replaceAll('{time}', _dateTimeLabel(expiresAt))
                        : widget.strings.call('temporaryChooseDateTime'),
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
                  _TemporaryRuleDraft(
                    phone: phone,
                    name: nameController.text.trim(),
                    listType: listType,
                    expiresAt: expiresAt.millisecondsSinceEpoch,
                  ),
                );
              },
              child: Text(widget.strings.call('add')),
            ),
          ],
        ),
      ),
    );
    phoneController.dispose();
    nameController.dispose();
    if (draft == null || !mounted) return;
    if (draft.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(widget.strings.call('temporaryDateMustBeFuture')),
          ),
        );
      return;
    }
    await widget.database.insertPhoneRule(
      phone: draft.phone,
      label: draft.name.isEmpty ? '@newNumber' : draft.name,
      listType: draft.listType,
      expiresAt: draft.expiresAt,
    );
    await _reloadTemporaryRules();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('temporaryRuleAdded'))),
      );
  }

  Widget _periodChip({
    required BuildContext context,
    required String label,
    required String period,
    required Duration duration,
    required String selectedPeriod,
    required void Function(String, Duration) onSelect,
  }) => ChoiceChip(
    label: Text(label),
    selected: selectedPeriod == period,
    onSelected: (_) => onSelect(period, duration),
    showCheckmark: false,
  );

  Widget _numberSourceButtons({
    required BuildContext dialogContext,
    required TextEditingController phoneController,
    required TextEditingController nameController,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final contact = await pickContactFromPhoneBook(
              context: dialogContext,
              strings: widget.strings,
              channel: _screeningChannel,
            );
            if (contact == null || !dialogContext.mounted) return;
            phoneController.text = contact.phone ?? '';
            nameController.text = contact.name ?? '';
          },
          icon: const Icon(Icons.contacts_outlined, size: 16),
          label: Text(
            widget.strings.call('temporaryFromContacts'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () async {
            final selection = await showCallLogPickerSheet(
              context: dialogContext,
              strings: widget.strings,
              channel: _screeningChannel,
            );
            if (selection == null || !dialogContext.mounted) return;
            phoneController.text = selection.number;
            nameController.text = selection.name;
          },
          icon: const Icon(Icons.history_rounded, size: 16),
          label: Text(
            widget.strings.call('callHistoryPicker'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
    ],
  );

  Widget _temporaryRulesCard() {
    final rules = _temporaryRules;
    const accent = Color(0xFF7663D9);
    return AppPanel(
      color: Color.alphaBlend(
        accent.withValues(alpha: 0.07),
        AppPalette.surface,
      ),
      borderColor: AppPalette.accent(accent).withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconBox(
                  icon: Icons.hourglass_bottom_rounded,
                  color: accent,
                  background: AppPalette.accentSurface(accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.strings.call('temporaryRulesTitle'),
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (rules.isEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.strings.call('temporaryRulesDescription'),
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addTemporaryRule,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(widget.strings.call('temporaryAdd')),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (rules.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...rules.indexed.map((indexedRule) {
                final index = indexedRule.$1;
                final rule = indexedRule.$2;
                final white = rule['list_type'] == 'white';
                final color = white ? AppPalette.green : AppPalette.red;
                final label = rule['label'] as String? ?? '';
                final resolvedName =
                    rule['resolved_contact_name'] as String? ?? '';
                final title = label.isNotEmpty && label != '@newNumber'
                    ? localizedValue(widget.strings, label)
                    : resolvedName.isNotEmpty
                    ? resolvedName
                    : rule['phone'] as String;
                final expiresAt = rule['expires_at'] as int;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == rules.length - 1 ? 8 : 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: widget.strings.call('cancelTemporaryRule'),
                            onPressed: () => _removeTemporaryRule(rule),
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 32,
                              height: 32,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                      Text(
                        rule['phone'] as String,
                        style: TextStyle(color: AppPalette.muted, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Tag(
                        label:
                            '${widget.strings.call(white ? 'allowed' : 'blocked')} · '
                            '${widget.strings.call('temporaryRemaining').replaceAll('{time}', _remainingTime(expiresAt))}',
                        color: color,
                        background: AppPalette.accentSurface(color),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _removeTemporaryRule(Map<String, Object?> rule) async {
    final id = rule['id'] as int?;
    if (id == null) return;
    await widget.database.deletePhoneRule(id);
    await _reloadTemporaryRules();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.protectionEnabled
        ? AppPalette.green
        : AppPalette.amber;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        PageIntro(
          eyebrow: widget.strings.call('homeEyebrow'),
          title: widget.strings.homeTitle,
          subtitle: widget.strings.homeSubtitle,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppPalette.navy, Color(0xFF253F68)],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1D172744),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const DarkPill(
                    icon: Icons.auto_awesome_rounded,
                    label: 'CALL GATE',
                  ),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.55),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    widget.protectionEnabled
                        ? widget.strings.call('activeShort')
                        : widget.strings.call('pausedShort'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                widget.protectionEnabled
                    ? widget.strings.call('protectionActive')
                    : widget.strings.call('protectionPaused'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.protectionEnabled
                    ? widget.strings.call('filteringReady')
                    : widget.strings.call('filteringPaused'),
                style: const TextStyle(color: Color(0xFFC7D2E3), fontSize: 12),
              ),
              const SizedBox(height: 19),
              Container(
                padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 39,
                      height: 39,
                      child: Center(child: ShieldPhoneLogo(size: 39)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.protectionEnabled
                            ? widget.strings.call('filteringOn')
                            : widget.strings.call('filteringOff'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: widget.protectionEnabled,
                      onChanged: widget.onProtectionChanged,
                      activeTrackColor: const Color(0xFF63D7A5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SystemCallPermissionsCard(strings: widget.strings),
        const SizedBox(height: 24),
        SectionHeading(
          title: widget.strings.quickRules,
          subtitle: widget.strings.quickSubtitle,
        ),
        const SizedBox(height: 11),
        AppPanel(
          child: Column(
            children: [
              RuleSwitch(
                icon: Icons.directions_car_rounded,
                title: widget.strings.call('drivingModeTitle'),
                subtitle: widget.strings.call('drivingModeSubtitle'),
                value: widget.drivingMode,
                onChanged: widget.onDrivingModeChanged,
                iconColor: const Color(0xFF2B6CB0),
                iconBackground: AppPalette.bluePale,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.notifications_off_outlined,
                title: widget.strings.call('manualSilenceTitle'),
                subtitle: widget.strings.call('manualSilenceSubtitle'),
                value: widget.manualSilenceEnabled,
                onChanged: widget.onManualSilenceChanged,
                iconColor: const Color(0xFF7663D9),
                iconBackground: AppPalette.accentSurface(
                  const Color(0xFF7663D9),
                ),
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.volume_off_rounded,
                title: widget.strings.call('manualMessengerMuteTitle'),
                subtitle: widget.strings.call('manualMessengerMuteSubtitle'),
                value: widget.manualMessengerMute,
                onChanged: _changeManualMessengerMute,
                iconColor: AppPalette.accent(AppPalette.blue),
                iconBackground: AppPalette.bluePale,
              ),
              if (widget.manualMessengerMute && !_dndPolicyAccessGranted) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(62, 0, 12, 4),
                  child: Text(
                    widget.strings.call('dndAccessWarning'),
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 58),
                    child: TextButton.icon(
                      onPressed: _openDndPolicyAccessSettings,
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      label: Text(widget.strings.call('dndGrantAccess')),
                    ),
                  ),
                ),
              ],
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.visibility_off_outlined,
                title: widget.strings.call('quickHiddenTitle'),
                subtitle: widget.strings.call('quickHiddenSubtitle'),
                value: widget.blockUnknown,
                onChanged: widget.onBlockUnknownChanged,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.person_off_outlined,
                title: widget.strings.call('quickNonContactsTitle'),
                subtitle: widget.strings.call('quickNonContactsSubtitle'),
                value: widget.blockNonContacts,
                onChanged: widget.onBlockNonContactsChanged,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.dialpad_rounded,
                title: widget.strings.call('quickShortNumbersTitle'),
                subtitle: widget.strings.call('quickShortNumbersSubtitle'),
                value: widget.blockShortNumbers,
                onChanged: widget.onBlockShortNumbersChanged,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.public_rounded,
                title: widget.strings.call('quickInternationalTitle'),
                subtitle: widget.strings.call('quickInternationalSubtitle'),
                value: widget.blockInternational,
                onChanged: widget.onBlockInternationalChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _temporaryRulesCard(),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: widget.onTest,
          icon: const Icon(Icons.science_outlined),
          label: Text(widget.strings.call('testCallButton')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: AppPalette.accent(AppPalette.blue),
            side: const BorderSide(color: Color(0xFFD9E1FF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 13),
        AppInfoFootnote(
          message: widget.strings.call('freeForeverMessage'),
          linkLabel: widget.strings.call('freeForeverSupportLink'),
          onSupport: widget.onSupport,
        ),
      ],
    );
  }
}

class _TemporaryRuleDraft {
  const _TemporaryRuleDraft({
    required this.phone,
    required this.name,
    required this.listType,
    required this.expiresAt,
  });

  final String phone;
  final String name;
  final String listType;
  final int expiresAt;
}

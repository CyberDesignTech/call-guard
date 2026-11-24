import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/protection_warning.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/time_button.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    required this.strings,
    required this.protectionEnabled,
    required this.automaticSilence,
    required this.onAutomaticSilenceChanged,
    required this.dndSyncEnabled,
    required this.onDndSyncEnabledChanged,
    required this.allowOnlyWhitelist,
    required this.onAllowOnlyWhitelistChanged,
    required this.startTime,
    required this.onStartTimeChanged,
    required this.endTime,
    required this.onEndTimeChanged,
    required this.selectedDays,
    required this.onSelectedDaysChanged,
  });

  final AppStrings strings;
  final bool protectionEnabled;
  final bool automaticSilence;
  final ValueChanged<bool> onAutomaticSilenceChanged;
  final bool dndSyncEnabled;
  final ValueChanged<bool> onDndSyncEnabledChanged;
  final bool allowOnlyWhitelist;
  final ValueChanged<bool> onAllowOnlyWhitelistChanged;
  final TimeOfDay startTime;
  final ValueChanged<TimeOfDay> onStartTimeChanged;
  final TimeOfDay endTime;
  final ValueChanged<TimeOfDay> onEndTimeChanged;
  final Set<int> selectedDays;
  final ValueChanged<Set<int>> onSelectedDaysChanged;

  @override
  State<SchedulePage> createState() => SchedulePageState();
}

class SchedulePageState extends State<SchedulePage>
    with WidgetsBindingObserver {
  final _protectionWarningKey = GlobalKey<ProtectionWarningState>();
  final _screeningChannel = CallScreeningChannel();
  bool _dndPolicyAccessGranted = false;

  bool get _scheduleSettingsEnabled =>
      widget.protectionEnabled && widget.automaticSilence;

  List<String> get _days => [
    widget.strings.call('dayMon'),
    widget.strings.call('dayTue'),
    widget.strings.call('dayWed'),
    widget.strings.call('dayThu'),
    widget.strings.call('dayFri'),
    widget.strings.call('daySat'),
    widget.strings.call('daySun'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshDndPolicyAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDndPolicyAccess();
  }

  Future<void> _refreshDndPolicyAccess() async {
    try {
      final granted = await _screeningChannel.isDndPolicyAccessGranted();
      if (!mounted) return;
      setState(() => _dndPolicyAccessGranted = granted);
      if (granted && widget.dndSyncEnabled) {
        await _screeningChannel.syncDndState();
      }
    } on PlatformException {
      // Do Not Disturb policy access is Android-specific.
    } on MissingPluginException {
      // Keep the schedule UI usable without the Android method channel.
    }
  }

  Future<void> _openDndPolicyAccessSettings() async {
    try {
      await _screeningChannel.openDndPolicyAccessSettings();
    } on PlatformException {
      // Permission access is optional; refresh when the app resumes.
    } on MissingPluginException {
      // System policy settings exist only on Android.
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? widget.startTime : widget.endTime,
      helpText: widget.strings.call(
        start ? 'timePickerStart' : 'timePickerEnd',
      ),
    );
    if (selected != null && mounted) {
      if (start) {
        widget.onStartTimeChanged(selected);
      } else {
        widget.onEndTimeChanged(selected);
      }
    }
  }

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        PageIntro(
          eyebrow: widget.strings.call('scheduleEyebrow'),
          title: widget.strings.scheduleTitle,
          subtitle: widget.strings.call('scheduleSubtitle'),
        ),
        if (!widget.protectionEnabled) ...[
          const SizedBox(height: 12),
          ProtectionWarning(
            key: _protectionWarningKey,
            containerKey: const ValueKey('schedule-protection-warning'),
            message: widget.strings.call('scheduleProtectionDisabledWarning'),
          ),
        ],
        const SizedBox(height: 18),
        AppPanel(
          child: RuleSwitch(
            icon: Icons.notifications_off_outlined,
            title: widget.strings.call('scheduleToggle'),
            subtitle: widget.strings.call(
              !widget.protectionEnabled
                  ? 'scheduleProtectionDisabledShort'
                  : widget.automaticSilence
                  ? 'scheduleActive'
                  : 'scheduleInactive',
            ),
            value: widget.automaticSilence,
            onChanged: widget.protectionEnabled
                ? widget.onAutomaticSilenceChanged
                : null,
            onDisabledTap: widget.protectionEnabled
                ? null
                : () => _protectionWarningKey.currentState?.highlight(),
            iconColor: const Color(0xFF7663D9),
            iconBackground: const Color(0xFFF0EDFF),
          ),
        ),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RuleSwitch(
                icon: Icons.do_not_disturb_on_outlined,
                title: widget.strings.call('dndSyncTitle'),
                subtitle: widget.strings.call('dndSyncDescription'),
                value: widget.dndSyncEnabled,
                onChanged: widget.onDndSyncEnabledChanged,
                iconColor: AppPalette.accent(AppPalette.blue),
                iconBackground: AppPalette.bluePale,
              ),
              if (widget.dndSyncEnabled && !_dndPolicyAccessGranted) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.strings.call('dndAccessWarning'),
                    style: TextStyle(color: AppPalette.muted, fontSize: 12),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _openDndPolicyAccessSettings,
                    icon: const Icon(Icons.settings_outlined, size: 17),
                    label: Text(widget.strings.call('dndGrantAccess')),
                  ),
                ),
              ],
            ],
          ),
        ),
        Opacity(
          opacity: _scheduleSettingsEnabled ? 1 : 0.45,
          child: AbsorbPointer(
            absorbing: !_scheduleSettingsEnabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                SectionHeading(
                  title: widget.strings.call('timeInterval'),
                  subtitle: widget.strings.call('timeTap'),
                ),
                const SizedBox(height: 10),
                AppPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TimeButton(
                            caption: widget.strings.call('timeStart'),
                            time: _timeLabel(widget.startTime),
                            icon: Icons.volume_off_outlined,
                            onTap: () => _pickTime(start: true),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppPalette.muted,
                            size: 18,
                          ),
                        ),
                        Expanded(
                          child: TimeButton(
                            caption: widget.strings.call('timeEnd'),
                            time: _timeLabel(widget.endTime),
                            icon: Icons.volume_up_outlined,
                            onTap: () => _pickTime(start: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 21),
                SectionHeading(
                  title: widget.strings.call('repeatDays'),
                  subtitle: widget.strings.call('repeatDaysHint'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 8,
                  children: List.generate(_days.length, (index) {
                    final day = index + 1;
                    final selected = widget.selectedDays.contains(day);
                    return ChoiceChip(
                      label: Text(_days[index]),
                      selected: selected,
                      onSelected: (value) {
                        final days = Set<int>.from(widget.selectedDays);
                        if (value) {
                          days.add(day);
                        } else {
                          days.remove(day);
                        }
                        widget.onSelectedDaysChanged(days);
                      },
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppPalette.accent(AppPalette.blue)
                            : AppPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                      backgroundColor: AppPalette.surface,
                      selectedColor: AppPalette.bluePale,
                      side: BorderSide(
                        color: selected
                            ? (AppPalette.isDark
                                  ? const Color(0xFF53658C)
                                  : const Color(0xFFD9E1FF))
                            : AppPalette.line,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                SectionHeading(
                  title: widget.strings.call('callRule'),
                  subtitle: widget.strings.call('callRuleHint'),
                ),
                const SizedBox(height: 10),
                AppPanel(
                  child: RuleSwitch(
                    icon: Icons.verified_user_outlined,
                    title: widget.strings.call('onlyAllowlist'),
                    subtitle: widget.strings.call('onlyAllowlistHint'),
                    value: widget.allowOnlyWhitelist,
                    onChanged: widget.onAllowOnlyWhitelistChanged,
                    iconColor: AppPalette.green,
                    iconBackground: AppPalette.greenPale,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

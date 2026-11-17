import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
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

class SchedulePageState extends State<SchedulePage> {
  final _protectionWarningKey = GlobalKey<ProtectionWarningState>();

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

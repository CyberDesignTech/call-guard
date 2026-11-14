import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/prototype_footnote.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/thin_divider.dart';

class AnsweringModePage extends StatelessWidget {
  const AnsweringModePage({
    required this.strings,
    required this.enabled,
    required this.onEnabledChanged,
    required this.scenario,
    required this.onScenarioChanged,
    required this.localNotification,
    required this.onLocalNotificationChanged,
  });

  final AppStrings strings;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final String scenario;
  final ValueChanged<String> onScenarioChanged;
  final bool localNotification;
  final ValueChanged<bool> onLocalNotificationChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
    children: [
      PageIntro(
        eyebrow: strings.call('answerEyebrow'),
        title: strings.answerTitle,
        subtitle: strings.call('answerSubtitle'),
      ),
      const SizedBox(height: 18),
      AppPanel(
        child: RuleSwitch(
          icon: Icons.phone_disabled_outlined,
          title: strings.call('answeringEnabledLabel'),
          subtitle: strings.call('answeringEnabledDescription'),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
      ),
      const SizedBox(height: 21),
      SectionHeading(
        title: strings.call('answeringScenarioTitle'),
        subtitle: strings.call('answeringScenarioHint'),
      ),
      const SizedBox(height: 10),
      AppPanel(
        child: RadioGroup<String>(
          groupValue: scenario,
          onChanged: (value) {
            if (value != null) onScenarioChanged(value);
          },
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'quiet_mode',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(strings.call('answeringQuietScenario')),
                secondary: const Icon(Icons.notifications_off_outlined),
                dense: true,
              ),
              const ThinDivider(),
              RadioListTile<String>(
                value: 'unknown_numbers',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text(strings.call('answeringUnknownScenario')),
                secondary: const Icon(Icons.person_search_outlined),
                dense: true,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      AppPanel(
        child: RuleSwitch(
          icon: Icons.notifications_active_outlined,
          title: strings.call('answeringNotificationLabel'),
          subtitle: strings.call('answeringNotificationHint'),
          value: localNotification,
          onChanged: onLocalNotificationChanged,
          iconColor: AppPalette.amber,
          iconBackground: AppPalette.amberPale,
        ),
      ),
      const SizedBox(height: 16),
      PrototypeFootnote(label: strings.call('prototypeFootnote')),
    ],
  );
}

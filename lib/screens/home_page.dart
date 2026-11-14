import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/dark_pill.dart';
import '../widgets/common/icon_box.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/prototype_footnote.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/shield_phone_logo.dart';
import '../widgets/common/thin_divider.dart';
import '../widgets/system_call_permissions_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.strings,
    required this.protectionEnabled,
    required this.onProtectionChanged,
    required this.blockUnknown,
    required this.onBlockUnknownChanged,
    required this.blockNonContacts,
    required this.onBlockNonContactsChanged,
    required this.blockInternational,
    required this.onBlockInternationalChanged,
    required this.automaticSilence,
    required this.manualSilenceEnabled,
    required this.onManualSilenceChanged,
    required this.onOpenSchedule,
    required this.onTest,
  });

  final AppStrings strings;
  final bool protectionEnabled;
  final ValueChanged<bool> onProtectionChanged;
  final bool blockUnknown;
  final ValueChanged<bool> onBlockUnknownChanged;
  final bool blockNonContacts;
  final ValueChanged<bool> onBlockNonContactsChanged;
  final bool blockInternational;
  final ValueChanged<bool> onBlockInternationalChanged;
  final bool automaticSilence;
  final bool manualSilenceEnabled;
  final ValueChanged<bool> onManualSilenceChanged;
  final VoidCallback onOpenSchedule;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final statusColor = protectionEnabled ? AppPalette.green : AppPalette.amber;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        PageIntro(
          eyebrow: strings.call('homeEyebrow'),
          title: strings.homeTitle,
          subtitle: strings.homeSubtitle,
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
                    label: 'CALL GUARD',
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
                    protectionEnabled
                        ? strings.call('activeShort')
                        : strings.call('pausedShort'),
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
                protectionEnabled
                    ? strings.call('protectionActive')
                    : strings.call('protectionPaused'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                protectionEnabled
                    ? strings.call('filteringReady')
                    : strings.call('filteringPaused'),
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
                        protectionEnabled
                            ? strings.call('filteringOn')
                            : strings.call('filteringOff'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: protectionEnabled,
                      onChanged: onProtectionChanged,
                      activeTrackColor: const Color(0xFF63D7A5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SystemCallPermissionsCard(strings: strings),
        const SizedBox(height: 14),
        AppPanel(
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: onOpenSchedule,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconBox(
                    icon: automaticSilence
                        ? Icons.notifications_off_outlined
                        : Icons.shield_outlined,
                    color: automaticSilence
                        ? const Color(0xFF7663D9)
                        : AppPalette.blue,
                    background: automaticSilence
                        ? AppPalette.accentSurface(const Color(0xFF7663D9))
                        : AppPalette.bluePale,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          automaticSilence
                              ? strings.call('silenceMode')
                              : strings.call('standardMode'),
                          style: TextStyle(
                            color: AppPalette.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          automaticSilence
                              ? strings.call('silenceDescription')
                              : strings.call('standardDescription'),
                          style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppPalette.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AppPanel(
          child: RuleSwitch(
            icon: Icons.notifications_off_outlined,
            title: strings.call('manualSilenceTitle'),
            subtitle: strings.call('manualSilenceSubtitle'),
            value: manualSilenceEnabled,
            onChanged: onManualSilenceChanged,
            iconColor: const Color(0xFF7663D9),
            iconBackground: AppPalette.accentSurface(const Color(0xFF7663D9)),
          ),
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: strings.quickRules,
          subtitle: strings.quickSubtitle,
        ),
        const SizedBox(height: 11),
        AppPanel(
          child: Column(
            children: [
              RuleSwitch(
                icon: Icons.visibility_off_outlined,
                title: strings.call('quickHiddenTitle'),
                subtitle: strings.call('quickHiddenSubtitle'),
                value: blockUnknown,
                onChanged: onBlockUnknownChanged,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.person_off_outlined,
                title: strings.call('quickNonContactsTitle'),
                subtitle: strings.call('quickNonContactsSubtitle'),
                value: blockNonContacts,
                onChanged: onBlockNonContactsChanged,
              ),
              const ThinDivider(),
              RuleSwitch(
                icon: Icons.public_rounded,
                title: strings.call('quickInternationalTitle'),
                subtitle: strings.call('quickInternationalSubtitle'),
                value: blockInternational,
                onChanged: onBlockInternationalChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onTest,
          icon: const Icon(Icons.science_outlined),
          label: Text(strings.call('testCallButton')),
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
        PrototypeFootnote(label: strings.call('prototypeFootnote')),
      ],
    );
  }
}

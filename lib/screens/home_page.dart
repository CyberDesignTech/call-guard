import 'dart:async';

import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../models/call_log_entry.dart';
import '../theme/app_palette.dart';
import '../widgets/common/app_panel.dart';
import '../widgets/common/app_info_footnote.dart';
import '../widgets/common/dark_pill.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/journal_card.dart';
import '../widgets/common/localized_value.dart';
import '../widgets/common/page_intro.dart';
import '../widgets/common/rule_switch.dart';
import '../widgets/common/section_heading.dart';
import '../widgets/common/shield_phone_logo.dart';
import '../widgets/common/thin_divider.dart';
import '../widgets/system_call_permissions_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.database,
    required this.isActive,
    required this.strings,
    required this.protectionEnabled,
    required this.onProtectionChanged,
    required this.blockUnknown,
    required this.onBlockUnknownChanged,
    required this.blockNonContacts,
    required this.onBlockNonContactsChanged,
    required this.blockInternational,
    required this.onBlockInternationalChanged,
    required this.manualSilenceEnabled,
    required this.onManualSilenceChanged,
    required this.onTest,
    required this.onSupport,
  });

  final DatabaseHelper database;
  final bool isActive;
  final AppStrings strings;
  final bool protectionEnabled;
  final ValueChanged<bool> onProtectionChanged;
  final bool blockUnknown;
  final ValueChanged<bool> onBlockUnknownChanged;
  final bool blockNonContacts;
  final ValueChanged<bool> onBlockNonContactsChanged;
  final bool blockInternational;
  final ValueChanged<bool> onBlockInternationalChanged;
  final bool manualSilenceEnabled;
  final ValueChanged<bool> onManualSilenceChanged;
  final VoidCallback onTest;
  final VoidCallback onSupport;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<CallLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reloadLogs());
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) unawaited(_reloadLogs());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_reloadLogs());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _reloadLogs() async {
    final rows = await widget.database.getCallLogs();
    if (!mounted) return;
    setState(() => _logs = rows.take(3).map(CallLogEntry.fromRow).toList());
  }

  String _dateTimeLabel(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final time = TimeOfDay.fromDateTime(date).format(context);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} · $time';
  }

  Color _reasonTint(String reason) => switch (reason) {
    'silent_schedule' => const Color(0xFF7663D9),
    'hidden_number' => AppPalette.amber,
    'country_block' || 'international_block' || 'blacklist' => AppPalette.red,
    'operator_block' ||
    'not_in_contacts' ||
    'allowlist_only' => const Color(0xFFE07A2E),
    _ => AppPalette.blue,
  };

  IconData _reasonIcon(String reason) => switch (reason) {
    'silent_schedule' => Icons.notifications_off_outlined,
    'hidden_number' => Icons.visibility_off_outlined,
    'country_block' => Icons.public_rounded,
    'international_block' => Icons.language_rounded,
    'operator_block' => Icons.cell_tower_rounded,
    'not_in_contacts' => Icons.person_off_outlined,
    'allowlist_only' => Icons.playlist_add_check_rounded,
    'blacklist' => Icons.block_rounded,
    _ => Icons.check_circle_outline_rounded,
  };

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
        SectionHeading(
          title: widget.strings.call('journalSegment'),
          subtitle: widget.strings.call('journalDemoHint'),
        ),
        const SizedBox(height: 11),
        if (_logs.isEmpty)
          AppPanel(child: EmptyState(label: widget.strings.call('noLogs')))
        else
          ..._logs.map((entry) {
            final tint = _reasonTint(entry.reason);
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
                icon: _reasonIcon(entry.reason),
              ),
            );
          }),
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

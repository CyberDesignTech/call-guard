import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../theme/app_palette.dart';
import '../screens/answering_page.dart';
import '../screens/home_page.dart';
import '../screens/lists_page.dart';
import '../screens/more_page.dart';
import '../screens/schedule_page.dart';
import '../widgets/common/shield_phone_logo.dart';
import '../widgets/profile_settings_sheet.dart';
import '../widgets/simulate_call_dialog.dart';
import '../widgets/support_project_dialog.dart';

enum AppSection { home, lists, schedule, answering, more }

class CallGuardShell extends StatefulWidget {
  const CallGuardShell({
    required this.database,
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
    required this.onAutomaticSilenceChanged,
    required this.allowOnlyWhitelist,
    required this.onAllowOnlyWhitelistChanged,
    required this.silenceStart,
    required this.onSilenceStartChanged,
    required this.silenceEnd,
    required this.onSilenceEndChanged,
    required this.silenceWeekdays,
    required this.onSilenceWeekdaysChanged,
    required this.answeringEnabled,
    required this.onAnsweringEnabledChanged,
    required this.answeringScenario,
    required this.onAnsweringScenarioChanged,
    required this.answeringLocalNotification,
    required this.onAnsweringLocalNotificationChanged,
    required this.answeringAutoRemind,
    required this.onAnsweringAutoRemindChanged,
    required this.answeringAutoRemindMinutes,
    required this.onAnsweringAutoRemindMinutesChanged,
    required this.answeringEmergencyRepeat,
    required this.onAnsweringEmergencyRepeatChanged,
    required this.openCallJournalRequest,
    required this.themeMode,
    required this.language,
    required this.strings,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
  });

  final DatabaseHelper database;
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
  final ValueChanged<bool> onAutomaticSilenceChanged;
  final bool allowOnlyWhitelist;
  final ValueChanged<bool> onAllowOnlyWhitelistChanged;
  final TimeOfDay silenceStart;
  final ValueChanged<TimeOfDay> onSilenceStartChanged;
  final TimeOfDay silenceEnd;
  final ValueChanged<TimeOfDay> onSilenceEndChanged;
  final Set<int> silenceWeekdays;
  final ValueChanged<Set<int>> onSilenceWeekdaysChanged;
  final bool answeringEnabled;
  final ValueChanged<bool> onAnsweringEnabledChanged;
  final String answeringScenario;
  final ValueChanged<String> onAnsweringScenarioChanged;
  final bool answeringLocalNotification;
  final ValueChanged<bool> onAnsweringLocalNotificationChanged;
  final bool answeringAutoRemind;
  final ValueChanged<bool> onAnsweringAutoRemindChanged;
  final int answeringAutoRemindMinutes;
  final ValueChanged<int> onAnsweringAutoRemindMinutesChanged;
  final bool answeringEmergencyRepeat;
  final ValueChanged<bool> onAnsweringEmergencyRepeatChanged;
  final int openCallJournalRequest;
  final ThemeMode themeMode;
  final AppLanguage language;
  final AppStrings strings;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<CallGuardShell> createState() => CallGuardShellState();
}

class CallGuardShellState extends State<CallGuardShell> {
  AppSection _section = AppSection.home;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    if (widget.openCallJournalRequest > 0) _section = AppSection.more;
    _pageController = PageController(initialPage: _section.index);
  }

  @override
  void didUpdateWidget(covariant CallGuardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openCallJournalRequest != widget.openCallJournalRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectSection(AppSection.more);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSection(AppSection section) {
    if (_section != section) {
      setState(() => _section = section);
    }
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round();
      if (currentPage == section.index) return;
      if (currentPage != null && (currentPage - section.index).abs() > 1) {
        _pageController.jumpToPage(section.index);
      } else {
        _pageController.animateToPage(
          section.index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _showStub() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('stubNotice'))),
      );
  }

  void _openTestDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => SimulateCallDialog(strings: widget.strings),
    );
  }

  void _openSupportDialog() {
    showSupportProjectDialog(context, widget.strings);
  }

  void _openProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ProfileSettingsSheet(
        language: widget.language,
        themeMode: widget.themeMode,
        strings: widget.strings,
        onLanguageChanged: widget.onLanguageChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(
          children: [
            const ShieldPhoneLogo(size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CALL GATE',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    widget.strings.call('appSlogan'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.strings.call('profileButton'),
            onPressed: _openProfileMenu,
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: AppPalette.bluePale,
              child: Icon(
                Icons.person_outline_rounded,
                color: AppPalette.accent(AppPalette.blue),
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          final section = AppSection.values[index];
          if (_section != section) setState(() => _section = section);
        },
        children: [
          HomePage(
            database: widget.database,
            isActive: _section == AppSection.home,
            strings: widget.strings,
            protectionEnabled: widget.protectionEnabled,
            onProtectionChanged: widget.onProtectionChanged,
            blockUnknown: widget.blockUnknown,
            onBlockUnknownChanged: widget.onBlockUnknownChanged,
            blockNonContacts: widget.blockNonContacts,
            onBlockNonContactsChanged: widget.onBlockNonContactsChanged,
            blockInternational: widget.blockInternational,
            onBlockInternationalChanged: widget.onBlockInternationalChanged,
            manualSilenceEnabled: widget.manualSilenceEnabled,
            onManualSilenceChanged: widget.onManualSilenceChanged,
            onTest: _openTestDialog,
            onSupport: _openSupportDialog,
          ),
          ListsPage(
            database: widget.database,
            onStub: _showStub,
            strings: widget.strings,
            isActive: _section == AppSection.lists,
            protectionEnabled: widget.protectionEnabled,
            onEdgeSwipe: (direction) => _selectSection(
              AppSection.values[AppSection.lists.index + direction],
            ),
          ),
          SchedulePage(
            strings: widget.strings,
            protectionEnabled: widget.protectionEnabled,
            automaticSilence: widget.automaticSilence,
            onAutomaticSilenceChanged: widget.onAutomaticSilenceChanged,
            allowOnlyWhitelist: widget.allowOnlyWhitelist,
            onAllowOnlyWhitelistChanged: widget.onAllowOnlyWhitelistChanged,
            startTime: widget.silenceStart,
            onStartTimeChanged: widget.onSilenceStartChanged,
            endTime: widget.silenceEnd,
            onEndTimeChanged: widget.onSilenceEndChanged,
            selectedDays: widget.silenceWeekdays,
            onSelectedDaysChanged: widget.onSilenceWeekdaysChanged,
          ),
          AnsweringModePage(
            strings: widget.strings,
            protectionEnabled: widget.protectionEnabled,
            enabled: widget.answeringEnabled,
            onEnabledChanged: widget.onAnsweringEnabledChanged,
            scenario: widget.answeringScenario,
            onScenarioChanged: widget.onAnsweringScenarioChanged,
            localNotification: widget.answeringLocalNotification,
            onLocalNotificationChanged:
                widget.onAnsweringLocalNotificationChanged,
            autoRemind: widget.answeringAutoRemind,
            onAutoRemindChanged: widget.onAnsweringAutoRemindChanged,
            autoRemindMinutes: widget.answeringAutoRemindMinutes,
            onAutoRemindMinutesChanged:
                widget.onAnsweringAutoRemindMinutesChanged,
            emergencyRepeat: widget.answeringEmergencyRepeat,
            onEmergencyRepeatChanged: widget.onAnsweringEmergencyRepeatChanged,
          ),
          MorePage(
            database: widget.database,
            onStub: _showStub,
            strings: widget.strings,
            isActive: _section == AppSection.more,
            journalOpenRequest: widget.openCallJournalRequest,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _section.index,
        onDestinationSelected: (index) =>
            _selectSection(AppSection.values[index]),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: widget.strings.homeNav,
            tooltip: widget.strings.homeTitle,
          ),
          NavigationDestination(
            icon: Icon(Icons.filter_alt_outlined),
            selectedIcon: Icon(Icons.filter_alt_rounded),
            label: widget.strings.listsNav,
            tooltip: widget.strings.listsScreenTitle,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.event_available_rounded),
            label: widget.strings.scheduleNav,
            tooltip: widget.strings.scheduleTitle,
          ),
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over_rounded),
            label: widget.strings.answerNav,
            tooltip: widget.strings.answerTitle,
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: widget.strings.moreNav,
            tooltip: widget.strings.moreTitle,
          ),
        ],
      ),
    );
  }
}

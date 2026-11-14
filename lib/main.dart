import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'data/database_helper.dart';
import 'l10n/app_strings.dart';

void main() => runApp(CallGuardApp());

abstract final class _Palette {
  static bool isDark = false;

  static Color get ink =>
      isDark ? const Color(0xFFF0F4FC) : const Color(0xFF17243B);
  static Color get muted =>
      isDark ? const Color(0xFFA2AEC2) : const Color(0xFF748198);
  static const blue = Color(0xFF4263EB);
  static Color get bluePale =>
      isDark ? const Color(0xFF273653) : const Color(0xFFEEF2FF);
  static const green = Color(0xFF15966A);
  static const greenPale = Color(0xFFE8F7F0);
  static const amber = Color(0xFFE29A27);
  static const amberPale = Color(0xFFFFF5E4);
  static const red = Color(0xFFD95757);
  static const redPale = Color(0xFFFFEEEE);
  static Color get canvas =>
      isDark ? const Color(0xFF101722) : const Color(0xFFF5F7FB);
  static Color get surface => isDark ? const Color(0xFF192434) : Colors.white;
  static Color get line =>
      isDark ? const Color(0xFF2B394E) : const Color(0xFFE8ECF3);
  static const navy = Color(0xFF172744);

  static Color accent(Color color) {
    if (!isDark) return color;
    if (color == green) return const Color(0xFF64D7A7);
    if (color == red) return const Color(0xFFFF9292);
    if (color == amber) return const Color(0xFFFFC96E);
    if (color == blue) return const Color(0xFFA8B9FF);
    if (color == const Color(0xFF7663D9)) return const Color(0xFFB7A8FF);
    return color;
  }

  static Color accentSurface(Color color) {
    if (!isDark) {
      if (color == green) return greenPale;
      if (color == red) return redPale;
      if (color == amber) return amberPale;
      if (color == blue) return bluePale;
      if (color == muted) return const Color(0xFFF0F2F6);
      return const Color(0xFFF0EDFF);
    }
    if (color == green) return const Color(0xFF1D3D34);
    if (color == red) return const Color(0xFF452B32);
    if (color == amber) return const Color(0xFF44371F);
    if (color == blue) return const Color(0xFF273653);
    if (color == muted) return const Color(0xFF293547);
    return const Color(0xFF342D50);
  }
}

class CallGuardApp extends StatefulWidget {
  CallGuardApp({super.key, DatabaseHelper? database})
    : database = database ?? DatabaseHelper.instance;

  final DatabaseHelper database;

  @override
  State<CallGuardApp> createState() => _CallGuardAppState();
}

class _CallGuardAppState extends State<CallGuardApp>
    with WidgetsBindingObserver {
  bool _ready = false;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.ukrainian;
  bool _protectionEnabled = true;
  bool _blockUnknown = true;
  bool _blockNonContacts = false;
  bool _blockInternational = true;
  bool _automaticSilence = false;
  bool _allowOnlyWhitelist = true;
  TimeOfDay _silenceStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _silenceEnd = const TimeOfDay(hour: 7, minute: 0);
  Set<int> _silenceWeekdays = {1, 2, 3, 4, 5, 6, 7};
  bool _autoReplyEnabled = false;
  int _autoReplyCondition = 0;
  int _greetingChoice = 0;
  bool _recordMessages = false;
  Future<void> _pendingSettingsWrites = Future<void>.value();
  List<Map<String, Object?>> _phoneRules = [];
  List<Map<String, Object?>> _countries = [];
  List<Map<String, Object?>> _operators = [];
  List<Map<String, Object?>> _reminders = [];
  List<Map<String, Object?>> _callLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system && _ready) setState(() {});
  }

  Future<void> _restoreSettings() async {
    try {
      await widget.database.initialize();
      final settings = await widget.database.getSettings();
      final whiteRules = await widget.database.getPhoneRules('white');
      final blackRules = await widget.database.getPhoneRules('black');
      final countries = await widget.database.getCountries();
      final operators = await widget.database.getAllOperators();
      final reminders = await widget.database.getReminders();
      final callLogs = await widget.database.getCallLogs();
      AppLanguage parseLanguage(String? value) =>
          AppLanguage.values
              .where((language) => language.name == value)
              .firstOrNull ??
          AppLanguage.ukrainian;
      ThemeMode parseTheme(String? value) =>
          ThemeMode.values.where((mode) => mode.name == value).firstOrNull ??
          ThemeMode.system;
      bool parseBool(String key, bool fallback) =>
          settings[key] == null ? fallback : settings[key] == 'true';
      int parseInt(String key, int fallback) =>
          int.tryParse(settings[key] ?? '') ?? fallback;
      final weekdays = (settings['silence_weekdays'] ?? '1,2,3,4,5,6,7')
          .split(',')
          .map(int.tryParse)
          .whereType<int>()
          .where((day) => day >= 1 && day <= 7)
          .toSet();

      if (!mounted) return;
      setState(() {
        _language = parseLanguage(settings['locale']);
        _themeMode = parseTheme(settings['theme_mode']);
        _protectionEnabled = parseBool('protection_enabled', true);
        _blockUnknown = parseBool('block_hidden', true);
        _blockNonContacts = parseBool('block_non_contacts', false);
        _blockInternational = parseBool('block_international', true);
        _automaticSilence = parseBool('automatic_silence', false);
        _allowOnlyWhitelist = parseBool('allow_only_whitelist', true);
        _silenceStart = _timeOfDay(parseInt('silence_start_minute', 1320));
        _silenceEnd = _timeOfDay(parseInt('silence_end_minute', 420));
        _silenceWeekdays = settings.containsKey('silence_weekdays')
            ? weekdays
            : {1, 2, 3, 4, 5, 6, 7};
        _autoReplyEnabled = parseBool('auto_reply_enabled', false);
        _autoReplyCondition = parseInt('auto_reply_condition', 0);
        _greetingChoice = parseInt('greeting_choice', 0);
        _recordMessages = parseBool('record_messages', false);
        _phoneRules = [...whiteRules, ...blackRules];
        _countries = countries;
        _operators = operators;
        _reminders = reminders;
        _callLogs = callLogs;
        _ready = true;
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Call Guard settings could not be restored: $error\n$stackTrace',
      );
      if (mounted) setState(() => _ready = true);
    }
  }

  TimeOfDay _timeOfDay(int minutes) => TimeOfDay(
    hour: (minutes ~/ 60).clamp(0, 23),
    minute: minutes.remainder(60).clamp(0, 59),
  );

  void _persistSetting(String key, Object value) {
    _pendingSettingsWrites = _pendingSettingsWrites
        .catchError((Object _) {})
        .then((_) => widget.database.setSetting(key, value));
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persistSetting('theme_mode', mode.name);
  }

  void _setLanguage(AppLanguage language) {
    setState(() => _language = language);
    _persistSetting('locale', language.name);
  }

  void _setSilenceStart(TimeOfDay value) {
    setState(() => _silenceStart = value);
    _persistSetting('silence_start_minute', value.hour * 60 + value.minute);
  }

  void _setSilenceEnd(TimeOfDay value) {
    setState(() => _silenceEnd = value);
    _persistSetting('silence_end_minute', value.hour * 60 + value.minute);
  }

  void _setSilenceWeekdays(Set<int> value) {
    setState(() => _silenceWeekdays = value);
    final days = value.toList()..sort();
    _persistSetting('silence_weekdays', days.join(','));
  }

  void _setAutoReplyCondition(int value) {
    setState(() => _autoReplyCondition = value);
    _persistSetting('auto_reply_condition', value);
  }

  void _setGreetingChoice(int value) {
    setState(() => _greetingChoice = value);
    _persistSetting('greeting_choice', value);
  }

  ThemeData _themeFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final canvas = isDark ? const Color(0xFF101722) : const Color(0xFFF5F7FB);
    final surface = isDark ? const Color(0xFF192434) : Colors.white;
    final ink = isDark ? const Color(0xFFF0F4FC) : const Color(0xFF17243B);
    final primary = isDark ? const Color(0xFFA8B9FF) : const Color(0xFF4263EB);
    final line = isDark ? const Color(0xFF2B394E) : const Color(0xFFE8ECF3);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF4263EB),
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: isDark ? const Color(0xFF17243B) : Colors.white,
          surface: surface,
          onSurface: ink,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF29384D)
            : const Color(0xFF17243B),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _Palette.isDark = switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    final strings = AppStrings(_language);
    return MaterialApp(
      title: 'Call Guard',
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: _themeMode,
      theme: _themeFor(Brightness.light),
      darkTheme: _themeFor(Brightness.dark),
      home: !_ready
          ? Scaffold(body: const Center(child: ShieldPhoneLogo(size: 72)))
          : _CallGuardShell(
              database: widget.database,
              protectionEnabled: _protectionEnabled,
              onProtectionChanged: (value) {
                setState(() => _protectionEnabled = value);
                _persistSetting('protection_enabled', value);
              },
              blockUnknown: _blockUnknown,
              onBlockUnknownChanged: (value) {
                setState(() => _blockUnknown = value);
                _persistSetting('block_hidden', value);
              },
              blockNonContacts: _blockNonContacts,
              onBlockNonContactsChanged: (value) {
                setState(() => _blockNonContacts = value);
                _persistSetting('block_non_contacts', value);
              },
              blockInternational: _blockInternational,
              onBlockInternationalChanged: (value) {
                setState(() => _blockInternational = value);
                _persistSetting('block_international', value);
              },
              automaticSilence: _automaticSilence,
              onAutomaticSilenceChanged: (value) {
                setState(() => _automaticSilence = value);
                _persistSetting('automatic_silence', value);
              },
              allowOnlyWhitelist: _allowOnlyWhitelist,
              onAllowOnlyWhitelistChanged: (value) {
                setState(() => _allowOnlyWhitelist = value);
                _persistSetting('allow_only_whitelist', value);
              },
              silenceStart: _silenceStart,
              onSilenceStartChanged: _setSilenceStart,
              silenceEnd: _silenceEnd,
              onSilenceEndChanged: _setSilenceEnd,
              silenceWeekdays: _silenceWeekdays,
              onSilenceWeekdaysChanged: _setSilenceWeekdays,
              autoReplyEnabled: _autoReplyEnabled,
              onAutoReplyEnabledChanged: (value) {
                setState(() => _autoReplyEnabled = value);
                _persistSetting('auto_reply_enabled', value);
              },
              autoReplyCondition: _autoReplyCondition,
              onAutoReplyConditionChanged: _setAutoReplyCondition,
              greetingChoice: _greetingChoice,
              onGreetingChoiceChanged: _setGreetingChoice,
              recordMessages: _recordMessages,
              onRecordMessagesChanged: (value) {
                setState(() => _recordMessages = value);
                _persistSetting('record_messages', value);
              },
              phoneRules: _phoneRules,
              countries: _countries,
              operators: _operators,
              reminders: _reminders,
              callLogs: _callLogs,
              themeMode: _themeMode,
              language: _language,
              strings: strings,
              onThemeModeChanged: _setThemeMode,
              onLanguageChanged: _setLanguage,
            ),
    );
  }
}

class _CallGuardShell extends StatefulWidget {
  const _CallGuardShell({
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
    required this.onAutomaticSilenceChanged,
    required this.allowOnlyWhitelist,
    required this.onAllowOnlyWhitelistChanged,
    required this.silenceStart,
    required this.onSilenceStartChanged,
    required this.silenceEnd,
    required this.onSilenceEndChanged,
    required this.silenceWeekdays,
    required this.onSilenceWeekdaysChanged,
    required this.autoReplyEnabled,
    required this.onAutoReplyEnabledChanged,
    required this.autoReplyCondition,
    required this.onAutoReplyConditionChanged,
    required this.greetingChoice,
    required this.onGreetingChoiceChanged,
    required this.recordMessages,
    required this.onRecordMessagesChanged,
    required this.phoneRules,
    required this.countries,
    required this.operators,
    required this.reminders,
    required this.callLogs,
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
  final ValueChanged<bool> onAutomaticSilenceChanged;
  final bool allowOnlyWhitelist;
  final ValueChanged<bool> onAllowOnlyWhitelistChanged;
  final TimeOfDay silenceStart;
  final ValueChanged<TimeOfDay> onSilenceStartChanged;
  final TimeOfDay silenceEnd;
  final ValueChanged<TimeOfDay> onSilenceEndChanged;
  final Set<int> silenceWeekdays;
  final ValueChanged<Set<int>> onSilenceWeekdaysChanged;
  final bool autoReplyEnabled;
  final ValueChanged<bool> onAutoReplyEnabledChanged;
  final int autoReplyCondition;
  final ValueChanged<int> onAutoReplyConditionChanged;
  final int greetingChoice;
  final ValueChanged<int> onGreetingChoiceChanged;
  final bool recordMessages;
  final ValueChanged<bool> onRecordMessagesChanged;
  final List<Map<String, Object?>> phoneRules;
  final List<Map<String, Object?>> countries;
  final List<Map<String, Object?>> operators;
  final List<Map<String, Object?>> reminders;
  final List<Map<String, Object?>> callLogs;
  final ThemeMode themeMode;
  final AppLanguage language;
  final AppStrings strings;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<_CallGuardShell> createState() => _CallGuardShellState();
}

class _CallGuardShellState extends State<_CallGuardShell> {
  int _selectedIndex = 0;

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
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.science_outlined,
          color: _Palette.accent(_Palette.blue),
        ),
        title: Text(widget.strings.call('testTitle')),
        content: Text(widget.strings.call('testBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('closeLabel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showStub();
            },
            child: Text(widget.strings.call('testRuleButton')),
          ),
        ],
      ),
    );
  }

  void _openProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ProfileSettingsSheet(
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
    final sectionTitles = [
      widget.strings.homeTitle,
      widget.strings.listsScreenTitle,
      widget.strings.scheduleTitle,
      widget.strings.answerTitle,
      widget.strings.moreTitle,
    ];
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
                    'CALL GUARD',
                    style: TextStyle(
                      color: _Palette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    sectionTitles[_selectedIndex].toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _Palette.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.05,
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
              backgroundColor: _Palette.bluePale,
              child: Icon(
                Icons.person_outline_rounded,
                color: _Palette.accent(_Palette.blue),
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: switch (_selectedIndex) {
        0 => _HomePage(
          strings: widget.strings,
          protectionEnabled: widget.protectionEnabled,
          onProtectionChanged: widget.onProtectionChanged,
          blockUnknown: widget.blockUnknown,
          onBlockUnknownChanged: widget.onBlockUnknownChanged,
          blockNonContacts: widget.blockNonContacts,
          onBlockNonContactsChanged: widget.onBlockNonContactsChanged,
          blockInternational: widget.blockInternational,
          onBlockInternationalChanged: widget.onBlockInternationalChanged,
          automaticSilence: widget.automaticSilence,
          onOpenSchedule: () => setState(() => _selectedIndex = 2),
          onTest: _openTestDialog,
        ),
        1 => _ListsPage(
          database: widget.database,
          onStub: _showStub,
          strings: widget.strings,
        ),
        2 => _SchedulePage(
          strings: widget.strings,
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
          onStub: _showStub,
        ),
        3 => _AutoReplyPage(
          onStub: _showStub,
          strings: widget.strings,
          enabled: widget.autoReplyEnabled,
          onEnabledChanged: widget.onAutoReplyEnabledChanged,
          condition: widget.autoReplyCondition,
          onConditionChanged: widget.onAutoReplyConditionChanged,
          greeting: widget.greetingChoice,
          onGreetingChanged: widget.onGreetingChoiceChanged,
          recordMessages: widget.recordMessages,
          onRecordMessagesChanged: widget.onRecordMessagesChanged,
        ),
        _ => _MorePage(
          database: widget.database,
          onStub: _showStub,
          strings: widget.strings,
        ),
      },
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
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

class _ProfileSettingsSheet extends StatefulWidget {
  const _ProfileSettingsSheet({
    required this.language,
    required this.themeMode,
    required this.strings,
    required this.onLanguageChanged,
    required this.onThemeModeChanged,
  });

  final AppLanguage language;
  final ThemeMode themeMode;
  final AppStrings strings;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_ProfileSettingsSheet> createState() => _ProfileSettingsSheetState();
}

class _ProfileSettingsSheetState extends State<_ProfileSettingsSheet> {
  late AppLanguage _language = widget.language;
  late ThemeMode _themeMode = widget.themeMode;

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const ShieldPhoneLogo(size: 76),
        title: const Text('Call Guard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.strings.call('versionLabel')}  v0.2.0-db',
              style: TextStyle(
                color: _Palette.accent(_Palette.blue),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.strings.call('aboutDescription'),
              textAlign: TextAlign.center,
              style: TextStyle(color: _Palette.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _Palette.bluePale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: _Palette.accent(_Palette.blue),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.strings.call('aboutPrivacy'),
                      style: TextStyle(color: _Palette.ink, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('closeLabel')),
          ),
        ],
      ),
    );
  }

  Future<void> _copyProjectLink(BuildContext dialogContext) async {
    await Clipboard.setData(
      const ClipboardData(
        text: 'https://github.com/CyberDesignTech/call-guard',
      ),
    );
    if (!mounted) return;
    Navigator.pop(dialogContext);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('linkCopied'))),
      );
  }

  void _showSupport() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.favorite_rounded,
          color: _Palette.accent(_Palette.red),
        ),
        title: Text(widget.strings.call('supportProject')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.strings.call('supportThanks'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _SupportOption(
                icon: Icons.coffee_outlined,
                title: widget.strings.call('supportCoffeeTitle'),
                description: widget.strings.call('supportCoffeeDescription'),
                color: _Palette.amber,
              ),
              const SizedBox(height: 10),
              _SupportOption(
                icon: Icons.share_outlined,
                title: widget.strings.call('supportShareTitle'),
                description: widget.strings.call('supportShareDescription'),
                color: _Palette.blue,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('closeLabel')),
          ),
          FilledButton.icon(
            onPressed: () => _copyProjectLink(dialogContext),
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: Text(widget.strings.call('copyLink')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_language);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: _Palette.bluePale,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: _Palette.accent(_Palette.blue),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.call('profileTitle'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.call('profileSubtitle'),
                          style: TextStyle(color: _Palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                strings.call('languageTitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              RadioGroup<AppLanguage>(
                groupValue: _language,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _language = value);
                  widget.onLanguageChanged(value);
                },
                child: Column(
                  children: AppLanguage.values
                      .map(
                        (language) => RadioListTile<AppLanguage>(
                          value: language,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _Palette.accent(_Palette.blue),
                          title: Text(
                            '${language.flag}  ${language.label}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const Divider(height: 22),
              Text(
                strings.call('themeTitle'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              RadioGroup<ThemeMode>(
                groupValue: _themeMode,
                onChanged: (mode) {
                  if (mode == null) return;
                  setState(() => _themeMode = mode);
                  widget.onThemeModeChanged(mode);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeSystem')),
                      secondary: const Icon(Icons.brightness_auto_outlined),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeLight')),
                      secondary: const Icon(Icons.light_mode_outlined),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.call('themeDark')),
                      secondary: const Icon(Icons.dark_mode_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _IconBox(
                  icon: Icons.info_outline_rounded,
                  color: _Palette.blue,
                  background: _Palette.bluePale,
                  size: 39,
                ),
                title: Text(
                  strings.call('aboutApp'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAbout,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _IconBox(
                  icon: Icons.favorite_outline_rounded,
                  color: _Palette.red,
                  background: _Palette.redPale,
                  size: 39,
                ),
                title: Text(
                  strings.call('supportProject'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showSupport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _Palette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _Palette.line),
    ),
    child: Row(
      children: [
        _IconBox(
          icon: icon,
          color: color,
          background: _Palette.accentSurface(color),
          size: 39,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(color: _Palette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({
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
  final VoidCallback onOpenSchedule;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final statusColor = protectionEnabled ? _Palette.green : _Palette.amber;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _PageIntro(
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
              colors: [_Palette.navy, Color(0xFF253F68)],
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
                  const _DarkPill(
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
        _Panel(
          child: InkWell(
            borderRadius: BorderRadius.circular(21),
            onTap: onOpenSchedule,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _IconBox(
                    icon: automaticSilence
                        ? Icons.notifications_off_outlined
                        : Icons.shield_outlined,
                    color: automaticSilence
                        ? const Color(0xFF7663D9)
                        : _Palette.blue,
                    background: automaticSilence
                        ? _Palette.accentSurface(const Color(0xFF7663D9))
                        : _Palette.bluePale,
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
                            color: _Palette.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          automaticSilence
                              ? strings.call('silenceDescription')
                              : strings.call('standardDescription'),
                          style: TextStyle(color: _Palette.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _Palette.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SectionHeading(
          title: strings.quickRules,
          subtitle: strings.quickSubtitle,
        ),
        const SizedBox(height: 11),
        _Panel(
          child: Column(
            children: [
              _RuleSwitch(
                icon: Icons.visibility_off_outlined,
                title: strings.call('quickHiddenTitle'),
                subtitle: strings.call('quickHiddenSubtitle'),
                value: blockUnknown,
                onChanged: onBlockUnknownChanged,
              ),
              const _ThinDivider(),
              _RuleSwitch(
                icon: Icons.person_off_outlined,
                title: strings.call('quickNonContactsTitle'),
                subtitle: strings.call('quickNonContactsSubtitle'),
                value: blockNonContacts,
                onChanged: onBlockNonContactsChanged,
              ),
              const _ThinDivider(),
              _RuleSwitch(
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
            foregroundColor: _Palette.accent(_Palette.blue),
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
        _PrototypeFootnote(label: strings.call('prototypeFootnote')),
      ],
    );
  }
}

class _ListsPage extends StatefulWidget {
  const _ListsPage({
    required this.database,
    required this.onStub,
    required this.strings,
  });

  final DatabaseHelper database;
  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<_ListsPage> {
  int _tab = 0;
  bool _loadingRules = true;
  final _countryPageKey = GlobalKey<_CountryOperatorsPageState>();
  List<_ListEntry> _whitelist = [];
  List<_ListEntry> _blacklist = [];

  @override
  void initState() {
    super.initState();
    _reloadRules();
  }

  Future<void> _reloadRules() async {
    final whiteRows = await widget.database.getPhoneRules('white');
    final blackRows = await widget.database.getPhoneRules('black');
    if (!mounted) return;
    setState(() {
      _whitelist = whiteRows.map(_entryFromRow).toList();
      _blacklist = blackRows.map(_entryFromRow).toList();
      _loadingRules = false;
    });
  }

  _ListEntry _entryFromRow(Map<String, Object?> row) {
    final rawLabel = row['label'] as String? ?? '';
    final isLocalizedKey = rawLabel.startsWith('@');
    final listType = row['list_type'] as String;
    final isWhite = listType == 'white';
    return _ListEntry(
      id: row['id'] as int,
      title: isLocalizedKey ? '' : rawLabel,
      titleKey: isLocalizedKey ? rawLabel.substring(1) : null,
      subtitle: row['phone'] as String,
      badge: '',
      badgeKey: isWhite ? 'allowed' : 'blocked',
      listType: listType,
      icon: isWhite ? Icons.person_outline : Icons.block_rounded,
      tint: isWhite ? _Palette.green : _Palette.red,
      pale: isWhite ? _Palette.greenPale : _Palette.redPale,
    );
  }

  Future<void> _addEntry() async {
    if (_tab == 2) {
      await _countryPageKey.currentState?.showAddChoiceDialog();
      return;
    }

    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    final result = await showDialog<_ListEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          _tab == 0
              ? Icons.person_add_alt_1_rounded
              : Icons.person_off_outlined,
          color: _Palette.blue,
        ),
        title: Text(
          _tab == 0 ? widget.strings.whiteListTab : widget.strings.blackListTab,
        ),
        content: Column(
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
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: widget.strings.call('optionalName'),
                hintText: widget.strings.call('nameExample'),
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
          ],
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
              final isWhite = _tab == 0;
              Navigator.pop(
                dialogContext,
                _ListEntry(
                  title: nameController.text.trim(),
                  titleKey: nameController.text.trim().isEmpty
                      ? 'newNumber'
                      : null,
                  subtitle: phone,
                  badge: '',
                  badgeKey: isWhite ? 'allowed' : 'blocked',
                  listType: isWhite ? 'white' : 'black',
                  icon: isWhite ? Icons.person_outline : Icons.block_rounded,
                  tint: isWhite ? _Palette.green : _Palette.red,
                  pale: isWhite ? _Palette.greenPale : _Palette.redPale,
                ),
              );
            },
            child: Text(widget.strings.call('save')),
          ),
        ],
      ),
    );
    phoneController.dispose();
    nameController.dispose();
    if (result != null && mounted) {
      await widget.database.insertPhoneRule(
        phone: result.subtitle,
        label: result.titleKey == null ? result.title : '@${result.titleKey}',
        listType: result.listType,
      );
      await _reloadRules();
    }
  }

  Future<void> _deleteEntry(_ListEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    await widget.database.deletePhoneRule(id);
    await _reloadRules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        tooltip: widget.strings.call(
          _tab == 2 ? 'addCountryTooltip' : 'addNumberTooltip',
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.strings.call('add')),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: _PageIntro(
                eyebrow: widget.strings.call('listsEyebrow'),
                title: widget.strings.listsScreenTitle,
                subtitle: widget.strings.call('listsSubtitle'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _Palette.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _Palette.line),
                ),
                child: TabBar(
                  onTap: (index) => setState(() => _tab = index),
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: _Palette.bluePale,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  labelColor: _Palette.accent(_Palette.blue),
                  unselectedLabelColor: _Palette.muted,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  tabs: [
                    Tab(
                      height: 50,
                      child: Text(
                        widget.strings.whiteListTab,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Text(
                        widget.strings.blackListTab,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Tab(
                      height: 50,
                      child: Text(
                        widget.strings.countryOperatorsTab,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _entryList(_whitelist, widget.strings.call('whiteListHint')),
                  _entryList(_blacklist, widget.strings.call('blackListHint')),
                  _CountryOperatorsPage(
                    key: _countryPageKey,
                    database: widget.database,
                    onStub: widget.onStub,
                    strings: widget.strings,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: _PrototypeFootnote(
                label: widget.strings.call('prototypeFootnote'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryList(List<_ListEntry> entries, String note) {
    if (_loadingRules) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 88),
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              note,
              style: TextStyle(color: _Palette.muted, fontSize: 11),
            ),
          );
        }
        final entry = entries[index - 1];
        return _EntryCard(
          entry: entry,
          strings: widget.strings,
          onDelete: () => _deleteEntry(entry),
        );
      },
    );
  }
}

enum _RuleState { neutral, allowed, blocked }

enum _CountryAddChoice { country, operator }

class _CountryEntry {
  _CountryEntry({
    required this.isoCode,
    required this.flag,
    required this.name,
    this.nameKey,
    required this.code,
    required this.operators,
    this.action = _RuleState.neutral,
  });

  final String isoCode;
  final String flag;
  final String name;
  final String? nameKey;
  final String code;
  final List<_OperatorEntry> operators;
  _RuleState action;
}

class _OperatorEntry {
  _OperatorEntry({
    this.id,
    required this.name,
    this.nameKey,
    required this.prefixes,
    this.action = _RuleState.neutral,
  });

  final int? id;
  final String name;
  final String? nameKey;
  final List<String> prefixes;
  _RuleState action;
}

class _OperatorDraft {
  const _OperatorDraft({required this.countryIso, required this.operator});

  final String countryIso;
  final _OperatorEntry operator;
}

class _CountryOperatorsPage extends StatefulWidget {
  const _CountryOperatorsPage({
    super.key,
    required this.database,
    required this.onStub,
    required this.strings,
  });

  final DatabaseHelper database;
  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_CountryOperatorsPage> createState() => _CountryOperatorsPageState();
}

class _CountryOperatorsPageState extends State<_CountryOperatorsPage> {
  String _query = '';
  final _searchController = TextEditingController();
  List<_CountryEntry> _countries = [];
  bool _loadingCountries = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final rows = await widget.database.getCountries();
    final countries = <_CountryEntry>[];
    for (final row in rows) {
      final isoCode = row['iso_code'] as String;
      final customName = row['custom_name'] as String?;
      final operatorRows = await widget.database.getOperators(isoCode);
      countries.add(
        _CountryEntry(
          isoCode: isoCode,
          flag: _flagForCountry(isoCode),
          name: customName ?? '',
          nameKey: customName == null ? row['name_key'] as String : null,
          code: row['dial_code'] as String,
          action: _ruleState(row['action'] as String),
          operators: operatorRows.map(_operatorFromRow).toList(),
        ),
      );
    }
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _loadingCountries = false;
    });
  }

  String _flagForCountry(String isoCode) => switch (isoCode) {
    'UA' => '🇺🇦',
    'PL' => '🇵🇱',
    'DE' => '🇩🇪',
    'GB' => '🇬🇧',
    'US-CA' => '🇺🇸🇨🇦',
    _ => '🌐',
  };

  _RuleState _ruleState(String value) => switch (value) {
    'allow' => _RuleState.allowed,
    'block' => _RuleState.blocked,
    _ => _RuleState.neutral,
  };

  String _storedRule(_RuleState value) => switch (value) {
    _RuleState.allowed => 'allow',
    _RuleState.blocked => 'block',
    _RuleState.neutral => 'neutral',
  };

  _OperatorEntry _operatorFromRow(Map<String, Object?> row) {
    final storedName = row['operator_name'] as String;
    final isLocalized = storedName.startsWith('@');
    return _OperatorEntry(
      id: row['id'] as int,
      name: isLocalized ? '' : storedName,
      nameKey: isLocalized ? storedName.substring(1) : null,
      prefixes: (row['prefixes'] as String)
          .split(',')
          .where((prefix) => prefix.isNotEmpty)
          .toList(),
      action: _ruleState(row['action'] as String),
    );
  }

  String _countryName(_CountryEntry country) => country.nameKey == null
      ? country.name
      : widget.strings.call(country.nameKey!);

  String _operatorName(_OperatorEntry operator) => operator.nameKey == null
      ? operator.name
      : widget.strings.call(operator.nameKey!);

  void _setCountryAction(_CountryEntry country, _RuleState value) {
    setState(() => country.action = value);
    unawaited(
      widget.database.updateCountryAction(country.isoCode, _storedRule(value)),
    );
  }

  void _setOperatorAction(_OperatorEntry operator, _RuleState value) {
    setState(() => operator.action = value);
    final id = operator.id;
    if (id != null) {
      unawaited(widget.database.updateOperatorAction(id, _storedRule(value)));
    }
  }

  String _countryAction(_RuleState state) =>
      widget.strings.call(switch (state) {
        _RuleState.neutral => 'countryDefault',
        _RuleState.allowed => 'countryAllowAll',
        _RuleState.blocked => 'countryBlockAll',
      });

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _countryActionShort(_RuleState state) =>
      widget.strings.call(switch (state) {
        _RuleState.neutral => 'countryDefaultShort',
        _RuleState.allowed => 'countryAllowedShort',
        _RuleState.blocked => 'countryBlockedShort',
      });

  String _operatorAction(_RuleState state) =>
      widget.strings.call(switch (state) {
        _RuleState.neutral => 'neutral',
        _RuleState.allowed => 'allowed',
        _RuleState.blocked => 'blocked',
      });

  Color _ruleColor(_RuleState state) => switch (state) {
    _RuleState.neutral => _Palette.muted,
    _RuleState.allowed => _Palette.green,
    _RuleState.blocked => _Palette.red,
  };

  Widget _ruleMenu({
    required _RuleState state,
    required bool country,
    required ValueChanged<_RuleState> onSelected,
  }) {
    final color = _ruleColor(state);
    return PopupMenuButton<_RuleState>(
      tooltip: widget.strings.call(
        country ? 'countryActionTooltip' : 'operatorActionTooltip',
      ),
      onSelected: onSelected,
      itemBuilder: (context) => _RuleState.values
          .map(
            (value) => PopupMenuItem(
              value: value,
              child: Text(
                country ? _countryAction(value) : _operatorAction(value),
              ),
            ),
          )
          .toList(),
      child: _Tag(
        label: country ? _countryActionShort(state) : _operatorAction(state),
        color: color,
        background: _Palette.accentSurface(color),
      ),
    );
  }

  Future<void> showAddChoiceDialog() async {
    final choice = await showDialog<_CountryAddChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.add_location_alt_outlined,
          color: _Palette.accent(_Palette.blue),
        ),
        title: Text(widget.strings.call('addFiltersTitle')),
        content: Text(widget.strings.call('addFiltersHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(widget.strings.call('cancel')),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _CountryAddChoice.country),
            icon: const Icon(Icons.flag_outlined),
            label: Text(widget.strings.call('addCountry')),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, _CountryAddChoice.operator),
            icon: const Icon(Icons.cell_tower_rounded),
            label: Text(widget.strings.call('addOperator')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == _CountryAddChoice.country) {
      await _showAddCountryDialog();
    } else if (choice == _CountryAddChoice.operator) {
      await _showAddOperatorDialog();
    }
  }

  Future<void> _showAddCountryDialog() async {
    final flagController = TextEditingController(text: '🌐');
    final nameController = TextEditingController();
    final codeController = TextEditingController(text: '+');
    var action = _RuleState.neutral;

    final country = await showDialog<_CountryEntry>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.flag_outlined,
            color: _Palette.accent(_Palette.blue),
          ),
          title: Text(widget.strings.call('addCountry')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextField(
                        controller: flagController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: widget.strings.call('flag'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: widget.strings.call('countryNameField'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('countryCodeField'),
                    hintText: '+380',
                    prefixIcon: Icon(Icons.public_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_RuleState>(
                  isExpanded: true,
                  initialValue: action,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('countryActionField'),
                  ),
                  items: _RuleState.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_countryAction(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => action = value);
                  },
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
                final name = nameController.text.trim();
                var code = codeController.text.trim();
                if (name.isEmpty || code.length < 2) return;
                if (!code.startsWith('+')) code = '+$code';
                Navigator.pop(
                  dialogContext,
                  _CountryEntry(
                    isoCode:
                        'X${code.replaceAll(RegExp(r'[^0-9]'), '')}-${DateTime.now().microsecondsSinceEpoch}',
                    flag: flagController.text.trim().isEmpty
                        ? '🌐'
                        : flagController.text.trim(),
                    name: name,
                    code: code,
                    operators: [],
                    action: action,
                  ),
                );
              },
              child: Text(widget.strings.call('add')),
            ),
          ],
        ),
      ),
    );

    flagController.dispose();
    nameController.dispose();
    codeController.dispose();
    if (country != null && mounted) {
      await widget.database.insertCountry(
        isoCode: country.isoCode,
        dialCode: country.code,
        nameKey: 'customCountry',
        customName: country.name,
        action: _storedRule(country.action),
      );
      await _loadCountries();
    }
  }

  Future<void> _showAddOperatorDialog() async {
    if (_countries.isEmpty) {
      widget.onStub();
      return;
    }
    final nameController = TextEditingController();
    final prefixesController = TextEditingController();
    var countryIso = _countries.first.isoCode;
    var action = _RuleState.neutral;

    final draft = await showDialog<_OperatorDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: Icon(
            Icons.cell_tower_rounded,
            color: _Palette.accent(_Palette.blue),
          ),
          title: Text(widget.strings.call('addOperator')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: countryIso,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorCountryField'),
                  ),
                  items: _countries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country.isoCode,
                          child: Text(
                            '${country.flag} ${_countryName(country)} ${country.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => countryIso = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorNameField'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prefixesController,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('prefixesField'),
                    hintText: widget.strings.call('prefixesHint'),
                    prefixIcon: Icon(Icons.numbers_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<_RuleState>(
                  isExpanded: true,
                  initialValue: action,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorActionField'),
                  ),
                  items: _RuleState.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_operatorAction(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => action = value);
                  },
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
                final name = nameController.text.trim();
                final prefixes = prefixesController.text
                    .split(',')
                    .map((prefix) => prefix.trim())
                    .where((prefix) => prefix.isNotEmpty)
                    .toList();
                if (name.isEmpty || prefixes.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _OperatorDraft(
                    countryIso: countryIso,
                    operator: _OperatorEntry(
                      name: name,
                      prefixes: prefixes,
                      action: action,
                    ),
                  ),
                );
              },
              child: Text(widget.strings.call('add')),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    prefixesController.dispose();
    if (draft != null && mounted) {
      await widget.database.insertOperator(
        countryIso: draft.countryIso,
        name: draft.operator.nameKey == null
            ? draft.operator.name
            : '@${draft.operator.nameKey}',
        prefixes: draft.operator.prefixes,
        action: _storedRule(draft.operator.action),
      );
      await _loadCountries();
    }
  }

  bool _matchesCountry(_CountryEntry country, String query) {
    final needle = query.toLowerCase();
    return _countryName(country).toLowerCase().contains(needle) ||
        country.code.toLowerCase().contains(needle) ||
        country.operators.any(
          (operator) =>
              _operatorName(operator).toLowerCase().contains(needle) ||
              operator.prefixes.any((prefix) => prefix.contains(needle)),
        );
  }

  Widget _countryCard(_CountryEntry country, String query) {
    final countryMatches =
        query.isEmpty ||
        _countryName(country).toLowerCase().contains(query.toLowerCase()) ||
        country.code.toLowerCase().contains(query.toLowerCase());
    final operators = countryMatches
        ? country.operators
        : country.operators
              .where(
                (operator) =>
                    operator.name.toLowerCase().contains(query.toLowerCase()) ||
                    operator.prefixes.any((prefix) => prefix.contains(query)),
              )
              .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: ExpansionTile(
          key: PageStorageKey('${country.code}-${country.name}'),
          leading: Text(country.flag, style: const TextStyle(fontSize: 23)),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _countryName(country),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              _ruleMenu(
                state: country.action,
                country: true,
                onSelected: (value) => _setCountryAction(country, value),
              ),
            ],
          ),
          subtitle: Text(
            '${country.code} · ${widget.strings.call('operatorCount').replaceAll('{count}', country.operators.length.toString())}',
            style: TextStyle(color: _Palette.muted, fontSize: 10),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
          children: operators.isEmpty
              ? [
                  if (country.operators.isEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.strings.call('operatorsEmpty'),
                        style: TextStyle(color: _Palette.muted, fontSize: 11),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.strings.call('operatorsSearchEmpty'),
                        style: TextStyle(color: _Palette.muted, fontSize: 11),
                      ),
                    ),
                ]
              : operators
                    .map((operator) => _operatorRow(country, operator))
                    .toList(),
        ),
      ),
    );
  }

  Widget _operatorRow(_CountryEntry country, _OperatorEntry operator) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 7, 9),
        decoration: BoxDecoration(
          color: _Palette.isDark
              ? const Color(0xFF202C3E)
              : const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _Palette.line),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cell_tower_rounded,
              color: _Palette.accent(_Palette.blue),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _operatorName(operator),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: operator.prefixes
                        .map(
                          (prefix) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _Palette.bluePale,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${country.code} $prefix',
                              style: TextStyle(
                                color: _Palette.accent(_Palette.blue),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            _ruleMenu(
              state: operator.action,
              country: false,
              onSelected: (value) => _setOperatorAction(operator, value),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final filtered = _countries
        .where((country) => query.isEmpty || _matchesCountry(country, query))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 88),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: widget.strings.call('countrySearchHint'),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: widget.strings.call('clearSearch'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingCountries)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          _Panel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                widget.strings.call('searchEmpty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: _Palette.muted, fontSize: 12),
              ),
            ),
          )
        else
          ...filtered.map((country) => _countryCard(country, query)),
      ],
    );
  }
}

class _ListEntry {
  const _ListEntry({
    required this.title,
    required this.subtitle,
    required this.badge,
    this.titleKey,
    this.badgeKey,
    this.id,
    this.listType = 'white',
    required this.icon,
    required this.tint,
    required this.pale,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String? titleKey;
  final String? badgeKey;
  final int? id;
  final String listType;
  final IconData icon;
  final Color tint;
  final Color pale;
}

class _SchedulePage extends StatefulWidget {
  const _SchedulePage({
    required this.strings,
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
    required this.onStub,
  });

  final AppStrings strings;
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
  final VoidCallback onStub;

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
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
        _PageIntro(
          eyebrow: widget.strings.call('scheduleEyebrow'),
          title: widget.strings.scheduleTitle,
          subtitle: widget.strings.call('scheduleSubtitle'),
        ),
        const SizedBox(height: 18),
        _Panel(
          child: _RuleSwitch(
            icon: Icons.notifications_off_outlined,
            title: widget.strings.call('scheduleToggle'),
            subtitle: widget.strings.call(
              widget.automaticSilence ? 'scheduleActive' : 'scheduleInactive',
            ),
            value: widget.automaticSilence,
            onChanged: widget.onAutomaticSilenceChanged,
            iconColor: const Color(0xFF7663D9),
            iconBackground: const Color(0xFFF0EDFF),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeading(
          title: widget.strings.call('timeInterval'),
          subtitle: widget.strings.call('timeTap'),
        ),
        const SizedBox(height: 10),
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    caption: widget.strings.call('timeStart'),
                    time: _timeLabel(widget.startTime),
                    icon: Icons.volume_off_outlined,
                    onTap: () => _pickTime(start: true),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: _Palette.muted,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: _TimeButton(
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
        _SectionHeading(
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
                    ? _Palette.accent(_Palette.blue)
                    : _Palette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              backgroundColor: _Palette.surface,
              selectedColor: _Palette.bluePale,
              side: BorderSide(
                color: selected
                    ? (_Palette.isDark
                          ? const Color(0xFF53658C)
                          : const Color(0xFFD9E1FF))
                    : _Palette.line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            );
          }),
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: widget.strings.call('callRule'),
          subtitle: widget.strings.call('callRuleHint'),
        ),
        const SizedBox(height: 10),
        _Panel(
          child: _RuleSwitch(
            icon: Icons.verified_user_outlined,
            title: widget.strings.call('onlyAllowlist'),
            subtitle: widget.strings.call('onlyAllowlistHint'),
            value: widget.allowOnlyWhitelist,
            onChanged: widget.onAllowOnlyWhitelistChanged,
            iconColor: _Palette.green,
            iconBackground: _Palette.greenPale,
          ),
        ),
        const SizedBox(height: 16),
        _PrototypeFootnote(label: widget.strings.call('prototypeFootnote')),
      ],
    );
  }
}

class _AutoReplyPage extends StatelessWidget {
  const _AutoReplyPage({
    required this.onStub,
    required this.strings,
    required this.enabled,
    required this.onEnabledChanged,
    required this.condition,
    required this.onConditionChanged,
    required this.greeting,
    required this.onGreetingChanged,
    required this.recordMessages,
    required this.onRecordMessagesChanged,
  });

  final VoidCallback onStub;
  final AppStrings strings;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final int condition;
  final ValueChanged<int> onConditionChanged;
  final int greeting;
  final ValueChanged<int> onGreetingChanged;
  final bool recordMessages;
  final ValueChanged<bool> onRecordMessagesChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _PageIntro(
          eyebrow: strings.call('answerEyebrow'),
          title: strings.answerTitle,
          subtitle: strings.call('answerSubtitle'),
        ),
        const SizedBox(height: 18),
        _Panel(
          child: _RuleSwitch(
            icon: Icons.record_voice_over_outlined,
            title: strings.call('autoReplyLabel'),
            subtitle: strings.call(enabled ? 'autoReplyOn' : 'autoReplyOff'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
        ),
        const SizedBox(height: 21),
        _SectionHeading(
          title: strings.call('answerWhen'),
          subtitle: strings.call('answerWhenHint'),
        ),
        const SizedBox(height: 10),
        _Panel(
          child: RadioGroup<int>(
            groupValue: condition,
            onChanged: (next) {
              if (next != null) onConditionChanged(next);
            },
            child: Column(
              children: [
                _radioOption(
                  0,
                  strings.call('whenBlocked'),
                  Icons.block_outlined,
                ),
                const _ThinDivider(),
                _radioOption(
                  1,
                  strings.call('whenSilence'),
                  Icons.notifications_off_outlined,
                ),
                const _ThinDivider(),
                _radioOption(
                  2,
                  strings.call('whenBusy'),
                  Icons.phone_in_talk_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 21),
        _SectionHeading(
          title: strings.call('greetings'),
          subtitle: strings.call('greetingsHint'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GreetingCard(
                icon: Icons.graphic_eq_rounded,
                title: strings.call('greetingStandard'),
                subtitle: strings.call('greetingSystem'),
                selected: greeting == 0,
                onTap: () => onGreetingChanged(0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GreetingCard(
                icon: Icons.audio_file_outlined,
                title: strings.call('greetingCustom'),
                subtitle: strings.call('greetingAudio'),
                selected: greeting == 1,
                onTap: () => onGreetingChanged(1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onStub,
          icon: const Icon(Icons.mic_none_rounded),
          label: Text(strings.call('recordVoice')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Panel(
          child: _RuleSwitch(
            icon: Icons.voicemail_rounded,
            title: strings.call('recordMessages'),
            subtitle: strings.call('recordMessagesHint'),
            value: recordMessages,
            onChanged: onRecordMessagesChanged,
            iconColor: _Palette.amber,
            iconBackground: _Palette.amberPale,
          ),
        ),
        const SizedBox(height: 16),
        _PrototypeFootnote(label: strings.call('prototypeFootnote')),
      ],
    );
  }

  Widget _radioOption(int value, String title, IconData icon) {
    return RadioListTile<int>(
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      activeColor: _Palette.accent(_Palette.blue),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      secondary: Icon(icon, color: _Palette.muted, size: 19),
      dense: true,
    );
  }
}

class _MorePage extends StatefulWidget {
  const _MorePage({
    required this.database,
    required this.onStub,
    required this.strings,
  });

  final DatabaseHelper database;
  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  int _segment = 0;
  List<_Reminder> _reminders = [];
  List<_CallLogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
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

  _Reminder _reminderFromRow(Map<String, Object?> row) => _Reminder(
    id: row['id'] as int,
    phone: row['phone'] as String,
    contactName: row['contact_name'] as String? ?? '',
    remindAt: row['remind_at'] as int,
    note: row['note'] as String? ?? '',
    isDone: (row['is_done'] as int? ?? 0) != 0,
  );

  _CallLogEntry _logFromRow(Map<String, Object?> row) => _CallLogEntry(
    id: row['id'] as int,
    phone: row['phone'] as String,
    reason: row['reason'] as String,
    timestamp: row['timestamp'] as int,
  );

  String _localizedOrRaw(String value) {
    if (value.startsWith('@')) return widget.strings.call(value.substring(1));
    if (AppStrings.keys.contains(value)) return widget.strings.call(value);
    return value;
  }

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

  Future<void> _toggleReminder(_Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;
    await widget.database.updateReminderDone(id, !reminder.isDone);
    await _reload();
  }

  Future<void> _deleteReminder(_Reminder reminder) async {
    final id = reminder.id;
    if (id == null) return;
    await widget.database.deleteReminder(id);
    await _reload();
  }

  Future<void> _addLogPhone(String phone) async {
    if (phone.startsWith('@')) {
      widget.onStub();
      return;
    }
    await widget.database.insertPhoneRule(
      phone: phone,
      label: null,
      listType: 'white',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(widget.strings.call('allowlistAdded'))),
      );
  }

  Future<void> _createReminder() async {
    final phoneController = TextEditingController();
    final noteController = TextEditingController();
    var selectedDate = DateTime.now().add(const Duration(days: 1));
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);

    final result = await showDialog<_Reminder>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          icon: const Icon(
            Icons.notifications_active_outlined,
            color: _Palette.blue,
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
                  _Reminder(
                    phone: phone,
                    contactName: '@reminderNew',
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
                  ),
                );
              },
              child: Text(widget.strings.call('create')),
            ),
          ],
        ),
      ),
    );

    phoneController.dispose();
    noteController.dispose();
    if (result != null && mounted) {
      await widget.database.insertReminder(
        phone: result.phone,
        contactName: result.contactName,
        remindAt: result.remindAt,
        note: result.note,
      );
      await _reload();
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _timeLabel(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _PageIntro(
          eyebrow: widget.strings.call('moreEyebrow'),
          title: widget.strings.moreTitle,
          subtitle: widget.strings.call('moreSubtitle'),
        ),
        const SizedBox(height: 17),
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
          onSelectionChanged: (selection) =>
              setState(() => _segment = selection.first),
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
        const SizedBox(height: 14),
        _PrototypeFootnote(label: widget.strings.call('prototypeFootnote')),
      ],
    );
  }

  List<Widget> _reminderContent() => [
    _SectionHeading(
      title: widget.strings.call('scheduledCalls'),
      subtitle: widget.strings.call('remindersDemoHint'),
    ),
    const SizedBox(height: 11),
    if (_loading)
      const Center(child: CircularProgressIndicator())
    else if (_reminders.isEmpty)
      _EmptyState(label: widget.strings.call('noReminders'))
    else
      ..._reminders.map(
        (reminder) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ReminderCard(
            reminder: reminder,
            strings: widget.strings,
            dateLabel: _dateTimeLabel(reminder.remindAt),
            onCall: widget.onStub,
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
    _SectionHeading(
      title: widget.strings.call('recentBlocks'),
      subtitle: widget.strings.call('journalDemoHint'),
    ),
    const SizedBox(height: 11),
    if (_loading)
      const Center(child: CircularProgressIndicator())
    else if (_logs.isEmpty)
      _EmptyState(label: widget.strings.call('noLogs'))
    else
      ..._logs.map((entry) {
        final tint = switch (entry.reason) {
          'reasonCountry' => _Palette.red,
          'reasonHidden' => _Palette.amber,
          'reasonSilence' => const Color(0xFF7663D9),
          _ => _Palette.blue,
        };
        final icon = switch (entry.reason) {
          'reasonCountry' => Icons.public_rounded,
          'reasonHidden' => Icons.visibility_off_outlined,
          'reasonSilence' => Icons.notifications_off_outlined,
          _ => Icons.block_rounded,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _JournalCard(
            phone: _localizedOrRaw(entry.phone),
            caption: _dateTimeLabel(entry.timestamp),
            reason: _localizedOrRaw(entry.reason),
            tint: tint,
            pale: _Palette.accentSurface(tint),
            icon: icon,
            onAdd: () => _addLogPhone(entry.phone),
            addLabel: widget.strings.call('addToAllowlist'),
          ),
        );
      }),
  ];
}

class _Reminder {
  const _Reminder({
    this.id,
    required this.phone,
    required this.contactName,
    required this.remindAt,
    required this.note,
    this.isDone = false,
  });

  final int? id;
  final String phone;
  final String contactName;
  final int remindAt;
  final String note;
  final bool isDone;
}

class _CallLogEntry {
  const _CallLogEntry({
    required this.id,
    required this.phone,
    required this.reason,
    required this.timestamp,
  });

  final int id;
  final String phone;
  final String reason;
  final int timestamp;
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.strings,
    required this.dateLabel,
    required this.onCall,
    required this.onToggleDone,
    required this.onDelete,
  });

  final _Reminder reminder;
  final AppStrings strings;
  final String dateLabel;
  final VoidCallback onCall;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;

  String _localizedOrRaw(String value) {
    if (value.startsWith('@')) return strings.call(value.substring(1));
    if (AppStrings.keys.contains(value)) return strings.call(value);
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBox(
                  icon: Icons.person_outline_rounded,
                  color: _Palette.accent(_Palette.blue),
                  background: _Palette.bluePale,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.contactName.isEmpty
                            ? strings.call('reminderNew')
                            : _localizedOrRaw(reminder.contactName),
                        style: TextStyle(
                          color: _Palette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reminder.phone,
                        style: TextStyle(color: _Palette.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: _Palette.accent(_Palette.blue),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    dateLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: _Palette.accent(_Palette.blue),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: _ThinDivider(),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    reminder.note.isEmpty
                        ? strings.call('reminderNewNote')
                        : _localizedOrRaw(reminder.note),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _Palette.muted, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: strings.call(
                    reminder.isDone ? 'restoreReminder' : 'markReminderDone',
                  ),
                  onPressed: onToggleDone,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 30,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    reminder.isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: reminder.isDone ? _Palette.green : _Palette.muted,
                    size: 18,
                  ),
                ),
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
                    color: _Palette.muted,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 3),
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
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: _Palette.muted, fontSize: 12),
      ),
    ),
  );
}

class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.phone,
    required this.caption,
    required this.reason,
    required this.tint,
    required this.pale,
    required this.icon,
    required this.onAdd,
    required this.addLabel,
  });

  final String phone;
  final String caption;
  final String reason;
  final Color tint;
  final Color pale;
  final IconData icon;
  final VoidCallback onAdd;
  final String addLabel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBox(icon: icon, color: tint, background: pale),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phone,
                        style: TextStyle(
                          color: _Palette.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        style: TextStyle(color: _Palette.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                _Tag(label: reason, color: tint, background: pale),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: Text(addLabel),
                style: TextButton.styleFrom(
                  foregroundColor: _Palette.accent(_Palette.blue),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.strings,
    required this.onDelete,
  });

  final _ListEntry entry;
  final AppStrings strings;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _IconBox(
              icon: entry.icon,
              color: entry.tint,
              background: entry.pale,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.titleKey == null
                        ? entry.title
                        : strings.call(entry.titleKey!),
                    style: TextStyle(
                      color: _Palette.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: TextStyle(color: _Palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _Tag(
              label: entry.badgeKey == null
                  ? entry.badge
                  : strings.call(entry.badgeKey!),
              color: entry.tint,
              background: entry.pale,
            ),
            const SizedBox(width: 3),
            IconButton(
              tooltip: strings.call('delete'),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 30, height: 36),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _Palette.muted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: TextStyle(
            color: _Palette.accent(_Palette.blue),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.25,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: TextStyle(
            color: _Palette.ink,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.65,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: _Palette.muted, fontSize: 12)),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _Palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(color: _Palette.muted, fontSize: 11)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _Palette.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2345),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: child),
    );
  }
}

class _RuleSwitch extends StatelessWidget {
  const _RuleSwitch({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.iconColor = _Palette.blue,
    this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
      secondary: _IconBox(
        icon: icon,
        color: iconColor,
        background: iconBackground ?? _Palette.bluePale,
        size: 39,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _Palette.ink,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: _Palette.muted, fontSize: 10),
      ),
      activeTrackColor: _Palette.green,
      dense: true,
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 65, endIndent: 14, color: _Palette.line);
}

class ShieldPhoneLogo extends StatelessWidget {
  const ShieldPhoneLogo({super.key, this.size = 42});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _ShieldPhonePainter());
  }
}

class _ShieldPhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(scale);

    final shield = Path()
      ..moveTo(50, 6)
      ..cubicTo(61, 13, 75, 16, 87, 18)
      ..lineTo(87, 47)
      ..cubicTo(87, 68, 71, 85, 50, 95)
      ..cubicTo(29, 85, 13, 68, 13, 47)
      ..lineTo(13, 18)
      ..cubicTo(25, 16, 39, 13, 50, 6)
      ..close();

    canvas.drawShadow(shield, const Color(0x66334FA8), 5, true);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF72A7FF), Color(0xFF19B6A3)],
        ).createShader(const Rect.fromLTWH(10, 6, 80, 90)),
    );
    final highlight = Path()
      ..moveTo(50, 15)
      ..cubicTo(58, 19, 67, 21, 76, 23);
    canvas.drawPath(
      highlight,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4,
    );

    final handset = Path()
      ..moveTo(34, 30)
      ..cubicTo(31, 29, 28, 31, 27, 34)
      ..lineTo(26, 39)
      ..cubicTo(29, 53, 43, 67, 57, 72)
      ..cubicTo(60, 73, 64, 71, 66, 68)
      ..lineTo(69, 63)
      ..cubicTo(70, 61, 69, 59, 67, 58)
      ..lineTo(60, 54)
      ..cubicTo(58, 53, 56, 54, 54, 56)
      ..lineTo(51, 59)
      ..cubicTo(45, 56, 40, 51, 37, 45)
      ..lineTo(41, 41)
      ..cubicTo(43, 39, 43, 37, 42, 35)
      ..lineTo(37, 31)
      ..cubicTo(36, 30, 35, 29, 34, 30)
      ..close();
    canvas.save();
    canvas.translate(50, 50);
    canvas.scale(1.2);
    canvas.translate(-50, -50);
    canvas.drawPath(handset, Paint()..color = Colors.white);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ShieldPhonePainter oldDelegate) => false;
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 43,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _Palette.isDark ? _Palette.accentSurface(color) : background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _Palette.accent(color), size: 20),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _Palette.isDark ? _Palette.accentSurface(color) : background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _Palette.accent(color),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DarkPill extends StatelessWidget {
  const _DarkPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFB6C7FF), size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.caption,
    required this.time,
    required this.icon,
    required this.onTap,
  });

  final String caption;
  final String time;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        side: BorderSide(color: _Palette.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _Palette.canvas,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _Palette.accent(_Palette.blue)),
              const SizedBox(width: 5),
              Text(
                caption,
                style: TextStyle(
                  color: _Palette.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.65,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            time,
            style: TextStyle(
              color: _Palette.ink,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _Palette.bluePale : _Palette.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? (_Palette.isDark
                        ? const Color(0xFF64749A)
                        : const Color(0xFFBFCBFF))
                  : _Palette.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? _Palette.accent(_Palette.blue)
                        : _Palette.muted,
                    size: 20,
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? _Palette.accent(_Palette.blue)
                        : (_Palette.isDark
                              ? const Color(0xFF607089)
                              : const Color(0xFFD5DCE7)),
                    size: 17,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                title,
                style: TextStyle(
                  color: _Palette.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: _Palette.muted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeFootnote extends StatelessWidget {
  const _PrototypeFootnote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline_rounded, size: 13, color: _Palette.muted),
        SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: _Palette.muted, fontSize: 9),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_strings.dart';

void main() => runApp(const CallGuardApp());

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
  const CallGuardApp({super.key});

  @override
  State<CallGuardApp> createState() => _CallGuardAppState();
}

class _CallGuardAppState extends State<CallGuardApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.ukrainian;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) setState(() {});
  }

  void _setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  void _setLanguage(AppLanguage language) =>
      setState(() => _language = language);

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
      home: _CallGuardShell(
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
    required this.themeMode,
    required this.language,
    required this.strings,
    required this.onThemeModeChanged,
    required this.onLanguageChanged,
  });

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
  bool _protectionEnabled = true;
  bool _blockUnknown = true;
  bool _blockNonContacts = false;
  bool _blockInternational = true;
  bool _automaticSilence = false;
  bool _allowOnlyWhitelist = true;

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
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomePage(
            strings: widget.strings,
            protectionEnabled: _protectionEnabled,
            onProtectionChanged: (value) =>
                setState(() => _protectionEnabled = value),
            blockUnknown: _blockUnknown,
            onBlockUnknownChanged: (value) =>
                setState(() => _blockUnknown = value),
            blockNonContacts: _blockNonContacts,
            onBlockNonContactsChanged: (value) =>
                setState(() => _blockNonContacts = value),
            blockInternational: _blockInternational,
            onBlockInternationalChanged: (value) =>
                setState(() => _blockInternational = value),
            automaticSilence: _automaticSilence,
            onOpenSchedule: () => setState(() => _selectedIndex = 2),
            onTest: _openTestDialog,
          ),
          _ListsPage(onStub: _showStub, strings: widget.strings),
          _SchedulePage(
            strings: widget.strings,
            automaticSilence: _automaticSilence,
            onAutomaticSilenceChanged: (value) =>
                setState(() => _automaticSilence = value),
            allowOnlyWhitelist: _allowOnlyWhitelist,
            onAllowOnlyWhitelistChanged: (value) =>
                setState(() => _allowOnlyWhitelist = value),
            onStub: _showStub,
          ),
          _AutoReplyPage(onStub: _showStub, strings: widget.strings),
          _MorePage(onStub: _showStub, strings: widget.strings),
        ],
      ),
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
            ],
          ),
        ),
      ),
    );
  }
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
  const _ListsPage({required this.onStub, required this.strings});

  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<_ListsPage> {
  int _tab = 0;
  final _countryPageKey = GlobalKey<_CountryOperatorsPageState>();

  final List<_ListEntry> _whitelist = [
    _ListEntry(
      title: '',
      titleKey: 'demoMother',
      subtitle: '+380 67 123 45 67',
      badge: '',
      badgeKey: 'allowed',
      icon: Icons.favorite_rounded,
      tint: _Palette.green,
      pale: _Palette.greenPale,
    ),
    _ListEntry(
      title: '',
      titleKey: 'demoWork',
      subtitle: '+380 44 220 18 40',
      badge: '',
      badgeKey: 'allowed',
      icon: Icons.work_outline_rounded,
      tint: _Palette.green,
      pale: _Palette.greenPale,
    ),
  ];

  final List<_ListEntry> _blacklist = [
    _ListEntry(
      title: '',
      titleKey: 'demoUnwanted',
      subtitle: '+48 600 123 456',
      badge: '',
      badgeKey: 'blocked',
      icon: Icons.block_rounded,
      tint: _Palette.red,
      pale: _Palette.redPale,
    ),
    _ListEntry(
      title: '',
      titleKey: 'demoAdvertising',
      subtitle: '+380 67 555 01 01',
      badge: '',
      badgeKey: 'blocked',
      icon: Icons.campaign_outlined,
      tint: _Palette.red,
      pale: _Palette.redPale,
    ),
  ];

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
                  title: nameController.text.trim().isEmpty
                      ? widget.strings.call('newNumber')
                      : nameController.text.trim(),
                  subtitle: phone,
                  badge: '',
                  badgeKey: isWhite ? 'allowed' : 'blocked',
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
      setState(() {
        if (_tab == 0) {
          _whitelist.add(result);
        } else {
          _blacklist.add(result);
        }
      });
    }
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
        return _EntryCard(entry: entries[index - 1], strings: widget.strings);
      },
    );
  }
}

enum _RuleState { neutral, allowed, blocked }

enum _CountryAddChoice { country, operator }

class _CountryEntry {
  _CountryEntry({
    required this.flag,
    required this.name,
    this.nameKey,
    required this.code,
    required this.operators,
    this.action = _RuleState.neutral,
  });

  final String flag;
  final String name;
  final String? nameKey;
  final String code;
  final List<_OperatorEntry> operators;
  _RuleState action;
}

class _OperatorEntry {
  _OperatorEntry({
    required this.name,
    this.nameKey,
    required this.prefixes,
    this.action = _RuleState.neutral,
  });

  final String name;
  final String? nameKey;
  final List<String> prefixes;
  _RuleState action;
}

class _OperatorDraft {
  const _OperatorDraft({required this.countryCode, required this.operator});

  final String countryCode;
  final _OperatorEntry operator;
}

class _CountryOperatorsPage extends StatefulWidget {
  const _CountryOperatorsPage({
    super.key,
    required this.onStub,
    required this.strings,
  });

  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_CountryOperatorsPage> createState() => _CountryOperatorsPageState();
}

class _CountryOperatorsPageState extends State<_CountryOperatorsPage> {
  String _query = '';
  final _searchController = TextEditingController();
  final List<_CountryEntry> _countries = [
    _CountryEntry(
      flag: '🇺🇦',
      name: '',
      nameKey: 'countryUkraine',
      code: '+380',
      operators: [
        _OperatorEntry(
          name: '',
          nameKey: 'operatorKyivstar',
          prefixes: ['67', '68', '96', '97', '98'],
        ),
        _OperatorEntry(
          name: '',
          nameKey: 'operatorVodafoneUA',
          prefixes: ['50', '66', '95', '99'],
        ),
        _OperatorEntry(
          name: '',
          nameKey: 'operatorLifecell',
          prefixes: ['63', '73', '93'],
        ),
      ],
    ),
    _CountryEntry(
      flag: '🇵🇱',
      name: '',
      nameKey: 'countryPoland',
      code: '+48',
      operators: [
        _OperatorEntry(
          name: '',
          nameKey: 'operatorOrange',
          prefixes: ['50', '51', '53', '57', '78', '79'],
        ),
        _OperatorEntry(
          name: '',
          nameKey: 'operatorPlay',
          prefixes: ['45', '53', '72', '73', '79', '88'],
        ),
      ],
    ),
    _CountryEntry(
      flag: '🇩🇪',
      name: '',
      nameKey: 'countryGermany',
      code: '+49',
      operators: [
        _OperatorEntry(
          name: '',
          nameKey: 'operatorTelekom',
          prefixes: ['151', '160', '170', '171', '175'],
        ),
        _OperatorEntry(
          name: '',
          nameKey: 'operatorVodafoneDE',
          prefixes: ['152', '162', '172', '173', '174'],
        ),
      ],
    ),
    _CountryEntry(
      flag: '🇬🇧',
      name: '',
      nameKey: 'countryUK',
      code: '+44',
      operators: [
        _OperatorEntry(
          name: '',
          nameKey: 'operatorVodafoneUK',
          prefixes: ['74', '75', '77', '78', '79'],
        ),
        _OperatorEntry(
          name: '',
          nameKey: 'operatorEE',
          prefixes: ['79', '75', '77'],
        ),
      ],
    ),
    _CountryEntry(
      flag: '🇺🇸🇨🇦',
      name: '',
      nameKey: 'countryNorthAmerica',
      code: '+1',
      operators: [],
    ),
  ];

  String _countryName(_CountryEntry country) => country.nameKey == null
      ? country.name
      : widget.strings.call(country.nameKey!);

  String _operatorName(_OperatorEntry operator) => operator.nameKey == null
      ? operator.name
      : widget.strings.call(operator.nameKey!);

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
      setState(() => _countries.add(country));
    }
  }

  Future<void> _showAddOperatorDialog() async {
    if (_countries.isEmpty) {
      widget.onStub();
      return;
    }
    final nameController = TextEditingController();
    final prefixesController = TextEditingController();
    var countryCode = _countries.first.code;
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
                  initialValue: countryCode,
                  decoration: InputDecoration(
                    labelText: widget.strings.call('operatorCountryField'),
                  ),
                  items: _countries
                      .map(
                        (country) => DropdownMenuItem(
                          value: country.code,
                          child: Text(
                            '${country.flag} ${_countryName(country)} ${country.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => countryCode = value);
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
                    countryCode: countryCode,
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
      final country = _countries.firstWhere(
        (entry) => entry.code == draft.countryCode,
      );
      setState(() => country.operators.add(draft.operator));
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
                onSelected: (value) => setState(() => country.action = value),
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
              onSelected: (value) => setState(() => operator.action = value),
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
        if (filtered.isEmpty)
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
    required this.icon,
    required this.tint,
    required this.pale,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String? titleKey;
  final String? badgeKey;
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
    required this.onStub,
  });

  final AppStrings strings;
  final bool automaticSilence;
  final ValueChanged<bool> onAutomaticSilenceChanged;
  final bool allowOnlyWhitelist;
  final ValueChanged<bool> onAllowOnlyWhitelistChanged;
  final VoidCallback onStub;

  @override
  State<_SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<_SchedulePage> {
  TimeOfDay _startTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5, 6, 7};

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
      initialTime: start ? _startTime : _endTime,
      helpText: widget.strings.call(
        start ? 'timePickerStart' : 'timePickerEnd',
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
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
                    time: _timeLabel(_startTime),
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
                    time: _timeLabel(_endTime),
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
            final selected = _selectedDays.contains(day);
            return ChoiceChip(
              label: Text(_days[index]),
              selected: selected,
              onSelected: (value) => setState(() {
                if (value) {
                  _selectedDays.add(day);
                } else {
                  _selectedDays.remove(day);
                }
              }),
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

class _AutoReplyPage extends StatefulWidget {
  const _AutoReplyPage({required this.onStub, required this.strings});

  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_AutoReplyPage> createState() => _AutoReplyPageState();
}

class _AutoReplyPageState extends State<_AutoReplyPage> {
  bool _enabled = false;
  int _condition = 0;
  int _greeting = 0;
  bool _recordMessages = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _PageIntro(
          eyebrow: widget.strings.call('answerEyebrow'),
          title: widget.strings.answerTitle,
          subtitle: widget.strings.call('answerSubtitle'),
        ),
        const SizedBox(height: 18),
        _Panel(
          child: _RuleSwitch(
            icon: Icons.record_voice_over_outlined,
            title: widget.strings.call('autoReplyLabel'),
            subtitle: widget.strings.call(
              _enabled ? 'autoReplyOn' : 'autoReplyOff',
            ),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
        ),
        const SizedBox(height: 21),
        _SectionHeading(
          title: widget.strings.call('answerWhen'),
          subtitle: widget.strings.call('answerWhenHint'),
        ),
        const SizedBox(height: 10),
        _Panel(
          child: RadioGroup<int>(
            groupValue: _condition,
            onChanged: (next) {
              if (next != null) setState(() => _condition = next);
            },
            child: Column(
              children: [
                _radioOption(
                  0,
                  widget.strings.call('whenBlocked'),
                  Icons.block_outlined,
                ),
                const _ThinDivider(),
                _radioOption(
                  1,
                  widget.strings.call('whenSilence'),
                  Icons.notifications_off_outlined,
                ),
                const _ThinDivider(),
                _radioOption(
                  2,
                  widget.strings.call('whenBusy'),
                  Icons.phone_in_talk_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 21),
        _SectionHeading(
          title: widget.strings.call('greetings'),
          subtitle: widget.strings.call('greetingsHint'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GreetingCard(
                icon: Icons.graphic_eq_rounded,
                title: widget.strings.call('greetingStandard'),
                subtitle: widget.strings.call('greetingSystem'),
                selected: _greeting == 0,
                onTap: () => setState(() => _greeting = 0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _GreetingCard(
                icon: Icons.audio_file_outlined,
                title: widget.strings.call('greetingCustom'),
                subtitle: widget.strings.call('greetingAudio'),
                selected: _greeting == 1,
                onTap: () => setState(() => _greeting = 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onStub,
          icon: const Icon(Icons.mic_none_rounded),
          label: Text(widget.strings.call('recordVoice')),
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
            title: widget.strings.call('recordMessages'),
            subtitle: widget.strings.call('recordMessagesHint'),
            value: _recordMessages,
            onChanged: (value) => setState(() => _recordMessages = value),
            iconColor: _Palette.amber,
            iconBackground: _Palette.amberPale,
          ),
        ),
        const SizedBox(height: 16),
        _PrototypeFootnote(label: widget.strings.call('prototypeFootnote')),
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
  const _MorePage({required this.onStub, required this.strings});

  final VoidCallback onStub;
  final AppStrings strings;

  @override
  State<_MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<_MorePage> {
  int _segment = 0;
  final List<_Reminder> _reminders = [
    _Reminder(
      name: '',
      nameKey: 'reminderOlena',
      phone: '+380 67 123 45 67',
      dateLabel: '14:30',
      datePrefixKey: 'today',
      note: '',
      noteKey: 'reminderNoteMeeting',
    ),
    _Reminder(
      name: '',
      nameKey: 'reminderUnknown',
      phone: '+48 600 123 456',
      dateLabel: '09:15',
      datePrefixKey: 'tomorrow',
      note: '',
      noteKey: 'reminderNoteCheck',
    ),
  ];

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
                    name: widget.strings.call('reminderNew'),
                    phone: phone,
                    dateLabel:
                        '${_dateLabel(selectedDate)} · ${_timeLabel(selectedTime)}',
                    note: noteController.text.trim().isEmpty
                        ? widget.strings.call('reminderNewNote')
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
    if (result != null && mounted) setState(() => _reminders.insert(0, result));
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
    ..._reminders.map(
      (reminder) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ReminderCard(
          reminder: reminder,
          strings: widget.strings,
          onCall: widget.onStub,
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
    _JournalCard(
      phone: '+48 600 123 456',
      caption: '${widget.strings.call('today')} · 11:42',
      reason: widget.strings.call('reasonCountry'),
      tint: _Palette.red,
      pale: _Palette.redPale,
      icon: Icons.public_rounded,
      onAdd: widget.onStub,
      addLabel: widget.strings.call('addToAllowlist'),
    ),
    const SizedBox(height: 10),
    _JournalCard(
      phone: widget.strings.call('numberHidden'),
      caption: '${widget.strings.call('today')} · 09:18',
      reason: widget.strings.call('reasonHidden'),
      tint: _Palette.amber,
      pale: _Palette.amberPale,
      icon: Icons.visibility_off_outlined,
      onAdd: widget.onStub,
      addLabel: widget.strings.call('addToAllowlist'),
    ),
    const SizedBox(height: 10),
    _JournalCard(
      phone: '+380 44 555 20 20',
      caption: '${widget.strings.call('yesterday')} · 20:06',
      reason: widget.strings.call('reasonSilence'),
      tint: const Color(0xFF7663D9),
      pale: const Color(0xFFF0EDFF),
      icon: Icons.notifications_off_outlined,
      onAdd: widget.onStub,
      addLabel: widget.strings.call('addToAllowlist'),
    ),
  ];
}

class _Reminder {
  const _Reminder({
    required this.name,
    required this.phone,
    required this.dateLabel,
    required this.note,
    this.nameKey,
    this.datePrefixKey,
    this.noteKey,
  });

  final String name;
  final String phone;
  final String dateLabel;
  final String note;
  final String? nameKey;
  final String? datePrefixKey;
  final String? noteKey;
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.strings,
    required this.onCall,
  });

  final _Reminder reminder;
  final AppStrings strings;
  final VoidCallback onCall;

  String _dateLabel() => reminder.datePrefixKey == null
      ? reminder.dateLabel
      : '${strings.call(reminder.datePrefixKey!)} · ${reminder.dateLabel}';

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
                        reminder.nameKey == null
                            ? reminder.name
                            : strings.call(reminder.nameKey!),
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
                    _dateLabel(),
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
                    reminder.noteKey == null
                        ? reminder.note
                        : strings.call(reminder.noteKey!),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _Palette.muted, fontSize: 11),
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
          ],
        ),
      ),
    );
  }
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
  const _EntryCard({required this.entry, required this.strings});

  final _ListEntry entry;
  final AppStrings strings;

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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../platform/call_screening_channel.dart';
import '../platform/status_tray_lifecycle.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../widgets/common/shield_phone_logo.dart';
import 'app_shell.dart';

class CallGuardApp extends StatefulWidget {
  CallGuardApp({super.key, DatabaseHelper? database})
    : database = database ?? DatabaseHelper.instance;

  final DatabaseHelper database;

  @override
  State<CallGuardApp> createState() => CallGuardAppState();
}

class CallGuardAppState extends State<CallGuardApp>
    with WidgetsBindingObserver {
  bool _ready = false;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.ukrainian;
  bool _protectionEnabled = true;
  bool _drivingMode = false;
  StatusTrayPreferences _trayPreferences = const StatusTrayPreferences();
  StatusTrayMode _trayMode = StatusTrayMode.hidden;
  bool _blockUnknown = true;
  bool _blockNonContacts = false;
  bool _blockInternational = true;
  bool _blockShortNumbers = false;
  bool _automaticSilence = false;
  bool _manualSilenceEnabled = false;
  bool _allowOnlyWhitelist = true;
  TimeOfDay _silenceStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _silenceEnd = const TimeOfDay(hour: 7, minute: 0);
  Set<int> _silenceWeekdays = {1, 2, 3, 4, 5, 6, 7};
  bool _answeringEnabled = false;
  String _answeringScenario = 'quiet_mode';
  bool _answeringLocalNotification = true;
  bool _answeringAutoRemind = false;
  int _answeringAutoRemindMinutes = 30;
  bool _answeringEmergencyRepeat = false;
  bool _dndSyncEnabled = false;
  int _openCallJournalRequest = 0;
  int _callHandledRequest = 0;
  int _modeRefreshGeneration = 0;
  late final CallScreeningChannel _screeningChannel;
  Future<void> _pendingSettingsWrites = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screeningChannel = CallScreeningChannel()
      ..setOpenCallJournalHandler(() async {
        if (!mounted) return false;
        setState(() => _openCallJournalRequest++);
        return true;
      })
      ..setStatusModesChangedHandler(_refreshModesFromDatabase)
      ..setCallHandledHandler(() async {
        if (mounted) setState(() => _callHandledRequest++);
      });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _ready) {
      unawaited(_refreshModesFromDatabase());
    }
  }

  Future<void> _refreshModesFromDatabase() async {
    if (!_ready) return;
    final generation = ++_modeRefreshGeneration;
    try {
      final settings = await widget.database.getSettings();
      if (!mounted || generation != _modeRefreshGeneration) return;
      bool parseBool(String key, bool fallback) =>
          settings[key] == null ? fallback : settings[key] == 'true';
      final protectionEnabled = parseBool('protection_enabled', true);
      final drivingMode = parseBool('driving_mode', false);
      if (protectionEnabled != _protectionEnabled ||
          drivingMode != _drivingMode) {
        setState(() {
          _protectionEnabled = protectionEnabled;
          _drivingMode = drivingMode;
        });
      }
      await _reconcileStatusTray();
    } catch (error, stackTrace) {
      debugPrint(
        'Call Gate modes could not be refreshed from SQLite: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _restoreSettings() async {
    try {
      await widget.database.initialize();
      var openCallJournal = false;
      try {
        openCallJournal = await _screeningChannel.consumePendingCallJournal();
      } on PlatformException {
        // Notification navigation is available only on Android.
      } on MissingPluginException {
        // Keep the app usable on platforms without the Android channel.
      }
      try {
        await _screeningChannel.restorePendingReminders();
      } on PlatformException {
        // Reminder alarms are an Android-only integration.
      } on MissingPluginException {
        // Keep the local app usable on platforms without the Android channel.
      }
      final settings = await widget.database.getSettings();
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
        if (openCallJournal) _openCallJournalRequest++;
        _language = parseLanguage(settings['locale']);
        _themeMode = parseTheme(settings['theme_mode']);
        _protectionEnabled = parseBool('protection_enabled', true);
        _drivingMode = parseBool('driving_mode', false);
        _trayPreferences = StatusTrayPreferences(
          enabled: parseBool('status_tray_icon_enabled', true),
          userOverridden: parseBool('status_tray_user_overridden', false),
          activated: parseBool('status_tray_activated', false),
          permissionPrompted: parseBool(
            'status_tray_permission_prompted',
            false,
          ),
        );
        _blockUnknown = parseBool('block_hidden', true);
        _blockNonContacts = parseBool('block_non_contacts', false);
        _blockInternational = parseBool('block_international', true);
        _blockShortNumbers = parseBool(
          DatabaseHelper.settingBlockShortNumbers,
          false,
        );
        _automaticSilence = parseBool('automatic_silence', false);
        _manualSilenceEnabled = parseBool('manual_silence_enabled', false);
        _allowOnlyWhitelist = parseBool('allow_only_whitelist', true);
        _silenceStart = _timeOfDay(parseInt('silence_start_minute', 1320));
        _silenceEnd = _timeOfDay(parseInt('silence_end_minute', 420));
        _silenceWeekdays = settings.containsKey('silence_weekdays')
            ? weekdays
            : {1, 2, 3, 4, 5, 6, 7};
        _answeringEnabled = parseBool('answering_enabled', false);
        final scenario = settings['answering_scenario'];
        _answeringScenario = scenario == 'unknown_numbers'
            ? 'unknown_numbers'
            : 'quiet_mode';
        _answeringLocalNotification = parseBool(
          'answering_local_notification',
          true,
        );
        _answeringAutoRemind = parseBool('answering_auto_remind', false);
        final autoRemindMinutes = parseInt('answering_auto_remind_minutes', 30);
        _answeringAutoRemindMinutes =
            const {15, 30, 60}.contains(autoRemindMinutes)
            ? autoRemindMinutes
            : 30;
        _answeringEmergencyRepeat = parseBool(
          'answering_emergency_repeat',
          false,
        );
        _dndSyncEnabled = parseBool('dnd_sync_enabled', false);
        _ready = true;
      });
      await _reconcileStatusTray(allowPermissionRequest: true);
      await _syncDndStateSafely();
    } catch (error, stackTrace) {
      debugPrint(
        'Call Gate settings could not be restored: $error\n$stackTrace',
      );
      if (mounted) setState(() => _ready = true);
    }
  }

  TimeOfDay _timeOfDay(int minutes) => TimeOfDay(
    hour: (minutes ~/ 60).clamp(0, 23),
    minute: minutes.remainder(60).clamp(0, 59),
  );

  Future<void> _persistSetting(String key, Object value) {
    final write = _pendingSettingsWrites
        .catchError((Object _) {})
        .then((_) => widget.database.setSetting(key, value));
    _pendingSettingsWrites = write;
    return write;
  }

  void _persistAndSyncDnd(String key, Object value) {
    unawaited(_persistSetting(key, value).then((_) => _syncDndStateSafely()));
  }

  Future<void> _syncDndStateSafely() async {
    try {
      await _screeningChannel.syncDndState();
    } on PlatformException {
      // DND policy access and synchronization are optional Android features.
    } on MissingPluginException {
      // Keep the app usable when the Android channel is unavailable.
    }
  }

  Future<CallScreeningPermissions?> _readPermissions() async {
    try {
      return await _screeningChannel.checkPermissions();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Hides the tray until screening is configured, auto-enables it when the
  /// role is granted, and keeps it in sync with protection and driving modes.
  Future<void> _reconcileStatusTray({
    bool allowPermissionRequest = false,
  }) async {
    if (!_ready) return;
    final permissions = await _readPermissions();
    final decision = StatusTrayLifecycle.reconcile(
      current: _trayPreferences,
      roleGranted: permissions?.callScreeningRole ?? false,
      protectionEnabled: _protectionEnabled,
      drivingMode: _drivingMode,
      notificationsGranted: permissions?.notificationsGranted ?? false,
    );
    final previous = _trayPreferences;
    final next = decision.preferences;
    if (mounted) {
      setState(() {
        _trayPreferences = next;
        _trayMode = decision.mode;
      });
    } else {
      _trayPreferences = next;
      _trayMode = decision.mode;
    }
    await _persistTrayPreferences(previous, next);
    if (decision.requestNotificationPermission && allowPermissionRequest) {
      try {
        await _screeningChannel.requestNotificationPermission();
      } on PlatformException {
        // The system may refuse without showing a dialog; the tray stays
        // enabled but hidden by Android until permission is granted.
      } on MissingPluginException {
        // Notification permissions are Android-only.
      }
      await _reconcileStatusTray();
      return;
    }
    _syncStatusIndicator();
  }

  Future<void> _persistTrayPreferences(
    StatusTrayPreferences previous,
    StatusTrayPreferences next,
  ) async {
    if (previous.enabled != next.enabled) {
      await _persistSetting('status_tray_icon_enabled', next.enabled);
    }
    if (previous.userOverridden != next.userOverridden) {
      await _persistSetting('status_tray_user_overridden', next.userOverridden);
    }
    if (previous.activated != next.activated) {
      await _persistSetting('status_tray_activated', next.activated);
    }
    if (previous.permissionPrompted != next.permissionPrompted) {
      await _persistSetting(
        'status_tray_permission_prompted',
        next.permissionPrompted,
      );
    }
  }

  void _syncStatusIndicator() {
    if (!_ready) return;
    _screeningChannel
        .updateStatusIndicator(
          enabled: _trayMode != StatusTrayMode.hidden,
          protectionEnabled: _protectionEnabled,
          drivingMode: _drivingMode,
          locale: _language.name,
        )
        .catchError((Object _) {
          // The persistent Android status notification is unavailable on
          // platforms that do not register the Android MethodChannel.
        });
  }

  Future<void> _setStatusIndicatorEnabled(bool value) async {
    if (value) {
      final permissions = await _readPermissions();
      if (permissions != null && !permissions.notificationsGranted) {
        try {
          await _screeningChannel.requestNotificationPermission();
        } on PlatformException {
          // Keep the user's explicit choice even if Android refuses.
        } on MissingPluginException {
          // Keep the preference usable in widget tests and on other platforms.
        }
      }
    }
    if (!mounted) return;
    final next = StatusTrayLifecycle.userChanged(
      _trayPreferences,
      value,
    ).copyWith(permissionPrompted: true);
    final previous = _trayPreferences;
    setState(() => _trayPreferences = next);
    await _persistTrayPreferences(previous, next);
    await _reconcileStatusTray();
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    _persistSetting('theme_mode', mode.name);
  }

  void _setLanguage(AppLanguage language) {
    setState(() => _language = language);
    _persistSetting('locale', language.name);
    _syncStatusIndicator();
  }

  void _setSilenceStart(TimeOfDay value) {
    setState(() => _silenceStart = value);
    _persistAndSyncDnd('silence_start_minute', value.hour * 60 + value.minute);
  }

  void _setSilenceEnd(TimeOfDay value) {
    setState(() => _silenceEnd = value);
    _persistAndSyncDnd('silence_end_minute', value.hour * 60 + value.minute);
  }

  void _setSilenceWeekdays(Set<int> value) {
    setState(() => _silenceWeekdays = value);
    final days = value.toList()..sort();
    _persistAndSyncDnd('silence_weekdays', days.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    AppPalette.isDark = switch (_themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platformBrightness == Brightness.dark,
    };
    final strings = AppStrings(_language);
    return MaterialApp(
      title: 'Call Gate',
      debugShowCheckedModeBanner: false,
      locale: _language.locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: _themeMode,
      theme: AppTheme.themeFor(Brightness.light),
      darkTheme: AppTheme.themeFor(Brightness.dark),
      home: !_ready
          ? Scaffold(body: const Center(child: ShieldPhoneLogo(size: 72)))
          : CallGuardShell(
              database: widget.database,
              protectionEnabled: _protectionEnabled,
              onProtectionChanged: (value) {
                setState(() => _protectionEnabled = value);
                _persistAndSyncDnd('protection_enabled', value);
                unawaited(_reconcileStatusTray());
              },
              drivingMode: _drivingMode,
              onDrivingModeChanged: (value) {
                setState(() => _drivingMode = value);
                _persistAndSyncDnd('driving_mode', value);
                unawaited(_reconcileStatusTray());
              },
              statusIndicatorEnabled: _trayPreferences.enabled,
              onStatusIndicatorChanged: _setStatusIndicatorEnabled,
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
              blockShortNumbers: _blockShortNumbers,
              onBlockShortNumbersChanged: (value) {
                setState(() => _blockShortNumbers = value);
                _persistSetting(DatabaseHelper.settingBlockShortNumbers, value);
              },
              automaticSilence: _automaticSilence,
              manualSilenceEnabled: _manualSilenceEnabled,
              onManualSilenceChanged: (value) {
                setState(() => _manualSilenceEnabled = value);
                _persistAndSyncDnd('manual_silence_enabled', value);
              },
              onAutomaticSilenceChanged: (value) {
                setState(() => _automaticSilence = value);
                _persistAndSyncDnd('automatic_silence', value);
              },
              dndSyncEnabled: _dndSyncEnabled,
              onDndSyncEnabledChanged: (value) {
                setState(() => _dndSyncEnabled = value);
                _persistAndSyncDnd('dnd_sync_enabled', value);
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
              answeringEnabled: _answeringEnabled,
              onAnsweringEnabledChanged: (value) {
                setState(() => _answeringEnabled = value);
                _persistSetting('answering_enabled', value);
              },
              answeringScenario: _answeringScenario,
              onAnsweringScenarioChanged: (value) {
                setState(() => _answeringScenario = value);
                _persistSetting('answering_scenario', value);
              },
              answeringLocalNotification: _answeringLocalNotification,
              onAnsweringLocalNotificationChanged: (value) {
                setState(() => _answeringLocalNotification = value);
                _persistSetting('answering_local_notification', value);
              },
              answeringAutoRemind: _answeringAutoRemind,
              onAnsweringAutoRemindChanged: (value) {
                setState(() => _answeringAutoRemind = value);
                _persistSetting('answering_auto_remind', value);
              },
              answeringAutoRemindMinutes: _answeringAutoRemindMinutes,
              onAnsweringAutoRemindMinutesChanged: (value) {
                setState(() => _answeringAutoRemindMinutes = value);
                _persistSetting('answering_auto_remind_minutes', value);
              },
              answeringEmergencyRepeat: _answeringEmergencyRepeat,
              onAnsweringEmergencyRepeatChanged: (value) {
                setState(() => _answeringEmergencyRepeat = value);
                _persistSetting('answering_emergency_repeat', value);
              },
              openCallJournalRequest: _openCallJournalRequest,
              callHandledRequest: _callHandledRequest,
              themeMode: _themeMode,
              language: _language,
              strings: strings,
              onThemeModeChanged: _setThemeMode,
              onLanguageChanged: _setLanguage,
            ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:call_guard/data/database_helper.dart';
import 'package:call_guard/main.dart';
import 'package:call_guard/l10n/app_strings.dart';
import 'package:call_guard/l10n/strings_de.dart';
import 'package:call_guard/l10n/strings_en.dart';
import 'package:call_guard/l10n/strings_es.dart';
import 'package:call_guard/l10n/strings_fr.dart';
import 'package:call_guard/l10n/strings_pl.dart';
import 'package:call_guard/l10n/strings_uk.dart';
import 'package:call_guard/platform/call_screening_channel.dart';
import 'package:call_guard/widgets/common/app_panel.dart';
import 'package:call_guard/widgets/common/journal_card.dart';

late DatabaseHelper _testDatabase;

void main() {
  setUpAll(() {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() async {
    _testDatabase = DatabaseHelper.forTesting();
    await _testDatabase.initialize();
  });
  tearDown(() async {
    await _testDatabase.getSettings();
    await _testDatabase.close();
  });

  Future<void> waitForText(WidgetTester tester, String text) async {
    for (
      var attempt = 0;
      attempt < 30 && find.text(text).evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(CallGuardApp(database: _testDatabase));
    await waitForText(tester, 'Захист вхідних дзвінків');
    await tester.pumpAndSettle();
  }

  Future<void> waitForDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  Future<void> finishSectionTransition(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder homeScrollable() => find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;

  test('SQLite schema seeds settings, countries and operators', () async {
    final settings = await _testDatabase.getSettings();
    final countries = await _testDatabase.getCountries();
    expect(settings['locale'], 'ukrainian');
    expect(countries, hasLength(5));
    expect(await _testDatabase.getOperators('UA'), hasLength(4));
    expect((await _testDatabase.getCallLogs()).first, contains('contact_name'));
    expect(await _testDatabase.getPhoneRules('white'), hasLength(2));
    expect(
      await _testDatabase.getIndexNamesForTesting(),
      containsAll(<String>[
        'idx_phone_rules_list_type',
        'idx_operator_rules_country_id',
        'idx_call_reminders_pending',
        'idx_call_logs_timestamp',
      ]),
    );
  });

  test('callback assistant settings default safely and persist', () async {
    final defaults = await _testDatabase.getSettings();
    expect(defaults['answering_auto_remind'], 'false');
    expect(defaults['answering_auto_remind_minutes'], '30');
    expect(defaults['answering_emergency_repeat'], 'false');

    await _testDatabase.setSetting('answering_auto_remind', true);
    await _testDatabase.setSetting('answering_auto_remind_minutes', 15);
    await _testDatabase.setSetting('answering_emergency_repeat', true);
    final saved = await _testDatabase.getSettings();
    expect(saved['answering_auto_remind'], 'true');
    expect(saved['answering_auto_remind_minutes'], '15');
    expect(saved['answering_emergency_repeat'], 'true');
  });

  test('fixed-line operator prefixes are seeded and can be blocked', () async {
    final operators = await _testDatabase.getOperators('UA');
    final ukrtelecom = operators.singleWhere(
      (row) => row['operator_name'] == '@operatorUkrtelecom',
    );
    expect(ukrtelecom['prefixes'], '44');
    expect(ukrtelecom['action'], 'neutral');

    await _testDatabase.updateOperatorAction(ukrtelecom['id'] as int, 'block');
    final saved = (await _testDatabase.getOperators('UA'))
        .singleWhere((row) => row['operator_name'] == '@operatorUkrtelecom');
    expect(saved['prefixes'], '44');
    expect(saved['action'], 'block');
  });

  test('legacy reminder tables migrate and persist repeat rules', () async {
    final databasePath = File('test/call_guard_legacy_reminders_test.db')
        .absolute
        .path;
    final databaseFile = File(databasePath);
    if (databaseFile.existsSync()) databaseFile.deleteSync();
    addTearDown(() async {
      for (final file in [
        databaseFile,
        File('$databasePath-shm'),
        File('$databasePath-wal'),
      ]) {
        if (await file.exists()) await file.delete();
      }
    });

    final legacyDatabase = await sqflite.openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_reminders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            contact_name TEXT,
            remind_at INTEGER NOT NULL,
            note TEXT,
            is_done INTEGER DEFAULT 0
          )
        ''');
        await db.insert('call_reminders', {
          'phone': '+380671234567',
          'remind_at': 1_900_000_000_000,
        });
      },
    );
    await legacyDatabase.close();

    final migrated = DatabaseHelper.forTesting(databasePath: databasePath);
    await migrated.initialize();
    final migratedSettings = await migrated.getSettings();
    expect(migratedSettings['answering_auto_remind'], 'false');
    expect(migratedSettings['answering_auto_remind_minutes'], '30');
    expect(migratedSettings['answering_emergency_repeat'], 'false');
    expect(
      await migrated.getIndexNamesForTesting(),
      contains('idx_call_reminders_pending'),
    );
    final legacyRow = (await migrated.getReminders()).firstWhere(
      (row) => row['phone'] == '+380671234567',
    );
    expect(legacyRow['repeat_type'], 'none');
    expect(legacyRow['repeat_interval'], 1);
    expect(legacyRow['created_at'], 0);

    final reminderId = await migrated.insertReminder(
      phone: '+48123456789',
      contactName: 'Ada',
      remindAt: 1_900_000_000_000,
      note: 'Call back',
      repeatType: 'custom',
      repeatInterval: 4,
    );
    await migrated.updateReminderSchedule(
      id: reminderId,
      remindAt: 1_900_000_100_000,
      repeatType: 'weekly',
      repeatInterval: 1,
    );
    final updated = (await migrated.getReminders()).singleWhere(
      (row) => row['id'] == reminderId,
    );
    expect(updated['repeat_type'], 'weekly');
    expect(updated['repeat_interval'], 1);
    await migrated.close();
  });

  test('legacy call logs migrate the saved contact name column', () async {
    const databasePath = 'test/call_guard_legacy_call_logs_test.db';
    final databaseFile = File(databasePath);
    if (databaseFile.existsSync()) databaseFile.deleteSync();
    addTearDown(() async {
      for (final file in [
        databaseFile,
        File('$databasePath-shm'),
        File('$databasePath-wal'),
      ]) {
        if (await file.exists()) await file.delete();
      }
    });

    final legacyDatabase = await sqflite.openDatabase(
      databasePath,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            reason TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.insert('call_logs', {
          'phone': '+380441234567',
          'reason': 'operator_block',
          'timestamp': 1234,
        });
      },
    );
    await legacyDatabase.close();

    final migrated = DatabaseHelper.forTesting(databasePath: databasePath);
    await migrated.initialize();
    final logs = await migrated.getCallLogs();
    expect(logs.single['phone'], '+380441234567');
    expect(logs.single.containsKey('contact_name'), isTrue);
    expect(logs.single['contact_name'], isNull);
    await migrated.close();
  });

  test(
    'can edit a reminder time and delete or clear call log entries',
    () async {
      final reminder = (await _testDatabase.getReminders()).first;
      final newReminderAt = DateTime(2027, 2, 3, 14, 45).millisecondsSinceEpoch;
      await _testDatabase.updateReminderTime(
        reminder['id'] as int,
        newReminderAt,
      );
      expect(
        (await _testDatabase.getReminders()).firstWhere(
          (row) => row['id'] == reminder['id'],
        )['remind_at'],
        newReminderAt,
      );

      final firstLog = (await _testDatabase.getCallLogs()).first;
      await _testDatabase.deleteCallLog(firstLog['id'] as int);
      expect(await _testDatabase.getCallLogs(), hasLength(2));
      await _testDatabase.clearCallLogs();
      expect(await _testDatabase.getCallLogs(), isEmpty);
    },
  );

  test(
    'SQLite preferences and records survive closing and reopening',
    () async {
      const databasePath = 'test/call_guard_persistence_test.db';
      final databaseFile = File(databasePath);
      if (databaseFile.existsSync()) databaseFile.deleteSync();
      addTearDown(() async {
        for (final file in [
          databaseFile,
          File('$databasePath-shm'),
          File('$databasePath-wal'),
        ]) {
          if (await file.exists()) await file.delete();
        }
      });

      final firstOpen = DatabaseHelper.forTesting(databasePath: databasePath);
      await firstOpen.initialize();
      await firstOpen.setSetting('locale', 'french');
      await firstOpen.setSetting('theme_mode', 'dark');
      await firstOpen.setSetting('silence_weekdays', '');
      final phoneId = await firstOpen.insertPhoneRule(
        phone: '+49 151 1234567',
        label: 'Work',
        listType: 'white',
      );
      await firstOpen.updateCountryAction('UA', 'block');
      final operatorId =
          (await firstOpen.getOperators('UA')).first['id'] as int;
      await firstOpen.updateOperatorAction(operatorId, 'allow');
      final reminderId = await firstOpen.insertReminder(
        phone: '+49 151 1234567',
        contactName: 'Alex',
        remindAt: DateTime(2026, 12, 1, 9).millisecondsSinceEpoch,
        note: 'Call back',
      );
      await firstOpen.updateReminderDone(reminderId, true);
      expect(phoneId, greaterThan(0));
      await firstOpen.close();

      final reopened = DatabaseHelper.forTesting(databasePath: databasePath);
      await reopened.initialize();
      expect((await reopened.getSettings())['locale'], 'french');
      expect((await reopened.getSettings())['theme_mode'], 'dark');
      expect((await reopened.getSettings())['silence_weekdays'], '');
      expect(
        (await reopened.getPhoneRules('white'))
            .any((row) => row['phone'] == '+49 151 1234567'),
        isTrue,
      );
      expect(
        (await reopened.getCountries()).firstWhere(
          (row) => row['iso_code'] == 'UA',
        )['action'],
        'block',
      );
      expect(
        (await reopened.getOperators('UA'))
            .firstWhere((row) => row['id'] == operatorId)['action'],
        'allow',
      );
      expect(
        (await reopened.getReminders()).firstWhere(
          (row) => row['id'] == reminderId,
        )['is_done'],
        1,
      );
      expect(await reopened.getCallLogs(), isNotEmpty);
      await reopened.close();
    },
  );

  testWidgets('renders the Call Gate protection prototype', (tester) async {
    await pumpApp(tester);

    expect(find.text('Захист вхідних дзвінків'), findsOneWidget);
    expect(find.text('Захист активний'), findsOneWidget);
    expect(find.text('CALL GATE'), findsNWidgets(2));
    expect(find.byType(ShieldPhoneLogo), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('Швидкі правила'),
      250,
      scrollable: homeScrollable(),
    );
    expect(find.text('Швидкі правила'), findsOneWidget);
  });

  testWidgets(
    'home groups manual silence under quick rules and has no standard card',
    (tester) async {
      await pumpApp(tester);
      expect(find.text('Стандартний режим'), findsNothing);
      expect(find.text('Розумний фільтр вхідних дзвінків'), findsOneWidget);

      final manualSilence = find.text('Режим тиші вручну');
      await tester.scrollUntilVisible(
        manualSilence,
        250,
        scrollable: homeScrollable(),
      );
      final quickRulesCard = find
          .ancestor(of: manualSilence, matching: find.byType(AppPanel))
          .first;
      expect(
        find.descendant(
          of: quickRulesCard,
          matching: find.text('Приховані номери'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: manualSilence, matching: find.byType(AppPanel)),
        findsOneWidget,
      );
    },
  );

  testWidgets('journal card shows the contact name and copies its number', (
    tester,
  ) async {
    final strings = AppStrings(AppLanguage.ukrainian);
    String? copiedText;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: JournalCard(
                strings: strings,
                phone: '+380 44 123 45 67',
                contactName: 'Тестовий контакт',
                caption: '2026-11-17 · 12:30',
                reason: strings.call('operator_block'),
                tint: Colors.deepOrange,
                pale: const Color(0xFFFFEEE5),
                icon: Icons.cell_tower_rounded,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Тестовий контакт'), findsOneWidget);
    expect(find.text('+380 44 123 45 67'), findsOneWidget);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
            (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.tap(find.byTooltip('Скопіювати номер'));
    await tester.pumpAndSettle();
    expect(copiedText, '+380 44 123 45 67');
    expect(find.text('Номер скопійовано'), findsOneWidget);
  });

  testWidgets('Scenarios navigation uses the new title and short tab label', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Розумний фільтр вхідних дзвінків'), findsOneWidget);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Сценарії та нагадування');

    expect(find.text('Сценарії та нагадування'), findsOneWidget);
    expect(find.text('Сценарії'), findsOneWidget);
  });

  testWidgets('lists header is left aligned like the other sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Списки та фільтри');

    final title = tester.widget<Text>(find.text('Списки та фільтри'));
    expect(title.textAlign, TextAlign.start);
    expect(
      tester.getTopLeft(find.text('Списки та фільтри')).dx,
      closeTo(18, 0.5),
    );
    expect(
      tester
          .getTopLeft(find.text('Визначте, від кого приймати вхідні дзвінки.'))
          .dx,
      closeTo(18, 0.5),
    );
    await waitForDatabase(tester);
  });

  testWidgets('bottom info banner appears only on the Home section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const message =
        'Call Gate працює повністю безкоштовно, без реклами та прихованих платежів і завжди залишатиметься таким.';
    const link = 'Підтримати проєкт';

    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text(message),
      250,
      scrollable: homeScrollable(),
    );
    await tester.ensureVisible(find.text(link));
    await tester.pumpAndSettle();
    expect(find.text(message).hitTestable(), findsOneWidget);
    expect(find.text(link).hitTestable(), findsOneWidget);

    for (final tooltip in [
      'Списки та фільтри',
      'Графік режиму тиші',
      'Сценарії та нагадування',
      'Нагадування та Журнал',
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      await finishSectionTransition(tester);
      expect(find.text(message).hitTestable(), findsNothing);
      expect(find.text(link).hitTestable(), findsNothing);
    }

    await waitForText(tester, 'Олена Коваль');
    await waitForDatabase(tester);
  });

  testWidgets('support link in the bottom banner opens the support dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Підтримати проєкт'),
      250,
      scrollable: homeScrollable(),
    );
    await tester.ensureVisible(find.text('Підтримати проєкт'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Підтримати проєкт'));
    await tester.pumpAndSettle();

    expect(find.text('Підтримати через Monobank'), findsOneWidget);
    expect(find.text('Підтримати на Ko-fi'), findsOneWidget);
    expect(find.text('Поділитися застосунком'), findsOneWidget);
  });

  testWidgets('answering assistant warns when main protection is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(
      () => _testDatabase.setSetting('protection_enabled', false),
    );
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);

    const warning =
        'Основний захист на «Головній» вимкнено, тому помічник зараз не перехоплюватиме дзвінки.';
    await waitForText(tester, warning);
    expect(find.text(warning), findsOneWidget);
  });

  testWidgets('reminder card labels the done checkbox', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Олена Коваль');

    expect(find.text('Позначити виконаним'), findsWidgets);
  });

  testWidgets('horizontal swipe changes the main navigation section', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.drag(find.byType(PageView).first, const Offset(-450, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await waitForText(tester, 'Мама');

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('Мама'), findsOneWidget);

    await tester.drag(find.byType(PageView).first, const Offset(450, 0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('Захист активний'), findsOneWidget);
  });

  test('every supported language has a complete UI dictionary', () {
    for (final language in AppLanguage.values) {
      final strings = AppStrings(language);
      for (final key in AppStrings.keys) {
        expect(
          strings.call(key),
          isNotEmpty,
          reason: '${language.label}: $key',
        );
      }
      expect(
        strings.call('moreSubtitle').toLowerCase(),
        isNot(contains('demo')),
        reason: '${language.label}: reminders page should not say demo',
      );
    }
  });

  test('all languages use the same placeholders for every key', () {
    final placeholder = RegExp(r'\{[^{}]+\}');
    for (final key in AppStrings.keys) {
      final expected = placeholder
          .allMatches(AppStrings(AppLanguage.ukrainian).call(key))
          .map((match) => match.group(0)!)
          .toSet();
      for (final language in AppLanguage.values) {
        final actual = placeholder
            .allMatches(AppStrings(language).call(key))
            .map((match) => match.group(0)!)
            .toSet();
        expect(
          actual,
          expected,
          reason: '${language.label}: $key placeholders differ',
        );
      }
    }
  });

  test('all languages contain the requested slogan and scenarios labels', () {
    final expected = <AppLanguage, (String, String, String)>{
      AppLanguage.ukrainian: (
        'Розумний фільтр вхідних дзвінків',
        'Сценарії та нагадування',
        'Сценарії',
      ),
      AppLanguage.english: (
        'Smart incoming call filter',
        'Scenarios & Reminders',
        'Scenarios',
      ),
      AppLanguage.polish: (
        'Inteligentny filtr połączeń przychodzących',
        'Scenariusze i przypomnienia',
        'Scenariusze',
      ),
      AppLanguage.german: (
        'Intelligenter Filter für eingehende Anrufe',
        'Szenarien & Erinnerungen',
        'Szenarien',
      ),
      AppLanguage.spanish: (
        'Filtro inteligente de llamadas entrantes',
        'Escenarios y recordatorios',
        'Escenarios',
      ),
      AppLanguage.french: (
        "Filtre intelligent d'appels entrants",
        'Scénarios et rappels',
        'Scénarios',
      ),
    };
    for (final entry in expected.entries) {
      final strings = AppStrings(entry.key);
      expect(strings.call('appSlogan'), entry.value.$1);
      expect(strings.answerTitle, entry.value.$2);
      expect(strings.answerNav, entry.value.$3);
    }
  });

  test('allowlist-only verdict is localized in every language', () {
    for (final language in AppLanguage.values) {
      final strings = AppStrings(language);
      expect(strings.call('allowlist_only'), isNotEmpty);
      expect(
        strings.call('allowlist_only'),
        isNot(strings.call('allowlist')),
        reason: '${language.label}: allowlist-only reason must be distinct',
      );
    }
  });

  test(
    'reminder bridge forwards scheduling and notification methods',
    () async {
      const channel = MethodChannel('com.wepr.callguard/reminder-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final bridge = CallScreeningChannel(channel: channel);
      expect(await bridge.requestNotificationPermission(), isTrue);
      await bridge.scheduleReminder(id: 21, remindAt: 1_900_000_000_000);
      await bridge.cancelReminder(21);
      await bridge.restorePendingReminders();
      await bridge.openNotificationSettings();
      await bridge.openDefaultAppsSettings();
      await bridge.openDialer('+380 67 123 45 67');

      expect(calls.map((call) => call.method), [
        'requestNotificationPermission',
        'scheduleReminder',
        'cancelReminder',
        'restorePendingReminders',
        'openNotificationSettings',
        'openDefaultAppsSettings',
        'openDialer',
      ]);
      expect(calls[1].arguments, {'id': 21, 'remindAt': 1_900_000_000_000});
      expect(calls[6].arguments, {'phoneNumber': '+380 67 123 45 67'});
    },
  );

  testWidgets(
    'notification banner refreshes and home shows permission status',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const channel = MethodChannel('com.wepr.callguard/screening');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var notificationsGranted = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkPermissions') {
          return {
            'roleAvailable': true,
            'callScreeningRole': false,
            'readContacts': false,
            'notificationsGranted': notificationsGranted,
          };
        }
        if (call.method == 'restorePendingReminders') return true;
        if (call.method == 'consumePendingCallJournal') return false;
        return true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await pumpApp(tester);
      await tester.tap(find.byTooltip('Нагадування та Журнал'));
      await finishSectionTransition(tester);
      await waitForText(
        tester,
        'Надайте Call Gate дозвіл на сповіщення, щоб нагадування спрацьовували вчасно при вимкненому екрані',
      );
      expect(find.text('Надати дозвіл'), findsOneWidget);

      notificationsGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await waitForText(tester, 'Створити нагадування');
      expect(
        find.text(
          'Надайте Call Gate дозвіл на сповіщення, щоб нагадування спрацьовували вчасно при вимкненому екрані',
        ),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Захист вхідних дзвінків'));
      await finishSectionTransition(tester);
      await waitForText(tester, 'Сповіщення дозволено');
      expect(find.text('Дозвіл на сповіщення'), findsOneWidget);
      await waitForDatabase(tester);
    },
  );

  testWidgets('contacts permission row explains missing access', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': true,
          'readContacts': false,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await waitForText(tester, 'Потрібен дозвіл для перевірки контактів');
    expect(
      find.text('Потрібен дозвіл для перевірки контактів'),
      findsOneWidget,
    );
    expect(find.text('Системну роль не надано'), findsNothing);
  });

  testWidgets('reminder cards display custom repeat badges', (tester) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': false,
          'notificationsGranted': false,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.runAsync(() async {
      final reminder = (await _testDatabase.getReminders()).first;
      await _testDatabase.updateReminderSchedule(
        id: reminder['id'] as int,
        remindAt: DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch,
        repeatType: 'custom',
        repeatInterval: 4,
      );
    });
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Олена Коваль');
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Кожні 4 дн.'), findsOneWidget);
    expect(find.byTooltip('Змінити дату й час нагадування'), findsWidgets);
  });

  test(
    'contact picker reports permission state and selected contact',
    () async {
      const channel = MethodChannel('com.wepr.callguard/contact-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var pickerCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'pickContact') {
          pickerCalls++;
          if (pickerCalls == 1) return {'permissionRequired': true};
          return {'name': 'Ada Lovelace', 'phone': '+441234567890'};
        }
        if (call.method == 'requestContactsPermission') {
          return {
            'roleAvailable': true,
            'callScreeningRole': false,
            'readContacts': true,
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final bridge = CallScreeningChannel(channel: channel);
      expect((await bridge.pickContact())?.permissionRequired, isTrue);
      expect((await bridge.requestContactsPermission()).readContacts, isTrue);
      final contact = await bridge.pickContact();
      expect(contact?.name, 'Ada Lovelace');
      expect(contact?.phone, '+441234567890');
    },
  );

  testWidgets('contact picker fills list and reminder forms', (tester) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var pickerCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'restorePendingReminders') return true;
      if (call.method == 'consumePendingCallJournal') return false;
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': false,
        };
      }
      if (call.method == 'pickContact') {
        pickerCalls++;
        return pickerCalls == 1
            ? {'permissionRequired': true}
            : {'name': 'Ada Lovelace', 'phone': '+441234567890'};
      }
      if (call.method == 'requestContactsPermission') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': true,
        };
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Мама');
    await tester.tap(find.byTooltip('Додати номер'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вибрати з контактів'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '+441234567890',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'Ada Lovelace',
    );
    await tester.tap(find.text('Скасувати'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Олена Коваль');
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await waitForText(tester, 'Створити нагадування');
    await tester.ensureVisible(find.text('Створити нагадування'));
    await tester.tap(find.text('Створити нагадування'));
    await tester.pumpAndSettle();
    expect(find.text('Повторювати'), findsOneWidget);
    expect(find.text('Одноразово'), findsOneWidget);
    expect(find.text('Щодня'), findsOneWidget);
    expect(find.text('Щотижня'), findsOneWidget);
    expect(find.text('Свій варіант'), findsOneWidget);
    await tester.tap(find.text('Вибрати з контактів'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '+441234567890',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      'Ada Lovelace',
    );
  });

  testWidgets('lets the user switch to the dark UI theme', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Темна'));
    await tester.pumpAndSettle();
    await waitForDatabase(tester);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.text('Тема оформлення'))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('test call button invokes the native rule engine channel', (
    tester,
  ) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? testedNumber;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': false,
        };
      }
      if (call.method == 'simulateCall') {
        testedNumber =
            (call.arguments as Map<Object?, Object?>)['phoneNumber'] as String;
        return {
          'verdict': 'REJECT',
          'reason': 'blacklist',
          'phoneNumber': testedNumber,
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final testButton = find.text('Тестовий виклик (перевірка правила)');
    await tester.ensureVisible(testButton);
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+380 67 555 01 01');
    await tester.tap(find.text('Перевірити номер'));
    await tester.pumpAndSettle();

    expect(testedNumber, '+380 67 555 01 01');
    expect(find.text('Цей виклик відхилено'), findsOneWidget);
    expect(
      find.text(
        'Діючі правила застосунку не дозволяють вхідний дзвінок із цього номера',
      ),
      findsOneWidget,
    );
    expect(find.text('Причина: Чорний список'), findsOneWidget);
  });

  testWidgets('renders the allowlist-only rejection reason', (tester) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': false,
        };
      }
      if (call.method == 'simulateCall') {
        return {
          'verdict': 'REJECT',
          'reason': 'allowlist_only',
          'phoneNumber': '+49 151 1234567',
        };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final testButton = find.text('Тестовий виклик (перевірка правила)');
    await tester.ensureVisible(testButton);
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+49 151 1234567');
    await tester.tap(find.text('Перевірити номер'));
    await tester.pumpAndSettle();

    expect(find.text('Цей виклик відхилено'), findsOneWidget);
    expect(find.text('Причина: Лише білий список'), findsOneWidget);
  });

  testWidgets('granted screening role can be changed from system settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var roleHeld = true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': roleHeld,
          'readContacts': true,
        };
      }
      if (call.method == 'openDefaultAppsSettings') {
        roleHeld = false;
        return true;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await waitForText(tester, 'Змінити / відкликати');
    await tester.ensureVisible(find.text('Змінити / відкликати'));
    await tester.tap(find.text('Змінити / відкликати'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Налаштування програм за замовчуванням'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await waitForText(tester, 'Надати системну роль');
    expect(find.text('Системну роль не надано'), findsOneWidget);
  });

  testWidgets('answering tab only offers quiet call-back options', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);
    await tester.pumpAndSettle();

    expect(find.text('Увімкнути сценарії відхилення дзвінків'), findsOneWidget);
    expect(find.text('У режимі тиші'), findsOneWidget);
    expect(find.text('Усі невідомі номери'), findsOneWidget);
    expect(find.text('Записувати повідомлення'), findsNothing);
    expect(find.text('Записати голос'), findsNothing);
  });

  testWidgets('callback assistant explains missing contacts permission', (
    tester,
  ) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': true,
          'readContacts': false,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      if (call.method == 'restorePendingReminders') return true;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Сценарії та нагадування');

    expect(find.text('Сценарії'), findsOneWidget);
    expect(find.text('Сценарії та нагадування'), findsOneWidget);
    await tester.tap(find.text('Усі невідомі номери'));
    await waitForText(
      tester,
      'Доступ до контактів потрібен, щоб відрізнити збережені номери від невідомих.',
    );
    expect(find.text('Надати доступ'), findsOneWidget);
  });

  testWidgets('callback assistant auto-remind and emergency settings work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': true,
          'readContacts': true,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      if (call.method == 'restorePendingReminders') return true;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);

    final autoRemindLabel = find.text('Автоматично нагадувати передзвонити');
    await tester.ensureVisible(autoRemindLabel);
    await tester.tap(autoRemindLabel);
    await tester.pump();
    expect(find.text('15 хв'), findsOneWidget);
    expect(find.text('30 хв'), findsOneWidget);
    expect(find.text('1 год'), findsOneWidget);
    await tester.tap(find.text('15 хв'));
    await tester.pump();

    final emergencyLabel = find.text('Екстрений прорив (3-й дзвінок за 5 хв)');
    await tester.ensureVisible(emergencyLabel);
    await tester.pump();
    await tester.tap(emergencyLabel);
    await tester.pump();

    // The app persists settings asynchronously; poll until the writes land.
    var settings = await tester.runAsync(_testDatabase.getSettings) ?? {};
    for (
      var attempt = 0;
      attempt < 20 && settings['answering_emergency_repeat'] != 'true';
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      settings = await tester.runAsync(_testDatabase.getSettings) ?? {};
    }
    expect(settings['answering_auto_remind'], 'true');
    expect(settings['answering_auto_remind_minutes'], '15');
    expect(settings['answering_emergency_repeat'], 'true');
  });

  testWidgets('profile menu opens About and Support dialogs', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') return null;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const screeningChannel = MethodChannel('com.wepr.callguard/screening');
    final openedUrls = <String>[];
    messenger.setMockMethodCallHandler(screeningChannel, (call) async {
      if (call.method == 'openExternalUrl') {
        openedUrls.add(call.arguments['url'] as String);
        return true;
      }
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': true,
          'readContacts': true,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(screeningChannel, null),
    );

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();

    final aboutMenuItem = find.text('Про додаток');
    await tester.ensureVisible(aboutMenuItem);
    await tester.tap(aboutMenuItem);
    await tester.pumpAndSettle();
    expect(find.text('Call Gate'), findsOneWidget);
    expect(find.textContaining('v1.8.0'), findsOneWidget);
    expect(find.textContaining('не надсилаються на сервер'), findsOneWidget);

    await tester.tap(find.text('Закрити вікно'));
    await tester.pumpAndSettle();
    final supportMenuItem = find.text('Підтримати проєкт');
    await tester.ensureVisible(supportMenuItem);
    await tester.tap(supportMenuItem);
    await tester.pumpAndSettle();
    expect(find.text('Підтримати через Monobank'), findsOneWidget);
    expect(find.text('Підтримати через Monobank'), findsOneWidget);
    expect(find.text('Підтримати на Ko-fi'), findsOneWidget);
    expect(find.text('Поділитися застосунком'), findsOneWidget);
    expect(find.text('Оцінити застосунок'), findsOneWidget);
    expect(find.text('Закрити вікно'), findsOneWidget);
    expect(find.text('Зрозуміло'), findsNothing);
    expect(find.text('Копіювати посилання'), findsNothing);

    await tester.tap(find.text('Підтримати через Monobank'));
    await tester.pumpAndSettle();
    expect(openedUrls, contains('https://send.monobank.ua/jar/AhQrx7NK3q'));
  });

  testWidgets('changes the app language and shows country operators', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🇬🇧  English'));
    await tester.pumpAndSettle();
    await waitForDatabase(tester);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    expect(find.text('Incoming call protection'), findsOneWidget);
    expect(find.text('Protection is active'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Lists & filters'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Countries & operators');
    await tester.tap(find.text('Countries & operators'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Ukraine');
    expect(find.text('Ukraine'), findsOneWidget);
  });

  testWidgets('expands countries to reveal their mobile operators', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Країни та оператори');
    await tester.tap(find.text('Країни та оператори'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Україна');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Україна'));
    await tester.pumpAndSettle();

    expect(find.text('Київстар'), findsOneWidget);
    expect(find.text('Vodafone UA'), findsOneWidget);
    expect(find.text('Укртелеком / Київ (044)'), findsOneWidget);
    expect(find.text('+380 44'), findsOneWidget);
    expect(find.text('+380 67'), findsOneWidget);
  });

  testWidgets('country FAB offers country and operator additions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Країни та оператори');
    await tester.tap(find.text('Країни та оператори'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Україна');
    await tester.tap(find.byTooltip('Додати країну або оператора'));
    await tester.pumpAndSettle();

    expect(find.text('Додати країну'), findsOneWidget);
    expect(find.text('Додати оператора'), findsOneWidget);
    await tester.tap(find.text('Додати оператора'));
    await tester.pumpAndSettle();
    expect(find.text('Мережеві префікси (NDC)'), findsOneWidget);
  });

  testWidgets('openCallJournal deep link selects the journal segment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': false,
          'notificationsGranted': false,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Олена Коваль');
    expect(find.text('Останні блокування'), findsNothing);

    await messenger.handlePlatformMessage(
      'com.wepr.callguard/screening',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('openCallJournal'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Останні блокування'), findsOneWidget);
    expect(find.text('Нагадування про дзвінки'), findsOneWidget);
    expect(find.text('Олена Коваль'), findsNothing);
  });

  testWidgets('operator search matches localized name case-insensitively', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Країни та оператори');
    await tester.tap(find.text('Країни та оператори'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Україна');

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'КИЇВСТАР');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Україна'));
    await tester.pumpAndSettle();

    expect(find.text('Київстар'), findsOneWidget);
    expect(find.text('Vodafone UA'), findsNothing);
    expect(find.text('lifecell'), findsNothing);
  });

  test('dictionaries stay complete with identical placeholders', () {
    final dictionaries = <String, Map<String, String>>{
      'uk': stringsUk,
      'en': stringsEn,
      'pl': stringsPl,
      'de': stringsDe,
      'es': stringsEs,
      'fr': stringsFr,
    };
    final referenceKeys = stringsUk.keys.toSet();
    final placeholder = RegExp(r'\{[^}]+\}');
    Set<String> placeholders(String text) =>
        placeholder.allMatches(text).map((match) => match.group(0)!).toSet();

    for (final entry in dictionaries.entries) {
      expect(
        entry.value.keys.toSet(),
        referenceKeys,
        reason: '${entry.key} dictionary keys must match Ukrainian',
      );
      for (final key in referenceKeys) {
        expect(
          placeholders(entry.value[key]!),
          placeholders(stringsUk[key]!),
          reason: '${entry.key}.$key placeholders must match Ukrainian',
        );
      }
    }

    const removedKeys = {
      'prototypeFootnote',
      'answeringActionRemind30',
      'answeringActionWhitelist',
      'answeringActionSms',
      'answeringSmsTemplate',
      'answering_machine',
      'reasonCountry',
      'reasonHidden',
      'reasonSilence',
    };
    for (final entry in dictionaries.entries) {
      for (final removed in removedKeys) {
        expect(
          entry.value.containsKey(removed),
          isFalse,
          reason: '${entry.key} still contains dead key $removed',
        );
      }
      for (final key in ['scheduleActive', 'journalDemoHint']) {
        final text = entry.value[key]!.toLowerCase();
        expect(text, isNot(contains('demo')), reason: '${entry.key}.$key');
        expect(text, isNot(contains('демо')), reason: '${entry.key}.$key');
        expect(text, isNot(contains('démo')), reason: '${entry.key}.$key');
      }
    }
  });
}

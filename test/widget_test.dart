import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:call_guard/data/database_helper.dart';
import 'package:call_guard/data/world_countries.dart';
import 'package:call_guard/main.dart';
import 'package:call_guard/l10n/app_strings.dart';
import 'package:call_guard/l10n/strings_de.dart';
import 'package:call_guard/l10n/strings_en.dart';
import 'package:call_guard/l10n/strings_es.dart';
import 'package:call_guard/l10n/strings_fr.dart';
import 'package:call_guard/l10n/strings_pl.dart';
import 'package:call_guard/l10n/strings_uk.dart';
import 'package:call_guard/platform/call_screening_channel.dart';
import 'package:call_guard/theme/app_palette.dart';
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
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await _testDatabase.getSettings();
    });
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

  test(
    'fresh database seeds defaults and catalogs but not user records',
    () async {
      final settings = await _testDatabase.getSettings();
      final countries = await _testDatabase.getCountries();
      expect(settings['locale'], 'ukrainian');
      expect(settings['protection_enabled'], 'true');
      expect(settings[DatabaseHelper.settingBlockShortNumbers], 'false');
      expect(countries, hasLength(195));
      expect(worldCountries, hasLength(195));
      expect(await _testDatabase.getOperators('UA'), hasLength(4));
      expect(await _testDatabase.getPhoneRules('white'), isEmpty);
      expect(await _testDatabase.getPhoneRules('black'), isEmpty);
      expect(await _testDatabase.getActiveTemporaryPhoneRules(), isEmpty);
      expect(await _testDatabase.getReminders(), isEmpty);
      expect(await _testDatabase.getCallLogs(), isEmpty);
      expect(
        await _testDatabase.getIndexNamesForTesting(),
        containsAll(<String>[
          'idx_phone_rules_list_type',
          'idx_operator_rules_country_id',
          'idx_call_reminders_pending',
          'idx_call_logs_timestamp',
        ]),
      );
    },
  );

  test('callback assistant settings default safely and persist', () async {
    final defaults = await _testDatabase.getSettings();
    expect(defaults['answering_auto_remind'], 'false');
    expect(defaults['answering_auto_remind_minutes'], '30');
    expect(defaults['answering_emergency_repeat'], 'false');
    expect(defaults['driving_mode'], 'false');
    expect(defaults['status_tray_icon_enabled'], 'true');
    expect(defaults['status_tray_user_overridden'], 'false');
    expect(defaults['status_tray_activated'], 'false');

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

  test(
    'expired phone rules are removed while active and permanent rules remain',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 777 00 01',
        label: 'Temporary allow',
        listType: 'white',
        expiresAt: now + const Duration(hours: 1).inMilliseconds,
      );
      final expiredId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 777 00 02',
        label: 'Expired block',
        listType: 'black',
        expiresAt: now - const Duration(minutes: 1).inMilliseconds,
      );
      final permanentId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 777 00 03',
        label: 'Permanent',
        listType: 'white',
      );

      final whiteRules = await _testDatabase.getPhoneRules('white');
      final activeTemporaries = await _testDatabase
          .getActiveTemporaryPhoneRules();
      final blackRules = await _testDatabase.getPhoneRules('black');
      expect(whiteRules.any((row) => row['id'] == activeId), isTrue);
      expect(
        whiteRules.singleWhere((row) => row['id'] == permanentId)['expires_at'],
        isNull,
      );
      expect(activeTemporaries.single['id'], activeId);
      expect(blackRules.any((row) => row['id'] == expiredId), isFalse);

      await _testDatabase.makePhoneRulePermanent(activeId);
      final nowPermanent = (await _testDatabase.getPhoneRules('white'))
          .singleWhere((row) => row['id'] == activeId);
      expect(nowPermanent['expires_at'], isNull);
    },
  );

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
    'legacy phone rules migrate expires_at without losing permanent entries',
    () async {
      const databasePath = 'test/call_guard_legacy_phone_rules_test.db';
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
        version: 5,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE phone_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone TEXT NOT NULL,
            label TEXT,
            list_type TEXT NOT NULL,
            created_at INTEGER
          )
        ''');
          await db.insert('phone_rules', {
            'phone': '+380 44 123 45 67',
            'label': 'Legacy permanent',
            'list_type': 'white',
            'created_at': 4567,
          });
        },
      );
      await legacyDatabase.close();

      final migrated = DatabaseHelper.forTesting(databasePath: databasePath);
      await migrated.initialize();
      final rules = await migrated.getPhoneRules('white');
      expect(rules.single['phone'], '+380 44 123 45 67');
      expect(rules.single['label'], 'Legacy permanent');
      expect(rules.single['expires_at'], isNull);
      await migrated.close();
    },
  );

  test(
    'active temporary rules are retained and expired ones are purged',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final activeId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 123 00 01',
        label: 'Active temp',
        listType: 'white',
        expiresAt: now + const Duration(hours: 1).inMilliseconds,
      );
      final expiredId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 123 00 02',
        label: 'Expired temp',
        listType: 'black',
        expiresAt: now - const Duration(minutes: 1).inMilliseconds,
      );
      final permanentId = await _testDatabase.insertPhoneRule(
        phone: '+380 44 123 00 03',
        label: 'Permanent',
        listType: 'white',
      );

      final temporary = await _testDatabase.getActiveTemporaryPhoneRules();
      expect(temporary.map((row) => row['id']), [activeId]);
      expect(
        (await _testDatabase.getPhoneRules('black'))
            .any((row) => row['id'] == expiredId),
        isFalse,
      );
      expect(
        (await _testDatabase.getPhoneRules('white'))
            .singleWhere((row) => row['id'] == permanentId)['expires_at'],
        isNull,
      );
    },
  );

  test(
    'can edit a reminder time and delete or clear call log entries',
    () async {
      final reminderId = await _testDatabase.insertReminder(
        phone: '+380 67 123 45 67',
        contactName: 'Test Contact',
        remindAt: DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        note: 'Test reminder',
      );
      final newReminderAt = DateTime(2027, 2, 3, 14, 45).millisecondsSinceEpoch;
      await _testDatabase.updateReminderTime(reminderId, newReminderAt);
      expect(
        (await _testDatabase.getReminders()).firstWhere(
          (row) => row['id'] == reminderId,
        )['remind_at'],
        newReminderAt,
      );

      for (var index = 0; index < 3; index++) {
        await _testDatabase.insertCallLog(
          phone: '+380 44 123 45 6$index',
          reason: 'country_block',
          timestamp: DateTime.now()
              .subtract(Duration(minutes: index))
              .millisecondsSinceEpoch,
        );
      }
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
      await firstOpen.insertCallLog(
        phone: '+49 151 1234567',
        reason: 'country_block',
        timestamp: DateTime(2026, 11, 1).millisecondsSinceEpoch,
      );
      await firstOpen.deleteCountry('ES');
      await firstOpen.deleteCountry('FR');
      expect(phoneId, greaterThan(0));
      await firstOpen.close();

      final reopened = DatabaseHelper.forTesting(databasePath: databasePath);
      await reopened.initialize();
      expect((await reopened.getSettings())['locale'], 'french');
      expect((await reopened.getSettings())['theme_mode'], 'dark');
      expect((await reopened.getSettings())['silence_weekdays'], '');
      expect(
        (await reopened.getCountries()).map((row) => row['iso_code']),
        containsAll(['ES', 'FR']),
      );
      expect(await reopened.getOperators('ES'), hasLength(5));
      expect(await reopened.getOperators('FR'), hasLength(5));
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
    expect(find.text('Відхиляти невідомі / приватні номери'), findsOneWidget);
    expect(find.text('Відхиляти номери поза адресною книгою'), findsOneWidget);
    expect(find.text('Режим «За кермом»'), findsOneWidget);
    expect(
      find.text(
        'Блокувати всі вхідні дзвінки (навіть із білого списку); усі відхилені виклики зберігаються в журналі',
      ),
      findsOneWidget,
    );
    const privacyMessage =
        'CallGate працює повністю локально на вашому пристрої, без доступу до інтернету та збору особистих даних. Застосунок є повністю безкоштовним, без реклами й прихованих платежів — і завжди залишатиметься таким.';
    await tester.scrollUntilVisible(
      find.text(privacyMessage),
      250,
      scrollable: homeScrollable(),
    );
    expect(find.text(privacyMessage), findsOneWidget);
  });

  testWidgets('native status mode changes refresh Flutter settings', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.runAsync(() async {
      await _testDatabase.setSetting('protection_enabled', false);
      await _testDatabase.setSetting('driving_mode', true);
    });

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final refreshResponse = messenger.handlePlatformMessage(
      'com.wepr.callguard/screening',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('statusModesChanged'),
      ),
      (_) {},
    );
    await waitForText(tester, 'Захист призупинено');
    await refreshResponse;

    final drivingLabel = find.text('Режим «За кермом»');
    await tester.scrollUntilVisible(
      drivingLabel,
      250,
      scrollable: homeScrollable(),
    );
    final drivingSwitch = find
        .ancestor(of: drivingLabel, matching: find.byType(SwitchListTile))
        .first;
    expect(tester.widget<SwitchListTile>(drivingSwitch).value, isTrue);
  });

  testWidgets(
    'home groups manual silence under quick rules and has no standard card',
    (tester) async {
      await pumpApp(tester);
      expect(find.text('Стандартний режим'), findsNothing);
      expect(find.text('Розумний фільтр вхідних дзвінків'), findsOneWidget);
      expect(find.text('Журнал блокувань'), findsNothing);
      expect(find.text('Останні блокування'), findsNothing);

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
      await tester.scrollUntilVisible(
        find.text('Тимчасові правила'),
        220,
        scrollable: homeScrollable(),
      );
      expect(
        find.text(
          'Дозволити або заблокувати вхідний номер на 1 год, добу чи обраний час',
        ),
        findsOneWidget,
      );
      final temporaryDescription = find.text(
        'Дозволити або заблокувати вхідний номер на 1 год, добу чи обраний час',
      );
      final temporaryHeaderRow = find
          .ancestor(of: temporaryDescription, matching: find.byType(Row))
          .first;
      expect(
        find.descendant(
          of: temporaryHeaderRow,
          matching: find.text('Тимчасові правила'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: temporaryHeaderRow, matching: find.text('Додати')),
        findsOneWidget,
      );
      expect(find.text('Додати'), findsOneWidget);
    },
  );

  testWidgets('short-number switch is shown and persists its setting', (
    tester,
  ) async {
    await pumpApp(tester);
    final label = find.text('Короткі та службові номери');
    await tester.scrollUntilVisible(label, 250, scrollable: homeScrollable());

    final switchTile = find
        .ancestor(of: label, matching: find.byType(SwitchListTile))
        .first;
    expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
    expect(
      find.text(
        'Блокувати вхідні виклики з коротких кодів (2–6 цифр), крім контактів та екстрених служб',
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(switchTile);
    await tester.pump();
    await tester.tap(switchTile);
    await tester.pump();
    final savedSettings = await tester.runAsync(_testDatabase.getSettings);

    expect(savedSettings?[DatabaseHelper.settingBlockShortNumbers], 'true');
    expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
  });

  testWidgets(
    'Home opens the temporary-rule dialog with action and duration choices',
    (tester) async {
      await pumpApp(tester);
      await tester.scrollUntilVisible(
        find.text('Тимчасові правила'),
        220,
        scrollable: homeScrollable(),
      );
      final temporaryCard = find
          .ancestor(
            of: find.text('Тимчасові правила'),
            matching: find.byType(AppPanel),
          )
          .first;
      await tester.tap(
        find.descendant(of: temporaryCard, matching: find.text('Додати')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Тимчасове правило'), findsOneWidget);
      expect(find.text('Із контактів'), findsOneWidget);
      expect(find.text('Із історії викликів'), findsOneWidget);
      final oneHour = tester.widget<ChoiceChip>(
        find
            .ancestor(of: find.text('1 год'), matching: find.byType(ChoiceChip))
            .first,
      );
      expect(oneHour.selected, isTrue);
      await tester.tap(find.text('Відхиляти (у Чорний список)'));
      await tester.pump();
      final actionGroup = tester.widget<SegmentedButton<String>>(
        find
            .ancestor(
              of: find.text('Відхиляти (у Чорний список)'),
              matching: find.byType(SegmentedButton<String>),
            )
            .first,
      );
      expect(actionGroup.selected, {'black'});

      await tester.tap(find.text('24 год'));
      await tester.pump();
      final oneDay = tester.widget<ChoiceChip>(
        find
            .ancestor(
              of: find.text('24 год'),
              matching: find.byType(ChoiceChip),
            )
            .first,
      );
      expect(oneDay.selected, isTrue);
    },
  );

  testWidgets(
    'call history picker fills white, black and temporary rule forms on demand',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const screeningChannel = MethodChannel('com.wepr.callguard/screening');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var historyRequests = 0;
      messenger.setMockMethodCallHandler(screeningChannel, (call) async {
        if (call.method == 'checkPermissions') {
          return {
            'roleAvailable': true,
            'callScreeningRole': true,
            'readContacts': true,
            'notificationsGranted': true,
          };
        }
        if (call.method == 'consumePendingCallJournal') return false;
        if (call.method == 'getRecentCallLog') {
          historyRequests++;
          return {
            'permissionGranted': true,
            'permanentlyDenied': false,
            'calls': [
              {
                'number': '+1 (202) 555-0198',
                'name': 'Avery Quinn',
                'type': 'missed',
                'timestamp': DateTime(2026, 11, 17, 12).millisecondsSinceEpoch,
              },
            ],
          };
        }
        return true;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(screeningChannel, null),
      );

      Future<void> selectHistoryEntry() async {
        final historyButton = find.text('Із історії викликів');
        await tester.ensureVisible(historyButton);
        await tester.tap(historyButton);
        await tester.pump(const Duration(milliseconds: 450));
        await waitForText(tester, 'Avery Quinn');
        expect(find.textContaining('Пропущений'), findsOneWidget);
        await tester.tap(find.text('Avery Quinn'));
        await tester.pump(const Duration(milliseconds: 450));
        final fields = find.byType(TextField);
        expect(
          tester.widget<TextField>(fields.first).controller!.text,
          '+12025550198',
        );
        expect(
          tester.widget<TextField>(fields.at(1)).controller!.text,
          'Avery Quinn',
        );
      }

      await pumpApp(tester);
      expect(
        historyRequests,
        0,
        reason: 'call history is never read at startup',
      );

      await tester.tap(find.byTooltip('Списки та фільтри'));
      await finishSectionTransition(tester);
      await waitForDatabase(tester);
      await tester.tap(find.byTooltip('Додати номер'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Вибрати з контактів'), findsOneWidget);
      expect(find.text('Із історії викликів'), findsOneWidget);
      expect(historyRequests, 0);
      await selectHistoryEntry();
      expect(historyRequests, 1);
      await tester.tap(find.text('Скасувати'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Чорний список'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byTooltip('Додати номер'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Із історії викликів'), findsOneWidget);
      await selectHistoryEntry();
      expect(historyRequests, 2);
      await tester.tap(find.text('Скасувати'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Захист вхідних дзвінків'));
      await finishSectionTransition(tester);
      await tester.scrollUntilVisible(
        find.text('Тимчасові правила'),
        220,
        scrollable: homeScrollable(),
      );
      final card = find
          .ancestor(
            of: find.text('Тимчасові правила'),
            matching: find.byType(AppPanel),
          )
          .first;
      await tester.tap(
        find.descendant(of: card, matching: find.text('Додати')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Із історії викликів'), findsOneWidget);
      await selectHistoryEntry();
      expect(historyRequests, 3);
    },
  );

  testWidgets('call history permission denial explains the next step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const screeningChannel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var settingsOpened = 0;
    messenger.setMockMethodCallHandler(screeningChannel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': true,
          'readContacts': true,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'consumePendingCallJournal') return false;
      if (call.method == 'getRecentCallLog') {
        return {
          'permissionGranted': false,
          'permanentlyDenied': true,
          'calls': const [],
        };
      }
      if (call.method == 'openCallLogSettings') {
        settingsOpened++;
        return true;
      }
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(screeningChannel, null),
    );

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForDatabase(tester);
    await tester.tap(find.byTooltip('Додати номер'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Із історії викликів'));
    await tester.pump(const Duration(milliseconds: 400));
    await waitForText(
      tester,
      'Щоб вибрати номер, потрібен дозвіл на доступ до історії викликів. Його можна надати лише за вашим запитом.',
    );
    expect(find.text('Відкрити налаштування'), findsOneWidget);
    await tester.tap(find.text('Відкрити налаштування'));
    expect(settingsOpened, 1);
  });

  testWidgets(
    'blocked journal entries can be added to permanent or temporary allow rules',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await _testDatabase.clearCallLogs();
        await _testDatabase.insertCallLog(
          phone: '+44 (20) 7123-4567',
          contactName: 'Allowed from journal',
          reason: 'blacklist',
          timestamp: DateTime(2026, 11, 18, 12).millisecondsSinceEpoch,
        );
        await _testDatabase.insertCallLog(
          phone: '+1 (202) 555-0183',
          contactName: 'Temporary from journal',
          reason: 'operator_block',
          timestamp: DateTime(2026, 11, 18, 11).millisecondsSinceEpoch,
        );
      });

      const screeningChannel = MethodChannel('com.wepr.callguard/screening');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(screeningChannel, (call) async {
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
      await tester.tap(find.byTooltip('Нагадування та Журнал'));
      await finishSectionTransition(tester);
      await waitForDatabase(tester);
      await tester.tap(find.text('Журнал блокувань'));
      await tester.pump(const Duration(milliseconds: 400));
      await waitForText(tester, 'Allowed from journal');

      Future<void> chooseQuickAdd(String contact, String option) async {
        final card = find
            .ancestor(of: find.text(contact), matching: find.byType(AppPanel))
            .first;
        await tester.ensureVisible(card);
        await tester.tap(
          find.descendant(of: card, matching: find.text('Додати в список')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('У Білий список'), findsOneWidget);
        expect(find.text('У Тимчасовий доступ (1 год)'), findsOneWidget);
        expect(find.text('У Тимчасовий доступ (24 год)'), findsOneWidget);
        await tester.ensureVisible(find.text(option));
        await tester.tap(find.text(option));
        await tester.pump(const Duration(milliseconds: 400));
        await waitForDatabase(tester);
      }

      await chooseQuickAdd('Allowed from journal', 'У Білий список');
      final whiteRules = await tester.runAsync(
        () => _testDatabase.getPhoneRules('white'),
      );
      expect(whiteRules!.map((row) => row['phone']), contains('+442071234567'));

      await chooseQuickAdd(
        'Temporary from journal',
        'У Тимчасовий доступ (1 год)',
      );
      final temporaryRules = await tester.runAsync(
        _testDatabase.getActiveTemporaryPhoneRules,
      );
      expect(
        temporaryRules!.any(
          (row) =>
              row['phone'] == '+12025550183' && row['list_type'] == 'white',
        ),
        isTrue,
      );
    },
  );

  testWidgets('Home shows active temporary rules with action and time left', (
    tester,
  ) async {
    await tester.runAsync(
      () => _testDatabase.insertPhoneRule(
        phone: '+380 44 555 12 34',
        label: 'Temporary work contact',
        listType: 'white',
        expiresAt: DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
      ),
    );
    await pumpApp(tester);
    await waitForDatabase(tester);
    await tester.scrollUntilVisible(
      find.text('Temporary work contact'),
      220,
      scrollable: homeScrollable(),
    );
    expect(find.text('Temporary work contact'), findsOneWidget);
    expect(find.text('+380 44 555 12 34'), findsOneWidget);
    expect(find.textContaining('Дозволено · ще'), findsOneWidget);
    expect(find.byTooltip('Скасувати тимчасове правило'), findsOneWidget);
  });

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

  testWidgets(
    'scenarios are locked and the warning highlights when main protection is off',
    (tester) async {
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
      expect(find.text(warning), findsOneWidget);
      const toggleTitle = 'Увімкнути сценарії та нагадування';
      final toggle = find
          .ancestor(
            of: find.text(toggleTitle),
            matching: find.byType(SwitchListTile),
          )
          .first;
      expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
      final toggleOpacity = find
          .ancestor(of: toggle, matching: find.byType(Opacity))
          .first;
      expect(
        tester.widget<Opacity>(toggleOpacity).opacity,
        closeTo(0.45, 0.01),
      );

      final scenarioHeading = find.text('Сценарій відхилення');
      final scenarioBlock = find
          .ancestor(of: scenarioHeading, matching: find.byType(AbsorbPointer))
          .first;
      expect(tester.widget<AbsorbPointer>(scenarioBlock).absorbing, isTrue);
      final scenarioOpacity = find
          .ancestor(of: scenarioHeading, matching: find.byType(Opacity))
          .first;
      expect(
        tester.widget<Opacity>(scenarioOpacity).opacity,
        closeTo(0.45, 0.01),
      );

      await tester.tap(find.text(toggleTitle));
      await tester.pump(const Duration(milliseconds: 240));
      final warningContainer = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('scenarios-protection-warning')),
      );
      final decoration = warningContainer.decoration! as BoxDecoration;
      expect(decoration.border!.top.width, 2);
      final savedAfterDisabledTap = await tester.runAsync(
        _testDatabase.getSettings,
      );
      expect(savedAfterDisabledTap?['answering_enabled'], 'false');

      final settings = await tester.runAsync(_testDatabase.getSettings);
      expect(settings?['answering_scenario'], 'quiet_mode');
    },
  );

  testWidgets('scenario settings unlock only after enabling the module', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);

    const toggleTitle = 'Увімкнути сценарії та нагадування';
    final toggle = find
        .ancestor(
          of: find.text(toggleTitle),
          matching: find.byType(SwitchListTile),
        )
        .first;
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
    var scenarioBlock = find
        .ancestor(
          of: find.text('Сценарій відхилення'),
          matching: find.byType(AbsorbPointer),
        )
        .first;
    expect(tester.widget<AbsorbPointer>(scenarioBlock).absorbing, isTrue);
    var scenarioOpacity = find
        .ancestor(
          of: find.text('Сценарій відхилення'),
          matching: find.byType(Opacity),
        )
        .first;
    expect(
      tester.widget<Opacity>(scenarioOpacity).opacity,
      closeTo(0.45, 0.01),
    );

    await tester.tap(find.text(toggleTitle));
    await tester.pump();
    scenarioBlock = find
        .ancestor(
          of: find.text('Сценарій відхилення'),
          matching: find.byType(AbsorbPointer),
        )
        .first;
    expect(tester.widget<AbsorbPointer>(scenarioBlock).absorbing, isFalse);
    scenarioOpacity = find
        .ancestor(
          of: find.text('Сценарій відхилення'),
          matching: find.byType(Opacity),
        )
        .first;
    expect(tester.widget<Opacity>(scenarioOpacity).opacity, 1);
    await waitForDatabase(tester);
  });

  testWidgets('schedule warns and locks settings when main protection is off', (
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
    await tester.tap(find.byTooltip('Графік режиму тиші'));
    await finishSectionTransition(tester);

    const warning =
        'Основний захист на «Головній» вимкнено — графік режиму тиші зараз не застосовується.';
    expect(find.text(warning), findsOneWidget);
    const toggleTitle = 'Активувати за розкладом';
    final toggle = find
        .ancestor(
          of: find.text(toggleTitle),
          matching: find.byType(SwitchListTile),
        )
        .first;
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    final toggleOpacity = find
        .ancestor(of: toggle, matching: find.byType(Opacity))
        .first;
    expect(tester.widget<Opacity>(toggleOpacity).opacity, closeTo(0.45, 0.01));

    final settingsHeading = find.text('Часовий інтервал');
    final settingsBlock = find
        .ancestor(of: settingsHeading, matching: find.byType(AbsorbPointer))
        .first;
    expect(tester.widget<AbsorbPointer>(settingsBlock).absorbing, isTrue);
    final settingsOpacity = find
        .ancestor(of: settingsHeading, matching: find.byType(Opacity))
        .first;
    expect(
      tester.widget<Opacity>(settingsOpacity).opacity,
      closeTo(0.45, 0.01),
    );
    await tester.ensureVisible(find.text(toggleTitle));
    await tester.tap(find.text(toggleTitle));
    await tester.pump(const Duration(milliseconds: 240));
    final warningContainer = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('schedule-protection-warning')),
    );
    final decoration = warningContainer.decoration! as BoxDecoration;
    expect(decoration.border!.top.width, 2);
  });

  testWidgets('schedule settings stay locked until its schedule switch is on', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Графік режиму тиші'));
    await finishSectionTransition(tester);

    final settingsHeading = find.text('Часовий інтервал');
    var settingsBlock = find
        .ancestor(of: settingsHeading, matching: find.byType(AbsorbPointer))
        .first;
    expect(tester.widget<AbsorbPointer>(settingsBlock).absorbing, isTrue);
    final settingsOpacity = find
        .ancestor(of: settingsHeading, matching: find.byType(Opacity))
        .first;
    expect(
      tester.widget<Opacity>(settingsOpacity).opacity,
      closeTo(0.45, 0.01),
    );
    const toggleTitle = 'Активувати за розкладом';
    await tester.tap(find.text(toggleTitle));
    await tester.pump();
    settingsBlock = find
        .ancestor(of: settingsHeading, matching: find.byType(AbsorbPointer))
        .first;
    expect(tester.widget<AbsorbPointer>(settingsBlock).absorbing, isFalse);
    expect(tester.widget<Opacity>(settingsOpacity).opacity, 1);
    await waitForDatabase(tester);
  });

  testWidgets('lists warning does not prevent editing phone lists', (
    tester,
  ) async {
    await tester.runAsync(
      () => _testDatabase.setSetting('protection_enabled', false),
    );
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForDatabase(tester);

    const warning =
        'Основний захист на головній вимкнено — списки та фільтри зараз не застосовуються до вхідних дзвінків.';
    await waitForText(tester, warning);
    expect(find.text(warning), findsOneWidget);
    await tester.tap(find.byTooltip('Додати номер'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).first, '+380 44 123 45 67');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '+380 44 123 45 67',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Скасувати'));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('lists show temporary expiry and allow making a rule permanent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await _testDatabase.insertPhoneRule(
        phone: '+380 44 555 12 34',
        label: 'Temporary work',
        listType: 'white',
        expiresAt: DateTime.now()
            .add(const Duration(hours: 2))
            .millisecondsSinceEpoch,
      );
    });
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Списки та фільтри'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Temporary work');
    expect(find.text('Temporary work'), findsOneWidget);
    final temporaryEntry = find
        .ancestor(
          of: find.text('Temporary work'),
          matching: find.byType(AppPanel),
        )
        .first;
    expect(
      find.descendant(
        of: temporaryEntry,
        matching: find.byIcon(Icons.hourglass_bottom_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: temporaryEntry, matching: find.textContaining('до ')),
      findsOneWidget,
    );
    expect(find.byTooltip('Дії з тимчасовим правилом'), findsOneWidget);

    await tester.tap(find.byTooltip('Дії з тимчасовим правилом'));
    await tester.pump(const Duration(milliseconds: 350));
    await waitForText(tester, 'Зробити постійним');
    expect(find.text('Зробити постійним'), findsOneWidget);
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
        'CallGate працює повністю локально на вашому пристрої, без доступу до інтернету та збору особистих даних. Застосунок є повністю безкоштовним, без реклами й прихованих платежів — і завжди залишатиметься таким.';
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

    await waitForText(tester, 'Нагадувань поки немає.');
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

    await tester.runAsync(
      () => _testDatabase.insertReminder(
        phone: '+380 67 123 45 67',
        contactName: 'Test Contact',
        remindAt: DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        note: 'Test reminder',
      ),
    );
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Test Contact');

    expect(find.text('Позначити виконаним'), findsWidgets);
  });

  testWidgets('horizontal swipe changes the main navigation section', (
    tester,
  ) async {
    await tester.runAsync(
      () => _testDatabase.insertPhoneRule(
        phone: '+380 67 123 45 67',
        label: 'Мама',
        listType: 'white',
      ),
    );
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

  test('privacy banner and quick-rule copy are localized consistently', () {
    final expected = <AppLanguage, Map<String, String>>{
      AppLanguage.ukrainian: {
        'freeForeverMessage': 'CallGate працює повністю локально на вашому пристрої, без доступу до інтернету та збору особистих даних. Застосунок є повністю безкоштовним, без реклами й прихованих платежів — і завжди залишатиметься таким.',
        'quickHiddenSubtitle': 'Відхиляти невідомі / приватні номери',
        'quickNonContactsSubtitle': 'Відхиляти номери поза адресною книгою',
        'listsProtectionDisabledWarning': 'Основний захист на головній вимкнено — списки та фільтри зараз не застосовуються до вхідних дзвінків.',
        'answeringEnabledLabel': 'Увімкнути сценарії та нагадування',
      },
      AppLanguage.english: {
        'freeForeverMessage': 'CallGate runs completely locally on your device, with no internet access and no collection of personal data. The app is completely free, with no ads or hidden fees — and will always remain so.',
        'quickHiddenSubtitle': 'Reject unknown / private numbers',
        'quickNonContactsSubtitle': 'Reject numbers outside your address book',
        'listsProtectionDisabledWarning': 'Main protection on Home is off — lists and filters are currently not applied to incoming calls.',
        'answeringEnabledLabel': 'Enable Scenarios & Reminders',
      },
      AppLanguage.polish: {
        'freeForeverMessage': 'CallGate działa w pełni lokalnie na Twoim urządzeniu, bez dostępu do internetu i gromadzenia danych osobowych. Aplikacja jest całkowicie darmowa, bez reklam i ukrytych opłat — i taka pozostanie na zawsze.',
        'quickHiddenSubtitle': 'Odrzucaj nieznane / prywatne numery',
        'quickNonContactsSubtitle': 'Odrzucaj numery spoza książki adresowej',
        'listsProtectionDisabledWarning': 'Główna ochrona na ekranie głównym jest wyłączona — listy i filtry nie są obecnie stosowane do połączeń przychodzących.',
        'answeringEnabledLabel': 'Włącz scenariusze i przypomnienia',
      },
      AppLanguage.german: {
        'freeForeverMessage': 'CallGate arbeitet vollständig lokal auf Ihrem Gerät, ohne Internetzugang und ohne Erhebung personenbezogener Daten. Die App ist völlig kostenlos, ohne Werbung oder versteckte Gebühren – und wird es immer bleiben.',
        'quickHiddenSubtitle': 'Unbekannte / unterdrückte Nummern abweisen',
        'quickNonContactsSubtitle':
            'Nummern außerhalb des Adressbuchs abweisen',
        'listsProtectionDisabledWarning': 'Der Hauptschutz auf der Startseite ist deaktiviert – Listen und Filter werden derzeit nicht auf eingehende Anrufe angewendet.',
        'answeringEnabledLabel': 'Szenarien & Erinnerungen aktivieren',
      },
      AppLanguage.spanish: {
        'freeForeverMessage': 'CallGate funciona completamente de forma local en tu dispositivo, sin acceso a internet ni recopilación de datos personales. La aplicación es totalmente gratuita, sin anuncios ni pagos ocultos, y siempre seguirá siéndolo.',
        'quickHiddenSubtitle': 'Rechazar números desconocidos / privados',
        'quickNonContactsSubtitle': 'Rechazar números fuera de la agenda',
        'listsProtectionDisabledWarning': 'La protección principal en Inicio está desactivada: las listas y filtros no se aplican actualmente a las llamadas entrantes.',
        'answeringEnabledLabel': 'Activar escenarios y recordatorios',
      },
      AppLanguage.french: {
        'freeForeverMessage': "CallGate fonctionne entièrement en local sur votre appareil, sans accès à Internet ni collecte de données personnelles. L'application est entièrement gratuite, sans publicité ni frais cachés — et le restera toujours.",
        'quickHiddenSubtitle': 'Rejeter les numéros inconnus / privés',
        'quickNonContactsSubtitle':
            "Rejeter les numéros hors du carnet d'adresses",
        'listsProtectionDisabledWarning': "La protection principale sur l'écran d'accueil est désactivée — les listes et filtres ne s'appliquent pas actuellement aux appels entrants.",
        'answeringEnabledLabel': 'Activer les scénarios et rappels',
      },
    };
    for (final entry in expected.entries) {
      final strings = AppStrings(entry.key);
      for (final translation in entry.value.entries) {
        expect(
          strings.call(translation.key),
          translation.value,
          reason: '${entry.key.label}: ${translation.key}',
        );
      }
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
      await bridge.updateStatusIndicator(
        enabled: true,
        protectionEnabled: true,
        drivingMode: false,
        locale: 'english',
      );
      await bridge.openDefaultAppsSettings();
      await bridge.openDialer('+380 67 123 45 67');

      expect(calls.map((call) => call.method), [
        'requestNotificationPermission',
        'scheduleReminder',
        'cancelReminder',
        'restorePendingReminders',
        'openNotificationSettings',
        'updateStatusIndicator',
        'openDefaultAppsSettings',
        'openDialer',
      ]);
      expect(calls[1].arguments, {'id': 21, 'remindAt': 1_900_000_000_000});
      expect(calls[5].arguments, {
        'enabled': true,
        'protectionEnabled': true,
        'drivingMode': false,
        'locale': 'english',
      });
      expect(calls[7].arguments, {'phoneNumber': '+380 67 123 45 67'});
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
      final reminderId = await _testDatabase.insertReminder(
        phone: '+380 67 123 45 67',
        contactName: 'Олена Коваль',
        remindAt: DateTime.now()
            .add(const Duration(days: 3))
            .millisecondsSinceEpoch,
        note: 'Test reminder',
      );
      await _testDatabase.updateReminderSchedule(
        id: reminderId,
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
        if (call.method == 'lookupContactName') return 'Ada Lovelace';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final bridge = CallScreeningChannel(channel: channel);
      expect((await bridge.pickContact())?.permissionRequired, isTrue);
      expect((await bridge.requestContactsPermission()).readContacts, isTrue);
      final contact = await bridge.pickContact();
      expect(contact?.name, 'Ada Lovelace');
      expect(contact?.phone, '+441234567890');
      expect(await bridge.lookupContactName('+441234567890'), 'Ada Lovelace');
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

    await tester.runAsync(
      () => _testDatabase.insertPhoneRule(
        phone: '+380 67 123 45 67',
        label: 'Мама',
        listType: 'white',
      ),
    );
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
    await waitForText(tester, 'Нагадувань поки немає.');
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

  testWidgets('test call button opens the rule simulator', (tester) async {
    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final testButton = find.text('Тестовий виклик (перевірка правила)');
    await tester.ensureVisible(testButton);
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    expect(find.text('Тестовий виклик'), findsOneWidget);
    expect(find.text('Перевірити номер'), findsOneWidget);
  });

  testWidgets('test call uses the live short-number switch and allowlist', (
    tester,
  ) async {
    const channel = MethodChannel('com.wepr.callguard/screening');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'checkPermissions') {
        return {
          'roleAvailable': true,
          'callScreeningRole': false,
          'readContacts': true,
          'notificationsGranted': true,
        };
      }
      if (call.method == 'lookupContactName') return null;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await pumpApp(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final testButton = find.text('Тестовий виклик (перевірка правила)');

    Future<void> openTestDialog() async {
      await tester.ensureVisible(testButton);
      await tester.tap(testButton);
      await tester.pumpAndSettle();
    }

    Future<void> evaluateNumber(String expectedVerdict) async {
      final input = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(input, '3700');
      await tester.tap(find.text('Перевірити номер'));
      await tester.pump();
      await waitForText(tester, expectedVerdict);
    }

    void expectVerdictColor(String label, Color color) {
      final labelFinder = find.text(label);
      expect(labelFinder, findsOneWidget);
      expect(
        tester.widget<Text>(labelFinder).style!.color,
        AppPalette.accent(color),
      );
    }

    // With the filter off, the simulator allows the short number.
    await openTestDialog();
    await evaluateNumber('Цей виклик дозволено');
    expectVerdictColor('Цей виклик дозволено', AppPalette.green);
    expect(
      find.textContaining('Правило дозволяє вхідний дзвінок'),
      findsOneWidget,
    );
    await tester.tap(find.text('Закрити вікно'));
    await tester.pumpAndSettle();

    // The live app value must win even if the persisted value is stale.
    final shortNumbersTitle = find.text('Короткі та службові номери');
    await tester.ensureVisible(shortNumbersTitle);
    final shortNumbersSwitch = find
        .ancestor(of: shortNumbersTitle, matching: find.byType(SwitchListTile))
        .first;
    await tester.tap(shortNumbersSwitch);
    await tester.pump();
    await waitForDatabase(tester);
    expect(tester.widget<SwitchListTile>(shortNumbersSwitch).value, isTrue);
    await tester.runAsync(
      () => _testDatabase.setSetting(
        DatabaseHelper.settingBlockShortNumbers,
        false,
      ),
    );

    await openTestDialog();
    await evaluateNumber('Цей виклик відхилено');
    expectVerdictColor('Цей виклик відхилено', AppPalette.red);
    expect(
      find.textContaining('Короткий або службовий номер заблоковано'),
      findsOneWidget,
    );
    await tester.tap(find.text('Закрити вікно'));
    await tester.pumpAndSettle();

    // A white-listed short number is still allowed while blocking is on.
    await tester.runAsync(
      () => _testDatabase.insertPhoneRule(
        phone: '3700',
        label: 'Test allow',
        listType: 'white',
      ),
    );
    await openTestDialog();
    await evaluateNumber('Цей виклик дозволено');
    expectVerdictColor('Цей виклик дозволено', AppPalette.green);
    expect(find.textContaining('Білий список'), findsOneWidget);
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

    expect(find.text('Увімкнути сценарії та нагадування'), findsOneWidget);
    expect(find.text('У режимі тиші'), findsOneWidget);
    expect(find.text('Усі невідомі номери'), findsOneWidget);
    expect(find.text('Записувати повідомлення'), findsNothing);
    expect(find.text('Записати голос'), findsNothing);
  });

  testWidgets('callback assistant explains missing contacts permission', (
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
      if (call.method == 'restorePendingReminders') return true;
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.runAsync(() async {
      await _testDatabase.setSetting('answering_enabled', true);
      await _testDatabase.setSetting('answering_scenario', 'unknown_numbers');
    });
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Сценарії та нагадування'));
    await finishSectionTransition(tester);
    await waitForText(tester, 'Сценарії та нагадування');

    expect(find.text('Сценарії'), findsOneWidget);
    expect(find.text('Сценарії та нагадування'), findsOneWidget);
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
    expect(find.textContaining('v2.0.1'), findsOneWidget);
    expect(find.text('© 2026 CyberDesignTech Dev'), findsOneWidget);
    expect(
      find.textContaining('CyberDesignTech Dev із фокусом'),
      findsOneWidget,
    );
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

  testWidgets('More tab shows the localized developer attribution footer', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Нагадування та Журнал'));
    await finishSectionTransition(tester);
    await waitForDatabase(tester);

    final copyright = find.text('© 2026 CyberDesignTech Dev');
    final collective = find.text('Незалежне об’єднання розробників');
    await tester.drag(find.byType(ListView).last, const Offset(0, -1800));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(copyright);
    await tester.ensureVisible(collective);

    expect(copyright, findsOneWidget);
    expect(collective, findsOneWidget);
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
    await waitForDatabase(tester);
    await tester.scrollUntilVisible(
      find.text('Ukraine'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
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
    await waitForText(tester, 'Нагадувань поки немає.');
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
    expect(find.text('Записів у журналі поки немає.'), findsOneWidget);
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

  testWidgets('world country search blocks and lists active country filters', (
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

    expect(find.text('ДЕТАЛЬНІ КРАЇНИ ТА ОПЕРАТОРИ'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '+39');
    await tester.pumpAndSettle();
    expect(find.text('Італія'), findsOneWidget);
    expect(find.text('Ватикан'), findsOneWidget);
    expect(find.text('Україна'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Італія');
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'), findsOneWidget);
    expect(find.byKey(const Key('world-country-IT-active')), findsOneWidget);
    expect(find.byKey(const Key('world-country-IT-all')), findsNothing);
    expect(find.text('УСІ КРАЇНИ СВІТУ'), findsNothing);
    await tester.runAsync(() async {
      final italy = (await _testDatabase.getCountries()).singleWhere(
        (row) => row['iso_code'] == 'IT',
      );
      expect(italy['action'], 'block');
    });
  });

  testWidgets(
    'world country moves between active and all lists without duplicates',
    (tester) async {
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

      final scrollable = find
          .descendant(
            of: find.byKey(const PageStorageKey('countryOperatorsList')),
            matching: find.byType(Scrollable),
          )
          .first;
      final auAll = find.byKey(const Key('world-country-AU-all'));
      final auActive = find.byKey(const Key('world-country-AU-active'));
      final atAll = find.byKey(const Key('world-country-AT-all'));
      Finder switchIn(Finder row) =>
          find.descendant(of: row, matching: find.byType(Switch));

      // Normal mode: Australia appears only in «Усі країни світу».
      expect(find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'), findsNothing);
      await tester.scrollUntilVisible(auAll, 300, scrollable: scrollable);
      expect(auAll, findsOneWidget);
      expect(auActive, findsNothing);

      // Enabling it moves it to «Активні фільтри країн».
      await tester.tap(switchIn(auAll));
      await tester.pumpAndSettle();
      await waitForDatabase(tester);
      await tester.scrollUntilVisible(
        find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'),
        -100,
        scrollable: scrollable,
      );
      expect(find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'), findsOneWidget);
      expect(auActive, findsOneWidget);
      expect(auAll, findsNothing);

      // It no longer sits in its alphabetical place in the general list.
      await tester.scrollUntilVisible(atAll, 300, scrollable: scrollable);
      expect(atAll, findsOneWidget);
      expect(auAll, findsNothing);

      // Disabling it in the active section returns it to the general list.
      await tester.scrollUntilVisible(auActive, -300, scrollable: scrollable);
      await tester.tap(switchIn(auActive));
      await tester.pumpAndSettle();
      await waitForDatabase(tester);
      expect(find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'), findsNothing);
      await tester.scrollUntilVisible(auAll, 300, scrollable: scrollable);
      expect(auAll, findsOneWidget);
      expect(auActive, findsNothing);

      // Search mode: exactly one row per country, switching sections.
      await tester.scrollUntilVisible(
        find.byType(TextField),
        -400,
        scrollable: scrollable,
      );
      await tester.enterText(find.byType(TextField), 'Австралія');
      await tester.pumpAndSettle();
      expect(auAll, findsOneWidget);
      expect(auActive, findsNothing);

      await tester.tap(switchIn(auAll));
      await tester.pumpAndSettle();
      await waitForDatabase(tester);
      expect(auActive, findsOneWidget);
      expect(auAll, findsNothing);
      expect(find.text('УСІ КРАЇНИ СВІТУ'), findsNothing);

      await tester.tap(switchIn(auActive));
      await tester.pumpAndSettle();
      await waitForDatabase(tester);
      expect(auAll, findsOneWidget);
      expect(auActive, findsNothing);
      expect(find.text('АКТИВНІ ФІЛЬТРИ КРАЇН'), findsNothing);
    },
  );

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

    const collectiveLabels = {
      'uk': 'Незалежне об’єднання розробників',
      'en': 'Independent developers collective',
      'pl': 'Niezależny zespół programistów',
      'de': 'Unabhängiges Entwicklerkollektiv',
      'es': 'Colectivo independiente de desarrolladores',
      'fr': 'Collectif indépendant de développeurs',
    };
    const aboutDescriptions = {
      'uk': 'Розроблено незалежним об’єднанням розробників CyberDesignTech Dev із фокусом на локальну приватність, швидкість та безпеку без хмарних сервісів.',
      'en': 'Developed by CyberDesignTech Dev, an independent developers collective focused on local privacy, speed, and security without cloud services.',
      'pl': 'Stworzone przez CyberDesignTech Dev — niezależny zespół programistów skupiony na lokalnej prywatności, szybkości i bezpieczeństwie bez chmury.',
      'de': 'Entwickelt von CyberDesignTech Dev, einem unabhängigen Entwicklerkollektiv mit Fokus auf lokale Privatsphäre, Geschwindigkeit und Sicherheit ohne Cloud-Dienste.',
      'es': 'Desarrollado por CyberDesignTech Dev, un colectivo independiente de desarrolladores centrado en la privacidad local, la velocidad y la seguridad sin servicios en la nube.',
      'fr': 'Développé par CyberDesignTech Dev, un collectif indépendant de développeurs axé sur la confidentialité locale, la rapidité et la sécurité sans services cloud.',
    };
    const temporaryDescriptions = {
      'uk': 'Дозволити або заблокувати вхідний номер на 1 год, добу чи обраний час',
      'en': 'Allow or block an incoming number for 1 hour, 24 hours, or a custom time',
      'pl': 'Zezwól lub zablokuj numer przychodzący na 1 godz., dobę lub wybrany czas',
      'de': 'Eingehende Nummer für 1 Std., 24 Std. oder eine gewählte Zeit erlauben oder blockieren',
      'es': 'Permitir o bloquear un número entrante durante 1 h, 24 h o un tiempo elegido',
      'fr': 'Autoriser ou bloquer un numéro entrant pendant 1 h, 24 h ou une durée choisie',
    };
    for (final entry in dictionaries.entries) {
      expect(
        entry.value['copyrightLine'],
        '© 2026 CyberDesignTech Dev',
        reason: '${entry.key} copyright line',
      );
      expect(
        entry.value['footerCollective'],
        collectiveLabels[entry.key],
        reason: '${entry.key} footer collective label',
      );
      expect(
        entry.value['aboutDescription'],
        aboutDescriptions[entry.key],
        reason: '${entry.key} About description',
      );
      expect(
        entry.value['temporaryRulesDescription'],
        temporaryDescriptions[entry.key],
        reason: '${entry.key} temporary rules description',
      );
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

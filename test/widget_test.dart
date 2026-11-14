import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:call_guard/data/database_helper.dart';
import 'package:call_guard/main.dart';
import 'package:call_guard/l10n/app_strings.dart';

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
    await waitForText(tester, 'Захист викликів');
    await tester.pumpAndSettle();
  }

  Future<void> waitForDatabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
  }

  test('SQLite schema seeds settings, countries and operators', () async {
    final settings = await _testDatabase.getSettings();
    final countries = await _testDatabase.getCountries();
    expect(settings['locale'], 'ukrainian');
    expect(countries, hasLength(5));
    expect(await _testDatabase.getOperators('UA'), hasLength(3));
    expect(await _testDatabase.getPhoneRules('white'), hasLength(2));
  });

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

  testWidgets('renders the Call Guard protection prototype', (tester) async {
    await pumpApp(tester);

    expect(find.text('Захист викликів'), findsOneWidget);
    expect(find.text('Захист активний'), findsOneWidget);
    expect(find.text('Швидкі правила'), findsOneWidget);
    expect(find.byType(ShieldPhoneLogo), findsNWidgets(2));
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
    }
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

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Профіль, мова та тема'));
    await tester.pumpAndSettle();

    final aboutMenuItem = find.text('Про додаток');
    await tester.ensureVisible(aboutMenuItem);
    await tester.tap(aboutMenuItem);
    await tester.pumpAndSettle();
    expect(find.text('Call Guard'), findsOneWidget);
    expect(find.textContaining('v0.2.0-db'), findsOneWidget);
    expect(find.textContaining('не надсилаються на сервер'), findsOneWidget);

    await tester.tap(find.text('Зрозуміло'));
    await tester.pumpAndSettle();
    final supportMenuItem = find.text('Підтримати проєкт');
    await tester.ensureVisible(supportMenuItem);
    await tester.tap(supportMenuItem);
    await tester.pumpAndSettle();
    expect(
      find.text('Buy Me a Coffee · Подякувати розробнику'),
      findsOneWidget,
    );
    expect(find.text('Поділитися застосунком'), findsOneWidget);

    await tester.tap(find.text('Копіювати посилання'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Посилання скопійовано'), findsOneWidget);
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

    expect(find.text('Call protection'), findsOneWidget);
    expect(find.text('Protection is active'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);

    await tester.tap(find.byTooltip('Lists & filters'));
    await waitForText(tester, 'Countries & operators');
    await tester.tap(find.text('Countries & operators'));
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
    await waitForText(tester, 'Країни та оператори');
    await tester.tap(find.text('Країни та оператори'));
    await waitForText(tester, 'Україна');
    await tester.tap(find.text('Україна'));
    await tester.pumpAndSettle();

    expect(find.text('Київстар'), findsOneWidget);
    expect(find.text('Vodafone UA'), findsOneWidget);
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
    await waitForText(tester, 'Країни та оператори');
    await tester.tap(find.text('Країни та оператори'));
    await waitForText(tester, 'Україна');
    await tester.tap(find.byTooltip('Додати країну або оператора'));
    await tester.pumpAndSettle();

    expect(find.text('Додати країну'), findsOneWidget);
    expect(find.text('Додати оператора'), findsOneWidget);
    await tester.tap(find.text('Додати оператора'));
    await tester.pumpAndSettle();
    expect(find.text('Мережеві префікси (NDC)'), findsOneWidget);
  });
}

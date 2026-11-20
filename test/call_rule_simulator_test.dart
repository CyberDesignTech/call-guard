import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:call_guard/data/database_helper.dart';
import 'package:call_guard/engine/call_rule_simulator.dart';

void main() {
  late DatabaseHelper database;

  setUpAll(() {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
  });

  setUp(() async {
    database = DatabaseHelper.forTesting();
    await database.initialize();
  });

  tearDown(() => database.close());

  test('disabled schedule ignores the stale allowlist-only switch', () async {
    final now = DateTime(
      2026,
      11,
      16,
      22,
      30,
    ); // Monday, inside configured hours
    await database.setSetting('protection_enabled', true);
    await database.setSetting('automatic_silence', false);
    await database.setSetting('allow_only_whitelist', true);
    await database.setSetting('silence_start_minute', 22 * 60);
    await database.setSetting('silence_end_minute', 7 * 60);
    await database.setSetting('silence_weekdays', '1');
    await database.setSetting('block_hidden', false);
    await database.setSetting('block_international', false);

    final verdict = await CallRuleSimulator(database)
        .evaluate('+380 63 555 01 02', now: now);

    expect(verdict.allowed, isTrue);
    expect(verdict.reason, 'default_allow');
  });

  test('active schedule applies only during its configured interval', () async {
    final now = DateTime(2026, 11, 16, 22, 30); // Monday
    await database.setSetting('protection_enabled', true);
    await database.setSetting('automatic_silence', true);
    await database.setSetting('allow_only_whitelist', true);
    await database.setSetting('silence_start_minute', 22 * 60);
    await database.setSetting('silence_end_minute', 7 * 60);
    await database.setSetting('silence_weekdays', '1');
    await database.setSetting('block_hidden', false);
    await database.setSetting('block_international', false);

    final verdict = await CallRuleSimulator(database)
        .evaluate('+380 63 555 01 02', now: now);

    expect(verdict.allowed, isFalse);
    expect(verdict.reason, 'silent_schedule');
  });

  test(
    'active schedule with whitelist-only disabled continues normal rules',
    () async {
      final now = DateTime(2026, 11, 16, 22, 30); // Monday
      await database.setSetting('automatic_silence', true);
      await database.setSetting('allow_only_whitelist', false);
      await database.setSetting('silence_start_minute', 22 * 60);
      await database.setSetting('silence_end_minute', 7 * 60);
      await database.setSetting('silence_weekdays', '1');
      await database.setSetting('block_international', false);

      final verdict = await CallRuleSimulator(database)
          .evaluate('+380 63 555 01 02', now: now);

      expect(verdict.allowed, isTrue);
      expect(verdict.reason, 'default_allow');
    },
  );

  test('blacklist rejects a number even when its country is allowed', () async {
    await database.updateCountryAction('UA', 'allow');
    await database.insertPhoneRule(
      phone: '+380 67 123 45 67',
      label: 'Explicit block',
      listType: 'black',
    );

    final verdict = await CallRuleSimulator(database)
        .evaluate('+380 67 123 45 67');

    expect(verdict.allowed, isFalse);
    expect(verdict.reason, 'blacklist');
  });

  test('emergency service codes bypass all call rules exactly', () async {
    await database.setSetting('driving_mode', true);
    await database.setSetting('manual_silence_enabled', true);
    await database.setSetting(DatabaseHelper.settingBlockShortNumbers, true);
    for (final number in [
      '101',
      '102',
      '103',
      '104',
      '112',
      '911',
      '999',
      '+1 12',
      '00-911',
    ]) {
      await database.insertPhoneRule(
        phone: number,
        label: 'Explicit block',
        listType: 'black',
      );
      final verdict = await CallRuleSimulator(database).evaluate(number);
      expect(verdict.allowed, isTrue, reason: '$number should be allowed');
      expect(verdict.reason, 'emergency_service');
    }
  });

  test(
    'short numbers skip international rules and follow their own switch',
    () async {
      await database.setSetting('block_international', true);
      await database.setSetting(DatabaseHelper.settingBlockShortNumbers, false);
      for (final number in ['3700', '466']) {
        final verdict = await CallRuleSimulator(database).evaluate(number);
        expect(verdict.allowed, isTrue);
        expect(verdict.reason, 'default_allow');
      }

      await database.setSetting(DatabaseHelper.settingBlockShortNumbers, true);
      final notContact = await CallRuleSimulator(database)
          .evaluate('3700', isInContacts: false);
      expect(notContact.allowed, isFalse);
      expect(notContact.reason, 'short_number_block');

      final contact = await CallRuleSimulator(database)
          .evaluate('3700', isInContacts: true);
      expect(contact.allowed, isTrue);
      expect(contact.reason, 'default_allow');

      final unknownContactStatus = await CallRuleSimulator(database)
          .evaluate('3700');
      expect(unknownContactStatus.allowed, isTrue);
      expect(unknownContactStatus.reason, 'default_allow');

      await database.insertPhoneRule(
        phone: '3700',
        label: 'Explicit allow',
        listType: 'white',
      );
      final allowlisted = await CallRuleSimulator(database)
          .evaluate('3700', isInContacts: false);
      expect(allowlisted.allowed, isTrue);
      expect(allowlisted.reason, 'allowlist');
    },
  );

  test(
    'emergency repeat may pass a scheduled rejection after two prior calls',
    () async {
      final now = DateTime(2026, 11, 16, 22, 30); // Monday
      const number = '+380 63 555 01 02';
      await database.setSetting('automatic_silence', true);
      await database.setSetting('allow_only_whitelist', true);
      await database.setSetting('answering_enabled', true);
      await database.setSetting('answering_emergency_repeat', true);
      await database.setSetting('block_international', false);
      await database.setSetting('silence_start_minute', 22 * 60);
      await database.setSetting('silence_end_minute', 7 * 60);
      await database.setSetting('silence_weekdays', '1');
      await database.insertCallLog(
        phone: number,
        reason: 'silent_schedule',
        timestamp:
            now.millisecondsSinceEpoch -
            const Duration(minutes: 2).inMilliseconds,
      );
      await database.insertCallLog(
        phone: number,
        reason: 'silent_schedule',
        timestamp:
            now.millisecondsSinceEpoch -
            const Duration(minutes: 1).inMilliseconds,
      );

      final verdict = await CallRuleSimulator(database)
          .evaluate(number, now: now);

      expect(verdict.allowed, isTrue);
      expect(verdict.reason, 'emergency_repeat');
    },
  );

  test(
    'driving mode rejects a whitelisted caller with its own reason',
    () async {
      await database.insertPhoneRule(
        phone: '+380 67 123 45 67',
        label: 'Test allow rule',
        listType: 'white',
      );
      await database.setSetting('driving_mode', true);

      final verdict = await CallRuleSimulator(database)
          .evaluate('+380 67 123 45 67');

      expect(verdict.allowed, isFalse);
      expect(verdict.reason, 'driving_mode');
    },
  );

  test('Spain mobile and Madrid fixed-line prefixes can be blocked', () async {
    final operators = await database.getOperators('ES');
    final movistar = operators.singleWhere(
      (row) => row['operator_name'] == '@operatorMovistarES',
    );
    final madrid = operators.singleWhere(
      (row) => row['operator_name'] == '@operatorMadridLandline',
    );
    await database.updateOperatorAction(movistar['id'] as int, 'block');
    await database.updateOperatorAction(madrid['id'] as int, 'block');
    await database.setSetting('block_international', false);

    final simulator = CallRuleSimulator(database);
    final mobile = await simulator.evaluate('+34 601 234 567');
    final fixed = await simulator.evaluate('+34 911 234 567');

    expect(mobile.reason, 'operator_block');
    expect(fixed.reason, 'operator_block');
  });

  test('France mobile and Paris fixed-line prefixes can be blocked', () async {
    final operators = await database.getOperators('FR');
    final orange = operators.singleWhere(
      (row) => row['operator_name'] == '@operatorOrangeFR',
    );
    final paris = operators.singleWhere(
      (row) => row['operator_name'] == '@operatorParisLandline',
    );
    await database.updateOperatorAction(orange['id'] as int, 'block');
    await database.updateOperatorAction(paris['id'] as int, 'block');
    await database.setSetting('block_international', false);

    final simulator = CallRuleSimulator(database);
    final mobile = await simulator.evaluate('+33 6 12 34 56 78');
    final fixed = await simulator.evaluate('+33 1 23 45 67 89');

    expect(mobile.reason, 'operator_block');
    expect(fixed.reason, 'operator_block');
  });

  test('world countries block by any E.164 calling code', () async {
    await database.updateCountryAction('IT', 'block');
    await database.updateCountryAction('CZ', 'block');
    await database.updateCountryAction('TR', 'block');
    await database.setSetting('block_international', false);

    final simulator = CallRuleSimulator(database);
    expect(
      (await simulator.evaluate('+39 320 123 4567')).reason,
      'country_block',
    );
    expect(
      (await simulator.evaluate('+420 601 123 456')).reason,
      'country_block',
    );
    expect(
      (await simulator.evaluate('+90 532 123 4567')).reason,
      'country_block',
    );

    // A neighbouring code that only shares the leading digit stays allowed.
    expect(
      (await simulator.evaluate('+380 67 555 01 02')).reason,
      'default_allow',
    );
  });

  test('shared +1 selects US and Canada by NANP area code', () async {
    await database.setSetting('block_international', false);
    await database.updateCountryAction('US', 'block');

    final simulator = CallRuleSimulator(database);
    expect(
      (await simulator.evaluate('+1 212 555 0100')).reason,
      'country_block',
    );
    expect(
      (await simulator.evaluate('+1 416 555 0100')).reason,
      'default_allow',
    );

    await database.updateCountryAction('US', 'neutral');
    await database.updateCountryAction('CA', 'block');
    expect(
      (await simulator.evaluate('+1 416 555 0100')).reason,
      'country_block',
    );
    expect(
      (await simulator.evaluate('+1 212 555 0100')).reason,
      'default_allow',
    );
  });

  test(
    'NANP operator rules still match after splitting US and Canada',
    () async {
      await database.setSetting('block_international', false);
      final operators = await database.getOperators('US');
      final newYork = operators.singleWhere(
        (row) => row['operator_name'] == '@operatorNewYorkLandline',
      );
      await database.updateOperatorAction(newYork['id'] as int, 'block');

      final simulator = CallRuleSimulator(database);
      expect(
        (await simulator.evaluate('+1 212 555 0100')).reason,
        'operator_block',
      );
      expect(
        (await simulator.evaluate('+1 416 555 0100')).reason,
        'default_allow',
      );
    },
  );

  test('shared +7 selects Kazakhstan and Russia without area codes', () async {
    await database.setSetting('block_international', false);
    await database.updateCountryAction('KZ', 'block');

    final simulator = CallRuleSimulator(database);
    expect(
      (await simulator.evaluate('+7 700 123 4567')).reason,
      'country_block',
    );
    expect(
      (await simulator.evaluate('+7 916 123 4567')).reason,
      'default_allow',
    );
  });
}

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
    'driving mode rejects a whitelisted caller with its own reason',
    () async {
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
}

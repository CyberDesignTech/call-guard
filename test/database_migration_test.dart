import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:call_guard/data/database_helper.dart';

void main() {
  setUpAll(() {
    ffi.sqfliteFfiInit();
    sqflite.databaseFactory = ffi.databaseFactoryFfi;
  });

  test('v1.9 migrates the tray preference and splits US/Canada', () async {
    const databasePath = 'test/call_guard_v19_migration_test.db';
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

    final legacy = await sqflite.openDatabase(
      databasePath,
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE country_rules (
            iso_code TEXT PRIMARY KEY,
            dial_code TEXT NOT NULL,
            name_key TEXT NOT NULL,
            custom_name TEXT,
            action TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE operator_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            country_iso TEXT NOT NULL,
            operator_name TEXT NOT NULL,
            prefixes TEXT NOT NULL,
            action TEXT NOT NULL
          )
        ''');
        await db.insert('app_settings', {
          'key': 'status_indicator_enabled',
          'value': 'false',
        });
        await db.insert('country_rules', {
          'iso_code': 'US-CA',
          'dial_code': '+1',
          'name_key': 'countryNorthAmerica',
          'action': 'block',
        });
        await db.insert('operator_rules', {
          'country_iso': 'US-CA',
          'operator_name': '@operatorNewYorkLandline',
          'prefixes': '212',
          'action': 'neutral',
        });
      },
    );
    await legacy.close();

    final migrated = DatabaseHelper.forTesting(databasePath: databasePath);
    await migrated.initialize();

    final settings = await migrated.getSettings();
    expect(settings.containsKey('status_indicator_enabled'), isFalse);
    expect(settings['status_tray_icon_enabled'], 'false');
    expect(settings['status_tray_user_overridden'], 'true');

    final countries = await migrated.getCountries();
    final isos = countries.map((row) => row['iso_code']).toSet();
    expect(isos, containsAll(<String>['US', 'CA']));
    expect(isos, isNot(contains('US-CA')));
    final unitedStates = countries.singleWhere(
      (row) => row['iso_code'] == 'US',
    );
    final canada = countries.singleWhere((row) => row['iso_code'] == 'CA');
    expect(unitedStates['action'], 'block');
    expect((unitedStates['area_codes'] as String).split(','), contains('212'));
    expect((canada['area_codes'] as String).split(','), contains('416'));

    final newYork = (await migrated.getOperators(
      'US',
    )).singleWhere((row) => row['operator_name'] == '@operatorNewYorkLandline');
    expect(newYork['prefixes'], '212');
    expect(await migrated.getOperators('US-CA'), isEmpty);

    await migrated.close();
  });

  test('fresh v8 install seeds populated area-code columns', () async {
    final database = DatabaseHelper.forTesting();
    await database.initialize();
    final countries = await database.getCountries();
    expect(countries, hasLength(195));
    final romania = countries.singleWhere((row) => row['iso_code'] == 'RO');
    expect(romania['area_codes'], isA<String>());
    final canada = countries.singleWhere((row) => row['iso_code'] == 'CA');
    expect((canada['area_codes'] as String).split(','), contains('416'));
    await database.close();
  });
}

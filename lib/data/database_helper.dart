import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static const _callbackSettingDefaults = <String, String>{
    'answering_auto_remind': 'false',
    'answering_auto_remind_minutes': '30',
    'answering_emergency_repeat': 'false',
  };

  DatabaseHelper._({String? databasePath}) : _databasePath = databasePath;

  static final DatabaseHelper instance = DatabaseHelper._();

  /// Uses a real in-memory SQLite database, intended for widget tests.
  factory DatabaseHelper.forTesting({String? databasePath}) =>
      DatabaseHelper._(databasePath: databasePath ?? inMemoryDatabasePath);

  final String? _databasePath;
  Database? _openedDatabase;

  Future<Database> get _database async {
    final current = _openedDatabase;
    if (current != null) return current;

    final databasePath =
        _databasePath ?? path.join(await getDatabasesPath(), 'call_guard.db');
    final database = await openDatabase(
      databasePath,
      version: 5,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureReminderRepeatColumns(db);
        await _ensureCallLogContactNameColumn(db);
        if (oldVersion < 3) await _createIndexes(db);
        await _ensureCallbackSettings(db);
        await _ensureFixedLineOperators(db);
      },
      onOpen: (db) async {
        await _ensureReminderRepeatColumns(db);
        await _ensureCallLogContactNameColumn(db);
        await _ensureCallbackSettings(db);
        await _normalizeLegacyCallLogReasons(db);
        await _ensureFixedLineOperators(db);
      },
    );
    _openedDatabase = database;
    return database;
  }

  Future<void> initialize() async {
    await _database;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE phone_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        label TEXT,
        list_type TEXT NOT NULL,
        created_at INTEGER
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
        action TEXT NOT NULL,
        FOREIGN KEY(country_iso) REFERENCES country_rules(iso_code) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE call_reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        contact_name TEXT,
        remind_at INTEGER NOT NULL,
        note TEXT,
        is_done INTEGER DEFAULT 0,
        repeat_type TEXT NOT NULL DEFAULT 'none',
        repeat_interval INTEGER NOT NULL DEFAULT 1,
        last_fired_at INTEGER,
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE call_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL,
        contact_name TEXT,
        reason TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    await _createIndexes(db);

    final settings = <String, String>{
      'locale': 'ukrainian',
      'theme_mode': 'system',
      'protection_enabled': 'true',
      'block_hidden': 'true',
      'block_non_contacts': 'false',
      'block_international': 'true',
      'automatic_silence': 'false',
      'manual_silence_enabled': 'false',
      'allow_only_whitelist': 'true',
      'silence_start_minute': '1320',
      'silence_end_minute': '420',
      'silence_weekdays': '1,2,3,4,5,6,7',
      'answering_enabled': 'false',
      'answering_scenario': 'quiet_mode',
      'answering_local_notification': 'true',
      ..._callbackSettingDefaults,
      'notification_permission_prompted': 'false',
    };
    final batch = db.batch();
    for (final setting in settings.entries) {
      batch.insert('app_settings', {
        'key': setting.key,
        'value': setting.value,
      });
    }

    final now = DateTime.now();
    final countries = <Map<String, Object?>>[
      {
        'iso_code': 'UA',
        'dial_code': '+380',
        'name_key': 'countryUkraine',
        'action': 'neutral',
      },
      {
        'iso_code': 'PL',
        'dial_code': '+48',
        'name_key': 'countryPoland',
        'action': 'neutral',
      },
      {
        'iso_code': 'DE',
        'dial_code': '+49',
        'name_key': 'countryGermany',
        'action': 'neutral',
      },
      {
        'iso_code': 'GB',
        'dial_code': '+44',
        'name_key': 'countryUK',
        'action': 'neutral',
      },
      {
        'iso_code': 'US-CA',
        'dial_code': '+1',
        'name_key': 'countryNorthAmerica',
        'action': 'neutral',
      },
    ];
    for (final country in countries) {
      batch.insert('country_rules', country);
    }

    final operators = <Map<String, Object?>>[
      _operatorSeed('UA', 'operatorKyivstar', '67,68,96,97,98'),
      _operatorSeed('UA', 'operatorVodafoneUA', '50,66,95,99'),
      _operatorSeed('UA', 'operatorLifecell', '63,73,93'),
      _operatorSeed('UA', 'operatorUkrtelecom', '44'),
      _operatorSeed('PL', 'operatorOrange', '50,51,53,57,78,79'),
      _operatorSeed('PL', 'operatorPlay', '45,53,72,73,79,88'),
      _operatorSeed('PL', 'operatorWarsawLandline', '22'),
      _operatorSeed('DE', 'operatorTelekom', '151,160,170,171,175'),
      _operatorSeed('DE', 'operatorVodafoneDE', '152,162,172,173,174'),
      _operatorSeed('DE', 'operatorBerlinLandline', '30'),
      _operatorSeed('GB', 'operatorVodafoneUK', '74,75,77,78,79'),
      _operatorSeed('GB', 'operatorEE', '79,75,77'),
      _operatorSeed('GB', 'operatorLondonLandline', '20'),
      _operatorSeed('US-CA', 'operatorNewYorkLandline', '212'),
    ];
    for (final operator in operators) {
      batch.insert('operator_rules', operator);
    }

    final createdAt = now.millisecondsSinceEpoch;
    batch.insert('phone_rules', {
      'phone': '+380 67 123 45 67',
      'label': '@demoMother',
      'list_type': 'white',
      'created_at': createdAt,
    });
    batch.insert('phone_rules', {
      'phone': '+380 44 220 18 40',
      'label': '@demoWork',
      'list_type': 'white',
      'created_at': createdAt,
    });
    batch.insert('phone_rules', {
      'phone': '+48 600 123 456',
      'label': '@demoUnwanted',
      'list_type': 'black',
      'created_at': createdAt,
    });
    batch.insert('phone_rules', {
      'phone': '+380 67 555 01 01',
      'label': '@demoAdvertising',
      'list_type': 'black',
      'created_at': createdAt,
    });

    batch.insert('call_reminders', {
      'phone': '+380 67 123 45 67',
      'contact_name': '@reminderOlena',
      'remind_at': now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
      'note': '@reminderNoteMeeting',
      'is_done': 0,
    });
    batch.insert('call_reminders', {
      'phone': '+48 600 123 456',
      'contact_name': '@reminderUnknown',
      'remind_at': now
          .add(const Duration(days: 1, hours: 9))
          .millisecondsSinceEpoch,
      'note': '@reminderNoteCheck',
      'is_done': 0,
    });

    batch.insert('call_logs', {
      'phone': '+48 600 123 456',
      'reason': 'country_block',
      'timestamp': now
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch,
    });
    batch.insert('call_logs', {
      'phone': '@numberHidden',
      'reason': 'hidden_number',
      'timestamp': now
          .subtract(const Duration(hours: 5))
          .millisecondsSinceEpoch,
    });
    batch.insert('call_logs', {
      'phone': '+380 44 555 20 20',
      'reason': 'silent_schedule',
      'timestamp': now
          .subtract(const Duration(days: 1, hours: 4))
          .millisecondsSinceEpoch,
    });

    await batch.commit(noResult: true);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name'] as String?).whereType<String>().toSet();
    if (tables.contains('phone_rules')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_phone_rules_list_type '
        'ON phone_rules(list_type)',
      );
    }
    if (tables.contains('operator_rules')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_operator_rules_country_id '
        'ON operator_rules(country_iso)',
      );
    }
    if (tables.contains('call_reminders')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_reminders_pending '
        'ON call_reminders(is_done, remind_at)',
      );
    }
    if (tables.contains('call_logs')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_call_logs_timestamp '
        'ON call_logs(timestamp)',
      );
    }
  }

  Future<void> _ensureReminderRepeatColumns(DatabaseExecutor db) async {
    final tableExists = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'call_reminders'",
    )).isNotEmpty;
    if (!tableExists) return;
    final columns = (await db.rawQuery('PRAGMA table_info(call_reminders)'))
        .map((column) => column['name'] as String?)
        .whereType<String>()
        .toSet();
    if (!columns.contains('repeat_type')) {
      await db.execute(
        "ALTER TABLE call_reminders ADD COLUMN repeat_type TEXT NOT NULL DEFAULT 'none'",
      );
    }
    if (!columns.contains('repeat_interval')) {
      await db.execute(
        'ALTER TABLE call_reminders ADD COLUMN repeat_interval INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (!columns.contains('last_fired_at')) {
      await db.execute(
        'ALTER TABLE call_reminders ADD COLUMN last_fired_at INTEGER',
      );
    }
    if (!columns.contains('created_at')) {
      await db.execute(
        'ALTER TABLE call_reminders ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _ensureCallLogContactNameColumn(DatabaseExecutor db) async {
    final tableExists = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'call_logs'",
    )).isNotEmpty;
    if (!tableExists) return;
    final columns = (await db.rawQuery('PRAGMA table_info(call_logs)'))
        .map((column) => column['name'] as String?)
        .whereType<String>()
        .toSet();
    if (!columns.contains('contact_name')) {
      await db.execute('ALTER TABLE call_logs ADD COLUMN contact_name TEXT');
    }
  }

  Future<void> _ensureFixedLineOperators(DatabaseExecutor db) async {
    const fixedLineOperators = <String, (String, String)>{
      'operatorUkrtelecom': ('UA', '44'),
      'operatorWarsawLandline': ('PL', '22'),
      'operatorBerlinLandline': ('DE', '30'),
      'operatorLondonLandline': ('GB', '20'),
      'operatorNewYorkLandline': ('US-CA', '212'),
    };
    final tableExists = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'operator_rules'",
    )).isNotEmpty;
    if (!tableExists) return;
    final existing = (await db.query(
      'operator_rules',
      columns: ['operator_name'],
    )).map((row) => row['operator_name'] as String).toSet();
    final countries = (await db.query(
      'country_rules',
      columns: ['iso_code'],
    )).map((row) => row['iso_code'] as String).toSet();
    for (final entry in fixedLineOperators.entries) {
      final storedName = '@${entry.key}';
      if (existing.contains(storedName) ||
          !countries.contains(entry.value.$1)) {
        continue;
      }
      await db.insert('operator_rules', {
        'country_iso': entry.value.$1,
        'operator_name': storedName,
        'prefixes': entry.value.$2,
        'action': 'neutral',
      });
    }
  }

  Future<void> _ensureCallbackSettings(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    for (final entry in _callbackSettingDefaults.entries) {
      await db.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _normalizeLegacyCallLogReasons(DatabaseExecutor db) async {
    final hasCallLogs = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'call_logs'",
    )).isNotEmpty;
    if (!hasCallLogs) return;
    const legacyReasons = <String, String>{
      'reasonCountry': 'country_block',
      'reasonHidden': 'hidden_number',
      'reasonSilence': 'silent_schedule',
    };
    for (final entry in legacyReasons.entries) {
      await db.update(
        'call_logs',
        {'reason': entry.value},
        where: 'reason = ?',
        whereArgs: [entry.key],
      );
    }
  }

  Map<String, Object?> _operatorSeed(
    String countryIso,
    String nameKey,
    String prefixes,
  ) => {
    'country_iso': countryIso,
    'operator_name': '@$nameKey',
    'prefixes': prefixes,
    'action': 'neutral',
  };

  Future<Map<String, String>> getSettings() async {
    final rows = await (await _database).query('app_settings');
    return Map<String, String>.of(_callbackSettingDefaults)..addEntries(
      rows.map(
        (row) => MapEntry(row['key']! as String, row['value']! as String),
      ),
    );
  }

  Future<void> setSetting(String key, Object value) async {
    await (await _database).insert('app_settings', {
      'key': key,
      'value': value.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getPhoneRules(String listType) async =>
      (await _database).query(
        'phone_rules',
        where: 'list_type = ?',
        whereArgs: [listType],
        orderBy: 'id DESC',
      );

  Future<int> insertPhoneRule({
    required String phone,
    required String? label,
    required String listType,
  }) async => (await _database).insert('phone_rules', {
    'phone': phone,
    'label': label,
    'list_type': listType,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  });

  Future<int> deletePhoneRule(int id) async =>
      (await _database).delete('phone_rules', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> getCountries() async =>
      (await _database).query('country_rules', orderBy: 'dial_code');

  Future<List<Map<String, Object?>>> getOperators(String countryIso) async =>
      (await _database).query(
        'operator_rules',
        where: 'country_iso = ?',
        whereArgs: [countryIso],
        orderBy: 'id',
      );

  Future<List<Map<String, Object?>>> getAllOperators() async =>
      (await _database).query('operator_rules', orderBy: 'id');

  Future<int> insertCountry({
    required String isoCode,
    required String dialCode,
    required String nameKey,
    required String? customName,
    required String action,
  }) async => (await _database).insert('country_rules', {
    'iso_code': isoCode,
    'dial_code': dialCode,
    'name_key': nameKey,
    'custom_name': customName,
    'action': action,
  });

  Future<int> updateCountryAction(String isoCode, String action) async =>
      (await _database).update(
        'country_rules',
        {'action': action},
        where: 'iso_code = ?',
        whereArgs: [isoCode],
      );

  Future<int> deleteCountry(String isoCode) async => (await _database).delete(
    'country_rules',
    where: 'iso_code = ?',
    whereArgs: [isoCode],
  );

  Future<int> insertOperator({
    required String countryIso,
    required String name,
    required List<String> prefixes,
    required String action,
  }) async => (await _database).insert('operator_rules', {
    'country_iso': countryIso,
    'operator_name': name,
    'prefixes': prefixes.join(','),
    'action': action,
  });

  Future<int> updateOperatorAction(int id, String action) async =>
      (await _database).update(
        'operator_rules',
        {'action': action},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> deleteOperator(int id) async => (await _database).delete(
    'operator_rules',
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<List<Map<String, Object?>>> getReminders() async =>
      (await _database).query('call_reminders', orderBy: 'remind_at');

  Future<int> insertReminder({
    required String phone,
    required String? contactName,
    required int remindAt,
    required String? note,
    String repeatType = 'none',
    int repeatInterval = 1,
  }) async => (await _database).insert('call_reminders', {
    'phone': phone,
    'contact_name': contactName,
    'remind_at': remindAt,
    'note': note,
    'is_done': 0,
    'repeat_type': repeatType,
    'repeat_interval': repeatInterval,
    'last_fired_at': null,
    'created_at': DateTime.now().millisecondsSinceEpoch,
  });

  Future<int> updateReminderDone(int id, bool isDone) async =>
      (await _database).update(
        'call_reminders',
        {'is_done': isDone ? 1 : 0, if (!isDone) 'last_fired_at': null},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> updateReminderSchedule({
    required int id,
    required int remindAt,
    required String repeatType,
    required int repeatInterval,
  }) async => (await _database).update(
    'call_reminders',
    {
      'remind_at': remindAt,
      'repeat_type': repeatType,
      'repeat_interval': repeatInterval,
      'last_fired_at': null,
    },
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<int> updateReminderTime(int id, int remindAt) async =>
      (await _database).update(
        'call_reminders',
        {'remind_at': remindAt},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> deleteReminder(int id) async => (await _database).delete(
    'call_reminders',
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<List<Map<String, Object?>>> getCallLogs() async =>
      (await _database).query('call_logs', orderBy: 'timestamp DESC');

  Future<int> deleteCallLog(int id) async =>
      (await _database).delete('call_logs', where: 'id = ?', whereArgs: [id]);

  Future<int> clearCallLogs() async => (await _database).delete('call_logs');

  Future<int> updateCallLogContactName(int id, String contactName) async =>
      (await _database).update(
        'call_logs',
        {'contact_name': contactName},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> insertCallLog({
    required String phone,
    String? contactName,
    required String reason,
    required int timestamp,
  }) async => (await _database).insert('call_logs', {
    'phone': phone,
    'contact_name': contactName,
    'reason': reason,
    'timestamp': timestamp,
  });

  /// Exposes created index names so tests can verify schema and migrations.
  Future<Set<String>> getIndexNamesForTesting() async {
    final rows = await (await _database).rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
    );
    return rows.map((row) => row['name']! as String).toSet();
  }

  Future<void> close() async {
    final database = _openedDatabase;
    _openedDatabase = null;
    await database?.close();
  }
}

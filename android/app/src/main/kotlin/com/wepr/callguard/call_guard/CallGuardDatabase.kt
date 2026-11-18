package com.wepr.callguard.call_guard

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Process-wide singleton for the SQLite file shared with Flutter's sqflite layer.
 *
 * The database stays open for the lifetime of the process so call screening,
 * reminders and notifications do not reopen it for every read/write.
 */
object CallGuardDatabase {
    private val repeatColumnsChecked = AtomicBoolean(false)
    private val callLogContactNameChecked = AtomicBoolean(false)
    private val phoneRuleExpiresAtChecked = AtomicBoolean(false)
    private val countryAreaCodesChecked = AtomicBoolean(false)

    @Volatile
    private var instance: SQLiteDatabase? = null

    fun open(context: Context): SQLiteDatabase {
        instance?.let { return it }
        return synchronized(this) {
            instance ?: openDatabase(context.applicationContext).also { instance = it }
        }
    }

    fun <T> withDatabase(context: Context, block: (SQLiteDatabase) -> T): T =
        block(open(context))

    /** Reads every row of app_settings once, so one call can share a settings snapshot. */
    fun readSettings(context: Context): Map<String, String> =
        withDatabase(context) { database ->
            val settings = HashMap<String, String>()
            database.rawQuery(
                "SELECT `${DbContract.AppSettings.KEY}`, `${DbContract.AppSettings.VALUE}` " +
                    "FROM ${DbContract.AppSettings.TABLE}",
                null,
            ).use { cursor ->
                val keyColumn = cursor.getColumnIndexOrThrow(DbContract.AppSettings.KEY)
                val valueColumn = cursor.getColumnIndexOrThrow(DbContract.AppSettings.VALUE)
                while (cursor.moveToNext()) {
                    settings[cursor.getString(keyColumn)] =
                        cursor.getString(valueColumn).orEmpty()
                }
            }
            settings
        }

    private fun openDatabase(appContext: Context): SQLiteDatabase {
        // sqflite's Android getDatabasesPath() resolves to Context.getDatabasePath().
        val databaseFile = appContext.getDatabasePath(DbContract.DATABASE_NAME)
        check(databaseFile.isFile) { "Call Guard database does not exist" }
        return SQLiteDatabase.openDatabase(
            databaseFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        ).apply {
            rawQuery("PRAGMA busy_timeout = ${DbContract.BUSY_TIMEOUT_MS}", null).use { }
            ensureRepeatColumns(this)
            ensureCallLogContactNameColumn(this)
            ensurePhoneRuleExpiresAtColumn(this)
            ensureCountryAreaCodesColumn(this)
            migrateLegacyStatusTraySettings(this)
            ensureCallbackSettings(this)
            ensureFixedLineOperators(this)
            ensureSpainFranceCatalog(this)
        }
    }

    /** Adds columns introduced after the first release; runs at most once per process. */
    private fun ensureRepeatColumns(database: SQLiteDatabase) {
        if (!repeatColumnsChecked.compareAndSet(false, true)) return
        try {
            val columns = mutableSetOf<String>()
            database.rawQuery(
                "PRAGMA table_info(${DbContract.CallReminders.TABLE})",
                null,
            ).use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) columns.add(cursor.getString(nameColumn))
            }
            if (DbContract.CallReminders.REPEAT_TYPE !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CallReminders.TABLE} ADD COLUMN " +
                        "${DbContract.CallReminders.REPEAT_TYPE} TEXT NOT NULL DEFAULT 'none'",
                )
            }
            if (DbContract.CallReminders.REPEAT_INTERVAL !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CallReminders.TABLE} ADD COLUMN " +
                        "${DbContract.CallReminders.REPEAT_INTERVAL} INTEGER NOT NULL DEFAULT 1",
                )
            }
            if (DbContract.CallReminders.LAST_FIRED_AT !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CallReminders.TABLE} ADD COLUMN " +
                        "${DbContract.CallReminders.LAST_FIRED_AT} INTEGER",
                )
            }
            if (DbContract.CallReminders.CREATED_AT !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CallReminders.TABLE} ADD COLUMN " +
                        "${DbContract.CallReminders.CREATED_AT} INTEGER NOT NULL DEFAULT 0",
                )
            }
        } catch (error: Exception) {
            // Allow a later call to retry the migration instead of caching a failure.
            repeatColumnsChecked.set(false)
            throw error
        }
    }

    private fun ensureCallbackSettings(database: SQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE IF NOT EXISTS ${DbContract.AppSettings.TABLE} (" +
                "${DbContract.AppSettings.KEY} TEXT PRIMARY KEY, " +
                "${DbContract.AppSettings.VALUE} TEXT NOT NULL)",
        )
        callbackSettingDefaults.forEach { (key, value) ->
            database.insertWithOnConflict(
                DbContract.AppSettings.TABLE,
                null,
                android.content.ContentValues().apply {
                    put(DbContract.AppSettings.KEY, key)
                    put(DbContract.AppSettings.VALUE, value)
                },
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        }
    }

    private fun ensureCallLogContactNameColumn(database: SQLiteDatabase) {
        if (!callLogContactNameChecked.compareAndSet(false, true)) return
        try {
            val columns = mutableSetOf<String>()
            database.rawQuery(
                "PRAGMA table_info(${DbContract.CallLogs.TABLE})",
                null,
            ).use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) columns.add(cursor.getString(nameColumn))
            }
            if (columns.isNotEmpty() && DbContract.CallLogs.CONTACT_NAME !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CallLogs.TABLE} ADD COLUMN " +
                        "${DbContract.CallLogs.CONTACT_NAME} TEXT",
                )
            }
        } catch (error: Exception) {
            callLogContactNameChecked.set(false)
            throw error
        }
    }

    private fun ensurePhoneRuleExpiresAtColumn(database: SQLiteDatabase) {
        if (!phoneRuleExpiresAtChecked.compareAndSet(false, true)) return
        try {
            val columns = mutableSetOf<String>()
            database.rawQuery(
                "PRAGMA table_info(${DbContract.PhoneRules.TABLE})",
                null,
            ).use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) columns.add(cursor.getString(nameColumn))
            }
            if (columns.isNotEmpty() && DbContract.PhoneRules.EXPIRES_AT !in columns) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.PhoneRules.TABLE} ADD COLUMN " +
                        "${DbContract.PhoneRules.EXPIRES_AT} INTEGER",
                )
            }
        } catch (error: Exception) {
            phoneRuleExpiresAtChecked.set(false)
            throw error
        }
    }

    private fun ensureCountryAreaCodesColumn(database: SQLiteDatabase) {
        if (!countryAreaCodesChecked.compareAndSet(false, true)) return
        try {
            val columns = mutableSetOf<String>()
            database.rawQuery(
                "PRAGMA table_info(${DbContract.CountryRules.TABLE})",
                null,
            ).use { cursor ->
                val nameColumn = cursor.getColumnIndexOrThrow("name")
                while (cursor.moveToNext()) columns.add(cursor.getString(nameColumn))
            }
            if (columns.isNotEmpty() &&
                DbContract.CountryRules.AREA_CODES !in columns
            ) {
                database.execSQL(
                    "ALTER TABLE ${DbContract.CountryRules.TABLE} ADD COLUMN " +
                        "${DbContract.CountryRules.AREA_CODES} TEXT NOT NULL DEFAULT ''",
                )
            }
        } catch (error: Exception) {
            countryAreaCodesChecked.set(false)
            throw error
        }
    }

    /**
     * Copies the pre-1.9 status indicator preference onto the smart tray keys.
     * An explicitly disabled legacy tray becomes a user override.
     */
    private fun migrateLegacyStatusTraySettings(database: SQLiteDatabase) {
        val hasSettingsTable = database.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            arrayOf(DbContract.AppSettings.TABLE),
        ).use { it.moveToFirst() }
        if (!hasSettingsTable) return
        val legacyEnabled = database.rawQuery(
            "SELECT ${DbContract.AppSettings.VALUE} FROM ${DbContract.AppSettings.TABLE} " +
                "WHERE ${DbContract.AppSettings.KEY} = ? LIMIT 1",
            arrayOf(DbContract.SettingKeys.LEGACY_STATUS_INDICATOR_ENABLED),
        ).use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) == "true" else null
        } ?: return
        fun insertIfMissing(key: String, value: Boolean) {
            database.insertWithOnConflict(
                DbContract.AppSettings.TABLE,
                null,
                android.content.ContentValues().apply {
                    put(DbContract.AppSettings.KEY, key)
                    put(DbContract.AppSettings.VALUE, value.toString())
                },
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        }
        insertIfMissing(DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED, legacyEnabled)
        insertIfMissing(DbContract.SettingKeys.STATUS_TRAY_USER_OVERRIDDEN, !legacyEnabled)
        database.delete(
            DbContract.AppSettings.TABLE,
            "${DbContract.AppSettings.KEY} = ?",
            arrayOf(DbContract.SettingKeys.LEGACY_STATUS_INDICATOR_ENABLED),
        )
    }

    private fun ensureFixedLineOperators(database: SQLiteDatabase) {
        val defaults = listOf(
            FixedLineOperator("UA", "@operatorUkrtelecom", "44"),
            FixedLineOperator("PL", "@operatorWarsawLandline", "22"),
            FixedLineOperator("DE", "@operatorBerlinLandline", "30"),
            FixedLineOperator("GB", "@operatorLondonLandline", "20"),
            FixedLineOperator("US", "@operatorNewYorkLandline", "212"),
        )
        defaults.forEach { operator ->
            val countryExists = database.rawQuery(
                "SELECT 1 FROM ${DbContract.CountryRules.TABLE} " +
                    "WHERE ${DbContract.CountryRules.ISO_CODE} = ? LIMIT 1",
                arrayOf(operator.countryIso),
            ).use { it.moveToFirst() }
            if (!countryExists) return@forEach
            val exists = database.rawQuery(
                "SELECT 1 FROM ${DbContract.OperatorRules.TABLE} " +
                    "WHERE ${DbContract.OperatorRules.OPERATOR_NAME} = ? LIMIT 1",
                arrayOf(operator.name),
            ).use { it.moveToFirst() }
            if (!exists) {
                database.insert(
                    DbContract.OperatorRules.TABLE,
                    null,
                    android.content.ContentValues().apply {
                        put(DbContract.OperatorRules.COUNTRY_ISO, operator.countryIso)
                        put(DbContract.OperatorRules.OPERATOR_NAME, operator.name)
                        put(DbContract.OperatorRules.PREFIXES, operator.prefix)
                        put(DbContract.OperatorRules.ACTION, "neutral")
                    },
                )
            }
        }
    }

    /** Seed the new catalog entries without overwriting a user's saved actions. */
    private fun ensureSpainFranceCatalog(database: SQLiteDatabase) {
        val countries = listOf(
            CountrySeed("ES", "+34", "countrySpain"),
            CountrySeed("FR", "+33", "countryFrance"),
        )
        countries.forEach { country ->
            database.insertWithOnConflict(
                DbContract.CountryRules.TABLE,
                null,
                android.content.ContentValues().apply {
                    put(DbContract.CountryRules.ISO_CODE, country.isoCode)
                    put(DbContract.CountryRules.DIAL_CODE, country.dialCode)
                    put("name_key", country.nameKey)
                    put(DbContract.CountryRules.ACTION, "neutral")
                },
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        }

        val operators = listOf(
            CatalogOperator("ES", "@operatorMovistarES", "60,61,62"),
            CatalogOperator("ES", "@operatorVodafoneES", "63,64,65"),
            CatalogOperator("ES", "@operatorOrangeES", "66,67"),
            CatalogOperator("ES", "@operatorYoigo", "68,69,71,72,73,74"),
            CatalogOperator("ES", "@operatorMadridLandline", "91"),
            CatalogOperator("FR", "@operatorOrangeFR", "60,61,62,70,71,72"),
            CatalogOperator("FR", "@operatorSFR", "63,64,65,73,74,75"),
            CatalogOperator("FR", "@operatorBouygues", "66,67,76,77"),
            CatalogOperator(
                "FR",
                "@operatorFreeMobile",
                "68,69,78,79,695,696,757,758,759,780,781,782,783,784,785,786,787,788,789",
            ),
            CatalogOperator("FR", "@operatorParisLandline", "1"),
        )
        operators.forEach { operator ->
            val countryExists = database.rawQuery(
                "SELECT 1 FROM ${DbContract.CountryRules.TABLE} " +
                    "WHERE ${DbContract.CountryRules.ISO_CODE} = ? LIMIT 1",
                arrayOf(operator.countryIso),
            ).use { it.moveToFirst() }
            if (!countryExists) return@forEach
            val operatorExists = database.rawQuery(
                "SELECT 1 FROM ${DbContract.OperatorRules.TABLE} " +
                    "WHERE ${DbContract.OperatorRules.OPERATOR_NAME} = ? LIMIT 1",
                arrayOf(operator.name),
            ).use { it.moveToFirst() }
            if (operatorExists) return@forEach
            database.insertWithOnConflict(
                DbContract.OperatorRules.TABLE,
                null,
                android.content.ContentValues().apply {
                    put(DbContract.OperatorRules.COUNTRY_ISO, operator.countryIso)
                    put(DbContract.OperatorRules.OPERATOR_NAME, operator.name)
                    put(DbContract.OperatorRules.PREFIXES, operator.prefixes)
                    put(DbContract.OperatorRules.ACTION, "neutral")
                },
                SQLiteDatabase.CONFLICT_IGNORE,
            )
        }
    }

    private data class CountrySeed(
        val isoCode: String,
        val dialCode: String,
        val nameKey: String,
    )

    private data class CatalogOperator(
        val countryIso: String,
        val name: String,
        val prefixes: String,
    )

    private data class FixedLineOperator(
        val countryIso: String,
        val name: String,
        val prefix: String,
    )

    private val callbackSettingDefaults = mapOf(
        DbContract.SettingKeys.ANSWERING_AUTO_REMIND to "false",
        DbContract.SettingKeys.ANSWERING_AUTO_REMIND_MINUTES to "30",
        DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT to "false",
        DbContract.SettingKeys.DRIVING_MODE to "false",
        DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED to "true",
        DbContract.SettingKeys.STATUS_TRAY_USER_OVERRIDDEN to "false",
        DbContract.SettingKeys.STATUS_TRAY_ACTIVATED to "false",
        DbContract.SettingKeys.STATUS_TRAY_PERMISSION_PROMPTED to "false",
    )
}

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
            ensureCallbackSettings(this)
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

    private val callbackSettingDefaults = mapOf(
        DbContract.SettingKeys.ANSWERING_AUTO_REMIND to "false",
        DbContract.SettingKeys.ANSWERING_AUTO_REMIND_MINUTES to "30",
        DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT to "false",
    )
}

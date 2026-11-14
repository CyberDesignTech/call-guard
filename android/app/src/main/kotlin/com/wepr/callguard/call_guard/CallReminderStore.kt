package com.wepr.callguard.call_guard

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

data class CallReminderRecord(
    val id: Int,
    val phone: String,
    val contactName: String?,
    val remindAt: Long,
    val note: String?,
    val isDone: Boolean,
    val repeatType: String,
    val repeatInterval: Int,
    val lastFiredAt: Long?,
)

/** Minimal native access to the SQLite tables created by the Flutter sqflite helper. */
object CallReminderStore {
    fun findReminder(context: Context, id: Int): CallReminderRecord? =
        openDatabase(context).use { database ->
            database.query(
                "call_reminders",
                reminderColumns,
                "id = ?",
                arrayOf(id.toString()),
                null,
                null,
                null,
                "1",
            ).use { cursor ->
                if (!cursor.moveToFirst()) return@use null
                cursor.toReminder()
            }
        }

    fun pendingReminders(
        context: Context,
        includeFiredOneTime: Boolean = false,
    ): List<CallReminderRecord> =
        openDatabase(context).use { database ->
            val reminders = mutableListOf<CallReminderRecord>()
            database.query(
                "call_reminders",
                reminderColumns,
                if (includeFiredOneTime) {
                    "is_done = 0"
                } else {
                    "is_done = 0 AND (repeat_type != 'none' OR last_fired_at IS NULL)"
                },
                null,
                null,
                null,
                "remind_at ASC",
            ).use { cursor ->
                while (cursor.moveToNext()) reminders.add(cursor.toReminder())
            }
            reminders
        }

    fun markDone(context: Context, id: Int): Boolean =
        openDatabase(context).use { database ->
            database.update(
                "call_reminders",
                ContentValues().apply { put("is_done", 1) },
                "id = ?",
                arrayOf(id.toString()),
            ) > 0
        }

    fun markFired(context: Context, id: Int, firedAt: Long = System.currentTimeMillis()): Boolean =
        openDatabase(context).use { database ->
            database.update(
                "call_reminders",
                ContentValues().apply { put("last_fired_at", firedAt) },
                "id = ? AND is_done = 0",
                arrayOf(id.toString()),
            ) > 0
        }

    fun updateReminderSchedule(
        context: Context,
        id: Int,
        remindAt: Long,
        repeatType: String,
        repeatInterval: Int,
        lastFiredAt: Long? = null,
    ): Boolean = openDatabase(context).use { database ->
        database.update(
            "call_reminders",
            ContentValues().apply {
                put("remind_at", remindAt)
                put("repeat_type", repeatType)
                put("repeat_interval", repeatInterval.coerceAtLeast(1))
                put("is_done", 0)
                if (lastFiredAt == null) putNull("last_fired_at")
                else put("last_fired_at", lastFiredAt)
            },
            "id = ? AND is_done = 0",
            arrayOf(id.toString()),
        ) > 0
    }

    fun getSetting(context: Context, key: String, fallback: String = ""): String =
        openDatabase(context).use { database ->
            database.query(
                "app_settings",
                arrayOf("value"),
                "`key` = ?",
                arrayOf(key),
                null,
                null,
                null,
                "1",
            ).use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0).orEmpty() else fallback
            }
        }

    fun insertCallLog(context: Context, phone: String, reason: String) {
        openDatabase(context).use { database ->
            database.insertOrThrow(
                "call_logs",
                null,
                ContentValues().apply {
                    put("phone", phone.ifBlank { "@numberHidden" })
                    put("reason", reason)
                    put("timestamp", System.currentTimeMillis())
                },
            )
        }
    }

    private fun openDatabase(context: Context): SQLiteDatabase {
        // Android's sqflite getDatabasesPath() resolves to this same database directory.
        val databaseFile = context.applicationContext.getDatabasePath(DATABASE_NAME)
        check(databaseFile.isFile) { "Call Guard database does not exist" }
        val database = SQLiteDatabase.openDatabase(
            databaseFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        )
        ensureRepeatColumns(database)
        return database
    }

    private fun ensureRepeatColumns(database: SQLiteDatabase) {
        val columns = mutableSetOf<String>()
        database.rawQuery("PRAGMA table_info(call_reminders)", null).use { cursor ->
            val nameColumn = cursor.getColumnIndexOrThrow("name")
            while (cursor.moveToNext()) columns.add(cursor.getString(nameColumn))
        }
        if ("repeat_type" !in columns) {
            database.execSQL(
                "ALTER TABLE call_reminders ADD COLUMN repeat_type TEXT NOT NULL DEFAULT 'none'",
            )
        }
        if ("repeat_interval" !in columns) {
            database.execSQL(
                "ALTER TABLE call_reminders ADD COLUMN repeat_interval INTEGER NOT NULL DEFAULT 1",
            )
        }
        if ("last_fired_at" !in columns) {
            database.execSQL("ALTER TABLE call_reminders ADD COLUMN last_fired_at INTEGER")
        }
    }

    private fun android.database.Cursor.toReminder(): CallReminderRecord =
        CallReminderRecord(
            id = getInt(getColumnIndexOrThrow("id")),
            phone = getString(getColumnIndexOrThrow("phone")).orEmpty(),
            contactName = getString(getColumnIndexOrThrow("contact_name")),
            remindAt = getLong(getColumnIndexOrThrow("remind_at")),
            note = getString(getColumnIndexOrThrow("note")),
            isDone = getInt(getColumnIndexOrThrow("is_done")) != 0,
            repeatType = getString(getColumnIndexOrThrow("repeat_type")) ?: "none",
            repeatInterval = getInt(getColumnIndexOrThrow("repeat_interval")).coerceAtLeast(1),
            lastFiredAt = if (isNull(getColumnIndexOrThrow("last_fired_at"))) {
                null
            } else {
                getLong(getColumnIndexOrThrow("last_fired_at"))
            },
        )

    private val reminderColumns = arrayOf(
        "id",
        "phone",
        "contact_name",
        "remind_at",
        "note",
        "is_done",
        "repeat_type",
        "repeat_interval",
        "last_fired_at",
    )

    private const val DATABASE_NAME = "call_guard.db"
}

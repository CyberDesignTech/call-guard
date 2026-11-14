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
)

/** Minimal native access to the SQLite tables created by the Flutter sqflite helper. */
object CallReminderStore {
    fun findReminder(context: Context, id: Int): CallReminderRecord? =
        openDatabase(context).use { database ->
            database.query(
                "call_reminders",
                arrayOf("id", "phone", "contact_name", "remind_at", "note", "is_done"),
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

    fun pendingReminders(context: Context): List<CallReminderRecord> =
        openDatabase(context).use { database ->
            val reminders = mutableListOf<CallReminderRecord>()
            database.query(
                "call_reminders",
                arrayOf("id", "phone", "contact_name", "remind_at", "note", "is_done"),
                "is_done = 0",
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
        return SQLiteDatabase.openDatabase(
            databaseFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        )
    }

    private fun android.database.Cursor.toReminder(): CallReminderRecord =
        CallReminderRecord(
            id = getInt(getColumnIndexOrThrow("id")),
            phone = getString(getColumnIndexOrThrow("phone")).orEmpty(),
            contactName = getString(getColumnIndexOrThrow("contact_name")),
            remindAt = getLong(getColumnIndexOrThrow("remind_at")),
            note = getString(getColumnIndexOrThrow("note")),
            isDone = getInt(getColumnIndexOrThrow("is_done")) != 0,
        )

    private const val DATABASE_NAME = "call_guard.db"
}

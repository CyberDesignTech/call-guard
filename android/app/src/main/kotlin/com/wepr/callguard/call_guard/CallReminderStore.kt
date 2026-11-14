package com.wepr.callguard.call_guard

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
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

data class ReminderScheduleUpdate(
    val id: Int,
    val remindAt: Long,
    val repeatType: String,
    val repeatInterval: Int,
    val lastFiredAt: Long?,
)

/** Minimal native access to the SQLite tables created by the Flutter sqflite helper. */
object CallReminderStore {
    fun findReminder(context: Context, id: Int): CallReminderRecord? =
        CallGuardDatabase.withDatabase(context) { database ->
            database.query(
                DbContract.CallReminders.TABLE,
                reminderColumns,
                "${DbContract.CallReminders.ID} = ?",
                arrayOf(id.toString()),
                null,
                null,
                null,
                "1",
            ).use { cursor ->
                if (!cursor.moveToFirst()) return@withDatabase null
                cursor.toReminder()
            }
        }

    fun pendingReminders(
        context: Context,
        includeFiredOneTime: Boolean = false,
    ): List<CallReminderRecord> =
        CallGuardDatabase.withDatabase(context) { database ->
            val reminders = mutableListOf<CallReminderRecord>()
            database.query(
                DbContract.CallReminders.TABLE,
                reminderColumns,
                if (includeFiredOneTime) {
                    "${DbContract.CallReminders.IS_DONE} = 0"
                } else {
                    "${DbContract.CallReminders.IS_DONE} = 0 AND " +
                        "(${DbContract.CallReminders.REPEAT_TYPE} != 'none' OR " +
                        "${DbContract.CallReminders.LAST_FIRED_AT} IS NULL)"
                },
                null,
                null,
                null,
                "${DbContract.CallReminders.REMIND_AT} ASC",
            ).use { cursor ->
                while (cursor.moveToNext()) reminders.add(cursor.toReminder())
            }
            reminders
        }

    fun markDone(context: Context, id: Int): Boolean =
        CallGuardDatabase.withDatabase(context) { database ->
            database.update(
                DbContract.CallReminders.TABLE,
                ContentValues().apply { put(DbContract.CallReminders.IS_DONE, 1) },
                "${DbContract.CallReminders.ID} = ?",
                arrayOf(id.toString()),
            ) > 0
        }

    fun markFired(context: Context, id: Int, firedAt: Long = System.currentTimeMillis()): Boolean =
        CallGuardDatabase.withDatabase(context) { database ->
            database.update(
                DbContract.CallReminders.TABLE,
                ContentValues().apply {
                    put(DbContract.CallReminders.LAST_FIRED_AT, firedAt)
                },
                "${DbContract.CallReminders.ID} = ? AND ${DbContract.CallReminders.IS_DONE} = 0",
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
    ): Boolean = CallGuardDatabase.withDatabase(context) { database ->
        updateScheduleRow(
            database,
            ReminderScheduleUpdate(
                id = id,
                remindAt = remindAt,
                repeatType = repeatType,
                repeatInterval = repeatInterval,
                lastFiredAt = lastFiredAt,
            ),
        )
    }

    /**
     * Updates several advanced repeating reminders in one transaction.
     *
     * @return ids whose row was actually updated.
     */
    fun updateReminderSchedules(
        context: Context,
        updates: List<ReminderScheduleUpdate>,
    ): Set<Int> {
        if (updates.isEmpty()) return emptySet()
        return CallGuardDatabase.withDatabase(context) { database ->
            val updatedIds = mutableSetOf<Int>()
            database.beginTransaction()
            try {
                updates.forEach { update ->
                    if (updateScheduleRow(database, update)) updatedIds.add(update.id)
                }
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
            updatedIds
        }
    }

    fun getSetting(context: Context, key: String, fallback: String = ""): String =
        CallGuardDatabase.withDatabase(context) { database ->
            database.query(
                DbContract.AppSettings.TABLE,
                arrayOf(DbContract.AppSettings.VALUE),
                "`${DbContract.AppSettings.KEY}` = ?",
                arrayOf(key),
                null,
                null,
                null,
                "1",
            ).use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0).orEmpty() else fallback
            }
        }

    /** Inserts a local callback reminder unless an equivalent one was just created. */
    fun insertReminderIfNotRecentlyCreated(
        context: Context,
        phone: String,
        remindAt: Long,
        note: String,
        dedupeWindowMs: Long = DEFAULT_REMINDER_DEDUPE_WINDOW_MS,
    ): Int? = CallGuardDatabase.withDatabase(context) { database ->
        val canonicalPhone = PhoneNumbers.canonicalize(context, phone)
        if (canonicalPhone.isBlank()) return@withDatabase null

        val now = System.currentTimeMillis()
        var reminderId: Int? = null
        database.beginTransaction()
        try {
            val hasRecentDuplicate = database.query(
                DbContract.CallReminders.TABLE,
                arrayOf(DbContract.CallReminders.PHONE),
                "${DbContract.CallReminders.CREATED_AT} >= ? AND " +
                    "${DbContract.CallReminders.NOTE} = ?",
                arrayOf(
                    (now - dedupeWindowMs.coerceAtLeast(0)).toString(),
                    note,
                ),
                null,
                null,
                null,
            ).use { cursor ->
                val phoneColumn = cursor.getColumnIndexOrThrow(DbContract.CallReminders.PHONE)
                var duplicate = false
                while (cursor.moveToNext() && !duplicate) {
                    duplicate = sameCanonicalPhone(
                        context,
                        canonicalPhone,
                        cursor.getString(phoneColumn).orEmpty(),
                    )
                }
                duplicate
            }

            if (!hasRecentDuplicate) {
                reminderId = database.insertOrThrow(
                    DbContract.CallReminders.TABLE,
                    null,
                    ContentValues().apply {
                        put(DbContract.CallReminders.PHONE, canonicalPhone)
                        putNull(DbContract.CallReminders.CONTACT_NAME)
                        put(DbContract.CallReminders.REMIND_AT, remindAt)
                        put(DbContract.CallReminders.NOTE, note)
                        put(DbContract.CallReminders.IS_DONE, 0)
                        put(DbContract.CallReminders.REPEAT_TYPE, "none")
                        put(DbContract.CallReminders.REPEAT_INTERVAL, 1)
                        putNull(DbContract.CallReminders.LAST_FIRED_AT)
                        put(DbContract.CallReminders.CREATED_AT, now)
                    },
                ).toInt()
                database.setTransactionSuccessful()
            }
        } finally {
            database.endTransaction()
        }
        reminderId
    }

    /** Idempotently adds a canonical, open phone number to the existing white list. */
    fun addToWhitelistIfAbsent(context: Context, phone: String): Boolean =
        CallGuardDatabase.withDatabase(context) { database ->
            val canonicalPhone = PhoneNumbers.canonicalize(context, phone)
            if (canonicalPhone.isBlank()) return@withDatabase false

            var inserted = false
            database.beginTransaction()
            try {
                val alreadyAllowed = database.query(
                    DbContract.PhoneRules.TABLE,
                    arrayOf(DbContract.PhoneRules.PHONE),
                    "${DbContract.PhoneRules.LIST_TYPE} = ?",
                    arrayOf(DbContract.PhoneRules.WHITE),
                    null,
                    null,
                    null,
                ).use { cursor ->
                    val phoneColumn = cursor.getColumnIndexOrThrow(DbContract.PhoneRules.PHONE)
                    var found = false
                    while (cursor.moveToNext() && !found) {
                        found = sameCanonicalPhone(
                            context,
                            canonicalPhone,
                            cursor.getString(phoneColumn).orEmpty(),
                        )
                    }
                    found
                }
                if (!alreadyAllowed) {
                    database.insertOrThrow(
                        DbContract.PhoneRules.TABLE,
                        null,
                        ContentValues().apply {
                            put(DbContract.PhoneRules.PHONE, canonicalPhone)
                            putNull(DbContract.PhoneRules.LABEL)
                            put(DbContract.PhoneRules.LIST_TYPE, DbContract.PhoneRules.WHITE)
                            put(DbContract.PhoneRules.CREATED_AT, System.currentTimeMillis())
                        },
                    )
                    inserted = true
                }
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
            inserted
        }

    fun insertCallLog(context: Context, phone: String, reason: String) {
        CallGuardDatabase.withDatabase(context) { database ->
            database.insertOrThrow(
                DbContract.CallLogs.TABLE,
                null,
                ContentValues().apply {
                    put(
                        DbContract.CallLogs.PHONE,
                        phone.ifBlank { PhoneNumbers.HIDDEN_NUMBER },
                    )
                    put(DbContract.CallLogs.REASON, reason)
                    put(DbContract.CallLogs.TIMESTAMP, System.currentTimeMillis())
                },
            )
        }
    }

    private fun updateScheduleRow(
        database: SQLiteDatabase,
        update: ReminderScheduleUpdate,
    ): Boolean = database.update(
        DbContract.CallReminders.TABLE,
        ContentValues().apply {
            put(DbContract.CallReminders.REMIND_AT, update.remindAt)
            put(DbContract.CallReminders.REPEAT_TYPE, update.repeatType)
            put(
                DbContract.CallReminders.REPEAT_INTERVAL,
                update.repeatInterval.coerceAtLeast(1),
            )
            put(DbContract.CallReminders.IS_DONE, 0)
            if (update.lastFiredAt == null) {
                putNull(DbContract.CallReminders.LAST_FIRED_AT)
            } else {
                put(DbContract.CallReminders.LAST_FIRED_AT, update.lastFiredAt)
            }
        },
        "${DbContract.CallReminders.ID} = ? AND ${DbContract.CallReminders.IS_DONE} = 0",
        arrayOf(update.id.toString()),
    ) > 0

    private fun sameCanonicalPhone(context: Context, first: String, second: String): Boolean {
        val firstCanonical = PhoneNumbers.canonicalize(context, first)
        val secondCanonical = PhoneNumbers.canonicalize(context, second)
        val firstDigits = PhoneNumbers.digits(firstCanonical)
        val secondDigits = PhoneNumbers.digits(secondCanonical)
        if (firstDigits.isNotEmpty() && firstDigits == secondDigits) return true
        return PhoneNumbers.compare(context, firstCanonical, secondCanonical)
    }

    private fun Cursor.toReminder(): CallReminderRecord =
        CallReminderRecord(
            id = getInt(getColumnIndexOrThrow(DbContract.CallReminders.ID)),
            phone = getString(getColumnIndexOrThrow(DbContract.CallReminders.PHONE)).orEmpty(),
            contactName = getString(getColumnIndexOrThrow(DbContract.CallReminders.CONTACT_NAME)),
            remindAt = getLong(getColumnIndexOrThrow(DbContract.CallReminders.REMIND_AT)),
            note = getString(getColumnIndexOrThrow(DbContract.CallReminders.NOTE)),
            isDone = getInt(getColumnIndexOrThrow(DbContract.CallReminders.IS_DONE)) != 0,
            repeatType = getString(
                getColumnIndexOrThrow(DbContract.CallReminders.REPEAT_TYPE),
            ) ?: "none",
            repeatInterval = getInt(
                getColumnIndexOrThrow(DbContract.CallReminders.REPEAT_INTERVAL),
            ).coerceAtLeast(1),
            lastFiredAt = if (
                isNull(getColumnIndexOrThrow(DbContract.CallReminders.LAST_FIRED_AT))
            ) {
                null
            } else {
                getLong(getColumnIndexOrThrow(DbContract.CallReminders.LAST_FIRED_AT))
            },
        )

    private val reminderColumns = arrayOf(
        DbContract.CallReminders.ID,
        DbContract.CallReminders.PHONE,
        DbContract.CallReminders.CONTACT_NAME,
        DbContract.CallReminders.REMIND_AT,
        DbContract.CallReminders.NOTE,
        DbContract.CallReminders.IS_DONE,
        DbContract.CallReminders.REPEAT_TYPE,
        DbContract.CallReminders.REPEAT_INTERVAL,
        DbContract.CallReminders.LAST_FIRED_AT,
        DbContract.CallReminders.CREATED_AT,
    )

    private const val DEFAULT_REMINDER_DEDUPE_WINDOW_MS = 5 * 60 * 1000L
}

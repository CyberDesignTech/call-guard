package com.wepr.callguard

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/** Writes native widget actions into the same SQLite settings table as Flutter. */
internal object CallGateModeStore {
    fun apply(context: Context, action: CallGateWidgetAction): Pair<Map<String, String>, Map<String, String>> =
        CallGuardDatabase.withDatabase(context) { database ->
            database.beginTransaction()
            try {
                val before = CallGuardDatabase.readSettings(context)
                action.changes(before, System.currentTimeMillis()).forEach { (key, value) ->
                    writeSetting(database, key, value)
                }
                val after = CallGuardDatabase.readSettings(context)
                database.setTransactionSuccessful()
                before to after
            } finally {
                database.endTransaction()
            }
        }

    /** Clears an elapsed timer; returns false if a newer timer is still active. */
    fun clearExpiredQuickSilence(context: Context, nowMillis: Long): Boolean =
        CallGuardDatabase.withDatabase(context) { database ->
            database.beginTransaction()
            try {
                val current = CallGuardDatabase.readSettings(context)[
                    DbContract.SettingKeys.QUICK_SILENCE_UNTIL
                ]?.toLongOrNull() ?: 0L
                val expired = current <= nowMillis
                if (expired && current != 0L) {
                    writeSetting(database, DbContract.SettingKeys.QUICK_SILENCE_UNTIL, "0")
                }
                database.setTransactionSuccessful()
                expired
            } finally {
                database.endTransaction()
            }
        }

    fun publish(context: Context, settings: Map<String, String>) {
        // Render the widget and refresh an open Flutter screen before doing the
        // slower status-notification work so a tap is reflected immediately.
        CallGateWidgetProvider.requestUpdate(context)
        runCatching {
            context.sendBroadcast(
                Intent(BridgeContract.Actions.STATUS_MODES_CHANGED).setPackage(context.packageName),
            )
        }.onFailure { Log.w(TAG, "Could not notify the open CallGate UI", it) }
        runCatching {
            CallNotificationHelper.updateStatusIndicator(
                context = context,
                enabled = BootCompletedReceiver.hasCallScreeningRole(context) &&
                    settings[DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED]
                        ?.toBooleanStrictOrNull() != false,
                protectionEnabled = settings[DbContract.SettingKeys.PROTECTION_ENABLED]
                    ?.toBooleanStrictOrNull() ?: true,
                drivingMode = settings[DbContract.SettingKeys.DRIVING_MODE]
                    ?.toBooleanStrictOrNull() ?: false,
                locale = settings[DbContract.SettingKeys.LOCALE] ?: "english",
            )
        }.onFailure { Log.w(TAG, "Could not refresh the CallGate status notification", it) }
    }

    private fun writeSetting(database: SQLiteDatabase, key: String, value: String) {
        check(
            database.insertWithOnConflict(
                DbContract.AppSettings.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.AppSettings.KEY, key)
                    put(DbContract.AppSettings.VALUE, value)
                },
                SQLiteDatabase.CONFLICT_REPLACE,
            ) != -1L,
        ) { "Could not persist setting $key" }
    }

    private const val TAG = "CallGateModeStore"
}

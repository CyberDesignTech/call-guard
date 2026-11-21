package com.wepr.callguard.call_guard

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.util.concurrent.Executors

/** Toggles persisted CallGate modes directly from the status notification. */
class CallStatusActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val toggle = StatusModeToggle.fromAction(intent.action) ?: return
        val appContext = context.applicationContext
        Log.i(TAG, "Notification action requested: ${toggle.logLabel}")

        val pendingResult = goAsync()
        try {
            worker.execute {
                try {
                    val settings = toggleSettingAndReadBack(appContext, toggle)
                    Log.i(TAG, "Saved ${toggle.settingKey}=${settings[toggle.settingKey]}")
                    runCatching {
                        DndSyncController.syncWithActiveModes(appContext)
                    }.onFailure {
                        Log.w(TAG, "Could not synchronize DND after a notification action", it)
                    }
                    runCatching {
                        CallNotificationHelper.updateStatusIndicator(
                            context = appContext,
                            enabled = BootCompletedReceiver.hasCallScreeningRole(appContext) &&
                                settings[DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED]
                                    ?.toBooleanStrictOrNull() != false,
                            protectionEnabled = settings.booleanSetting(
                                DbContract.SettingKeys.PROTECTION_ENABLED,
                                true,
                            ),
                            drivingMode = settings.booleanSetting(
                                DbContract.SettingKeys.DRIVING_MODE,
                                false,
                            ),
                            locale = settings[DbContract.SettingKeys.LOCALE] ?: "english",
                        )
                    }.onFailure {
                        Log.e(TAG, "Could not refresh the status notification", it)
                    }
                    runCatching {
                        appContext.sendBroadcast(
                            Intent(BridgeContract.Actions.STATUS_MODES_CHANGED)
                                .setPackage(appContext.packageName),
                        )
                    }.onFailure {
                        Log.w(TAG, "Could not notify an active CallGate UI", it)
                    }
                } catch (error: Exception) {
                    // A failed transaction rolls back; don't publish uncommitted modes.
                    Log.e(TAG, "Could not process ${toggle.logLabel} notification action", error)
                } finally {
                    pendingResult.finish()
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not schedule ${toggle.logLabel} notification action", error)
            pendingResult.finish()
        }
    }

    /** Reads, toggles, writes, and verifies the shared app_settings row atomically. */
    private fun toggleSettingAndReadBack(
        context: Context,
        toggle: StatusModeToggle,
    ): Map<String, String> = CallGuardDatabase.withDatabase(context) { database ->
        database.beginTransaction()
        try {
            val currentSettings = CallGuardDatabase.readSettings(context)
            val currentValue = currentSettings.booleanSetting(
                toggle.settingKey,
                toggle.defaultValue,
            )
            val nextValue = toggle.nextValue(currentValue)
            val values = ContentValues().apply {
                put(DbContract.AppSettings.KEY, toggle.settingKey)
                put(DbContract.AppSettings.VALUE, nextValue.toString())
            }
            check(
                database.insertWithOnConflict(
                    DbContract.AppSettings.TABLE,
                    null,
                    values,
                    SQLiteDatabase.CONFLICT_REPLACE,
                ) != -1L,
            ) { "Could not persist ${toggle.settingKey}" }

            val updatedSettings = CallGuardDatabase.readSettings(context)
            check(updatedSettings.booleanSetting(toggle.settingKey, toggle.defaultValue) == nextValue) {
                "Could not verify ${toggle.settingKey} after write"
            }
            database.setTransactionSuccessful()
            updatedSettings
        } finally {
            database.endTransaction()
        }
    }

    private companion object {
        const val TAG = "CallGateStatusAction"
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGateStatusActions").apply { isDaemon = true }
        }
    }
}

private fun Map<String, String>.booleanSetting(key: String, fallback: Boolean): Boolean =
    this[key]?.toBooleanStrictOrNull() ?: fallback

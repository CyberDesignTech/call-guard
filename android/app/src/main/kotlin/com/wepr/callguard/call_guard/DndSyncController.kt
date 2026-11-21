package com.wepr.callguard.call_guard

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import java.util.Calendar

/** Safely mirrors active CallGate modes to Android's interruption filter. */
object DndSyncController {
    const val NO_PREVIOUS_FILTER = -1

    private val syncLock = Any()

    fun isPolicyAccessGranted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return runCatching {
            context.getSystemService(NotificationManager::class.java)
                ?.isNotificationPolicyAccessGranted == true
        }.getOrDefault(false)
    }

    fun openPolicyAccessSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return runCatching {
            context.startActivity(
                Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        }.getOrDefault(false)
    }

    /** Reads persisted settings, syncs DND, and arms the next schedule boundary. */
    fun syncWithActiveModes(context: Context) {
        val appContext = context.applicationContext
        synchronized(syncLock) {
            try {
                val settings = CallGuardDatabase.readSettings(appContext)
                DndScheduleScheduler.scheduleNext(appContext, settings)

                val manager = appContext.getSystemService(NotificationManager::class.java)
                    ?: return
                if (!isPolicyAccessGranted(appContext)) return

                reconcile(
                    settings = settings,
                    hasPolicyAccess = true,
                    currentFilter = manager.currentInterruptionFilter,
                    persistPreviousFilter = { value ->
                        persistPreviousFilter(appContext, value)
                    },
                    setInterruptionFilter = manager::setInterruptionFilter,
                    now = Calendar.getInstance(),
                )
            } catch (error: Exception) {
                Log.w(TAG, "Could not synchronize Android Do Not Disturb", error)
            }
        }
    }

    /** Pure transition logic kept injectable for deterministic local unit tests. */
    internal fun reconcile(
        settings: Map<String, String>,
        hasPolicyAccess: Boolean,
        currentFilter: Int,
        persistPreviousFilter: (String) -> Unit,
        setInterruptionFilter: (Int) -> Unit,
        now: Calendar = Calendar.getInstance(),
    ) {
        if (!hasPolicyAccess) return

        val previous = settings[DbContract.SettingKeys.DND_PREVIOUS_FILTER]
            ?.toIntOrNull()
            ?: NO_PREVIOUS_FILTER
        val shouldActivate =
            settings.booleanSetting(DbContract.SettingKeys.PROTECTION_ENABLED, true) &&
                settings.booleanSetting(DbContract.SettingKeys.DND_SYNC_ENABLED, false) &&
                (
                    settings.booleanSetting(DbContract.SettingKeys.DRIVING_MODE, false) ||
                        settings.booleanSetting(
                            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED,
                            false,
                        ) ||
                        settings.booleanSetting(DbContract.SettingKeys.MANUAL_SILENCE, false) ||
                        settings.booleanSetting(DbContract.SettingKeys.SILENCE_MANUAL, false) ||
                        settings.booleanSetting(DbContract.SettingKeys.AUTOMATIC_SILENCE, false) &&
                        QuietSchedulePolicy.isWithin(settings, now)
                    )

        if (shouldActivate) {
            // Do not take ownership of an existing manual DND filter. Once we
            // own the filter, also respect a later user change away from PRIORITY.
            if (previous == NO_PREVIOUS_FILTER &&
                currentFilter == NotificationManager.INTERRUPTION_FILTER_ALL
            ) {
                persistPreviousFilter(currentFilter.toString())
                try {
                    setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                } catch (error: SecurityException) {
                    persistPreviousFilter(NO_PREVIOUS_FILTER.toString())
                    throw error
                }
            }
            return
        }

        if (previous != NO_PREVIOUS_FILTER) {
            // Restore only while the current filter is still the one CallGate set.
            // A different filter means the user changed DND manually; leave it alone.
            if (currentFilter == NotificationManager.INTERRUPTION_FILTER_PRIORITY) {
                try {
                    setInterruptionFilter(previous)
                } catch (error: SecurityException) {
                    Log.w(TAG, "Could not restore the previous DND filter", error)
                    return
                }
            }
            persistPreviousFilter(NO_PREVIOUS_FILTER.toString())
        }
    }

    private fun persistPreviousFilter(context: Context, value: String) {
        CallGuardDatabase.withDatabase(context) { database ->
            val values = ContentValues().apply {
                put(DbContract.AppSettings.KEY, DbContract.SettingKeys.DND_PREVIOUS_FILTER)
                put(DbContract.AppSettings.VALUE, value)
            }
            check(
                database.insertWithOnConflict(
                    DbContract.AppSettings.TABLE,
                    null,
                    values,
                    android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE,
                ) != -1L,
            ) { "Could not persist the previous DND filter" }
        }
    }

    private fun Map<String, String>.booleanSetting(key: String, fallback: Boolean): Boolean =
        this[key]?.toBooleanStrictOrNull() ?: fallback

    private const val TAG = "CallGateDndSync"
}

/** Re-evaluates DND at scheduled quiet-mode boundaries. */
internal object DndScheduleScheduler {
    private const val REQUEST_CODE = 0x4347444E

    fun scheduleNext(context: Context, settings: Map<String, String>) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = pendingIntent(context, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        val shouldTrackSchedule =
            settings[DbContract.SettingKeys.PROTECTION_ENABLED]
                ?.toBooleanStrictOrNull() != false &&
                settings[DbContract.SettingKeys.DND_SYNC_ENABLED]
                    ?.toBooleanStrictOrNull() == true &&
                settings[DbContract.SettingKeys.AUTOMATIC_SILENCE]
                    ?.toBooleanStrictOrNull() == true
        if (!shouldTrackSchedule) {
            alarmManager.cancel(pendingIntent)
            return
        }

        val nextTransition = QuietSchedulePolicy.nextTransitionAtMillis(
            settings,
            Calendar.getInstance(),
        ) ?: run {
            alarmManager.cancel(pendingIntent)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTransition,
                    pendingIntent,
                )
            } else {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTransition,
                    pendingIntent,
                )
            }
        } catch (error: SecurityException) {
            runCatching {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextTransition,
                    pendingIntent,
                )
            }.onFailure {
                Log.w(TAG, "Could not schedule the next DND boundary", it)
            }
        }
    }

    private fun pendingIntent(context: Context, mode: Int): PendingIntent? {
        val intent = Intent(context, DndScheduleReceiver::class.java)
            .setAction(ACTION_SYNC_SCHEDULE)
            .setPackage(context.packageName)
        val flags = mode or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }

    private const val TAG = "CallGateDndSchedule"
    internal const val ACTION_SYNC_SCHEDULE = "com.wepr.callguard.action.SYNC_DND_SCHEDULE"
}

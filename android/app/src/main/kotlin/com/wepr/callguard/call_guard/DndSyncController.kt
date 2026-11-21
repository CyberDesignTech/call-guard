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

/**
 * Safely mirrors active CallGate modes to Android's interruption filter.
 *
 * CallGate records the user's policy only when the current filter is ALL.
 * It restores that policy only while the filter is still PRIORITY, avoiding
 * overwriting a manual DND change made outside the app.
 */
object DndSyncController {
    const val NO_PREVIOUS_FILTER = -1

    private val syncLock = Any()

    /** Returns whether Android granted notification-policy access to CallGate. */
    fun hasPolicyAccess(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return runCatching {
            context.getSystemService(NotificationManager::class.java)
                ?.isNotificationPolicyAccessGranted == true
        }.getOrDefault(false)
    }

    fun isPolicyAccessGranted(context: Context): Boolean = hasPolicyAccess(context)

    /** Opens the system screen where notification-policy access can be granted. */
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

    /** Reads settings, reconciles DND ownership, and arms the next schedule boundary. */
    fun syncWithActiveModes(context: Context) {
        val appContext = context.applicationContext
        synchronized(syncLock) {
            try {
                val settings = CallGuardDatabase.readSettings(appContext)
                DndScheduleScheduler.scheduleNext(appContext, settings)

                val manager = appContext.getSystemService(NotificationManager::class.java)
                    ?: return
                if (!hasPolicyAccess(appContext)) return

                reconcile(
                    settings = settings,
                    hasPolicyAccess = true,
                    currentFilter = manager.currentInterruptionFilter,
                    currentPolicy = DndPolicySnapshot.from(manager.notificationPolicy),
                    persistPreviousState = { filter, policy ->
                        persistPreviousState(appContext, filter, policy)
                    },
                    clearPreviousState = { clearPreviousState(appContext) },
                    setNotificationPolicy = manager::setNotificationPolicy,
                    setInterruptionFilter = manager::setInterruptionFilter,
                    now = Calendar.getInstance(),
                )
            } catch (error: Exception) {
                Log.w(TAG, "Could not synchronize Android Do Not Disturb", error)
            }
        }
    }

    /**
     * Applies the DND ownership state machine without performing I/O itself.
     * Keeping it pure makes restoration and manual-user-change cases testable.
     */
    internal fun reconcile(
        settings: Map<String, String>,
        hasPolicyAccess: Boolean,
        currentFilter: Int,
        currentPolicy: DndPolicySnapshot,
        persistPreviousState: (Int, DndPolicySnapshot) -> Unit,
        clearPreviousState: () -> Unit,
        setNotificationPolicy: (NotificationManager.Policy) -> Unit,
        setInterruptionFilter: (Int) -> Unit,
        now: Calendar = Calendar.getInstance(),
    ) {
        if (!hasPolicyAccess) return

        val previous = settings[DbContract.SettingKeys.DND_PREVIOUS_FILTER]
            ?.toIntOrNull()
            ?: NO_PREVIOUS_FILTER
        val previousPolicy = savedPolicyFromSettings(settings)
        val quietScheduleActive =
            settings.booleanSetting(DbContract.SettingKeys.AUTOMATIC_SILENCE, false) &&
                QuietSchedulePolicy.isWithin(settings, now)
        val autoModeSyncActive =
            settings.booleanSetting(DbContract.SettingKeys.DND_SYNC_ENABLED, false) &&
                (
                    settings.booleanSetting(DbContract.SettingKeys.DRIVING_MODE, false) ||
                        settings.booleanSetting(
                            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED,
                            false,
                        ) ||
                        settings.booleanSetting(DbContract.SettingKeys.MANUAL_SILENCE, false) ||
                        settings.booleanSetting(DbContract.SettingKeys.SILENCE_MANUAL, false) ||
                        quietScheduleActive
                    )
        val shouldActivate =
            settings.booleanSetting(DbContract.SettingKeys.PROTECTION_ENABLED, true) &&
                (
                    settings.booleanSetting(
                        DbContract.SettingKeys.MANUAL_MESSENGER_MUTE,
                        false,
                    ) || autoModeSyncActive
                    )

        if (shouldActivate) {
            // Do not take ownership of an existing manual DND filter. Once we
            // own the filter, also respect a later user change away from PRIORITY.
            if (previous == NO_PREVIOUS_FILTER &&
                currentFilter == NotificationManager.INTERRUPTION_FILTER_ALL
            ) {
                val policyToRestore = previousPolicy ?: currentPolicy
                persistPreviousState(currentFilter, policyToRestore)
                val mutedPolicy = NotificationManager.Policy(
                    NotificationManager.Policy.PRIORITY_CATEGORY_CALLS or
                        NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS,
                    NotificationManager.Policy.PRIORITY_SENDERS_ANY,
                    // Message categories are excluded entirely; keep the unused
                    // sender setting conservative in case policy bits change later.
                    NotificationManager.Policy.PRIORITY_SENDERS_CONTACTS,
                    currentPolicy.suppressedVisualEffects or
                        NotificationManager.Policy.SUPPRESSED_EFFECT_PEEK,
                )
                try {
                    setNotificationPolicy(mutedPolicy)
                    setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
                } catch (error: SecurityException) {
                    runCatching { setNotificationPolicy(currentPolicy.toPlatformPolicy()) }
                    clearPreviousState()
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
                    previousPolicy?.let { setNotificationPolicy(it.toPlatformPolicy()) }
                    setInterruptionFilter(previous)
                } catch (error: SecurityException) {
                    Log.w(TAG, "Could not restore the previous DND policy/filter", error)
                    return
                }
            }
            clearPreviousState()
        }
    }

    private fun savedPolicyFromSettings(settings: Map<String, String>): DndPolicySnapshot? {
        val categories = settings[DbContract.SettingKeys.DND_PREVIOUS_POLICY_CATEGORIES]
            ?.toIntOrNull()
            ?: NO_PREVIOUS_FILTER
        if (categories == NO_PREVIOUS_FILTER) return null
        return DndPolicySnapshot(
            priorityCategories = categories,
            priorityCallSenders = settings[
                DbContract.SettingKeys.DND_PREVIOUS_POLICY_CALL_SENDERS
            ]?.toIntOrNull() ?: NotificationManager.Policy.PRIORITY_SENDERS_ANY,
            priorityMessageSenders = settings[
                DbContract.SettingKeys.DND_PREVIOUS_POLICY_MSG_SENDERS
            ]?.toIntOrNull() ?: NotificationManager.Policy.PRIORITY_SENDERS_ANY,
            suppressedVisualEffects = settings[
                DbContract.SettingKeys.DND_PREVIOUS_POLICY_SUPPRESSED
            ]?.toIntOrNull() ?: 0,
        )
    }

    private fun persistPreviousState(
        context: Context,
        interruptionFilter: Int,
        policy: DndPolicySnapshot,
    ) {
        CallGuardDatabase.withDatabase(context) { database ->
            database.beginTransaction()
            try {
                writeSetting(database, DbContract.SettingKeys.DND_PREVIOUS_FILTER, interruptionFilter)
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_CATEGORIES,
                    policy.priorityCategories,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_CALL_SENDERS,
                    policy.priorityCallSenders,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_MSG_SENDERS,
                    policy.priorityMessageSenders,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_SUPPRESSED,
                    policy.suppressedVisualEffects,
                )
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
    }

    private fun clearPreviousState(context: Context) {
        CallGuardDatabase.withDatabase(context) { database ->
            database.beginTransaction()
            try {
                writeSetting(database, DbContract.SettingKeys.DND_PREVIOUS_FILTER, NO_PREVIOUS_FILTER)
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_CATEGORIES,
                    NO_PREVIOUS_FILTER,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_CALL_SENDERS,
                    NO_PREVIOUS_FILTER,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_MSG_SENDERS,
                    NO_PREVIOUS_FILTER,
                )
                writeSetting(
                    database,
                    DbContract.SettingKeys.DND_PREVIOUS_POLICY_SUPPRESSED,
                    NO_PREVIOUS_FILTER,
                )
                database.setTransactionSuccessful()
            } finally {
                database.endTransaction()
            }
        }
    }

    private fun writeSetting(
        database: android.database.sqlite.SQLiteDatabase,
        key: String,
        value: Int,
    ) {
        val values = ContentValues().apply {
            put(DbContract.AppSettings.KEY, key)
            put(DbContract.AppSettings.VALUE, value.toString())
        }
        check(
            database.insertWithOnConflict(
                DbContract.AppSettings.TABLE,
                null,
                values,
                android.database.sqlite.SQLiteDatabase.CONFLICT_REPLACE,
            ) != -1L,
        ) { "Could not persist DND state key $key" }
    }

    private fun DndPolicySnapshot.toPlatformPolicy(): NotificationManager.Policy =
        NotificationManager.Policy(
            priorityCategories,
            priorityCallSenders,
            priorityMessageSenders,
            suppressedVisualEffects,
        )

    internal data class DndPolicySnapshot(
        val priorityCategories: Int,
        val priorityCallSenders: Int,
        val priorityMessageSenders: Int,
        val suppressedVisualEffects: Int,
    ) {
        companion object {
            fun from(policy: NotificationManager.Policy) = DndPolicySnapshot(
                priorityCategories = policy.priorityCategories,
                priorityCallSenders = policy.priorityCallSenders,
                priorityMessageSenders = policy.priorityMessageSenders,
                suppressedVisualEffects = policy.suppressedVisualEffects,
            )
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
                (
                    settings[DbContract.SettingKeys.DND_SYNC_ENABLED]
                        ?.toBooleanStrictOrNull() == true ||
                        settings[DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED]
                            ?.toBooleanStrictOrNull() != false
                    ) &&
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

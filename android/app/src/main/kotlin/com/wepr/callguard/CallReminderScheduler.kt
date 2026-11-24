package com.wepr.callguard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Schedules local reminder alarms and restores them after lifecycle events.
 *
 * Exact alarms are preferred for user-created reminders; an idle-safe fallback
 * keeps reminders usable when Android withholds exact-alarm access.
 */
object CallReminderScheduler {
    const val ACTION_FIRE_REMINDER = "com.wepr.callguard.action.FIRE_REMINDER"
    const val ACTION_MARK_REMINDER_DONE = "com.wepr.callguard.action.MARK_REMINDER_DONE"
    const val EXTRA_REMINDER_ID = "reminder_id"

    /** Arms or re-arms one reminder without changing its database record. */
    fun schedule(context: Context, reminderId: Int, remindAt: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = reminderPendingIntent(
            context,
            reminderId,
            PendingIntent.FLAG_UPDATE_CURRENT,
        ) ?: return
        val triggerAt = remindAt.coerceAtLeast(System.currentTimeMillis())

        try {
            // Alarm clocks are exact, wake the device from Doze and bypass app standby.
            // They are the strongest alarm API available to a reminder app.
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAt, showReminderUi(context, reminderId)),
                pendingIntent,
            )
        } catch (securityException: SecurityException) {
            // Android 12+ can withhold exact-alarm access. Keep the reminder usable
            // with the strongest idle-safe fallback instead of losing it entirely.
            Log.w(TAG, "Alarm-clock permission is unavailable; using an idle-safe fallback")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                @Suppress("DEPRECATION")
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }

    /** Cancels the alarm associated with one reminder id. */
    fun cancel(context: Context, reminderId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = reminderPendingIntent(
            context,
            reminderId,
            PendingIntent.FLAG_NO_CREATE,
        ) ?: return
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    /** Restores pending alarms and advances overdue repeating reminders after boot. */
    fun restorePending(context: Context, afterBoot: Boolean = false) {
        val now = System.currentTimeMillis()
        val pendingSchedules = mutableListOf<PendingSchedule>()
        val overdueUpdates = mutableListOf<ReminderScheduleUpdate>()

        CallReminderStore.pendingReminders(
            context,
            includeFiredOneTime = afterBoot,
        ).forEach { reminder ->
            if (reminder.repeatType == "none" && reminder.lastFiredAt != null) {
                return@forEach
            }
            if (afterBoot && reminder.repeatType != "none" && reminder.remindAt <= now) {
                val next = ReminderRepeatPolicy.nextOccurrence(reminder, now) ?: return@forEach
                overdueUpdates.add(
                    ReminderScheduleUpdate(
                        id = reminder.id,
                        remindAt = next,
                        repeatType = reminder.repeatType,
                        repeatInterval = reminder.repeatInterval,
                        lastFiredAt = now,
                    ),
                )
                pendingSchedules.add(
                    PendingSchedule(reminder.id, next, requiresDatabaseUpdate = true),
                )
            } else {
                pendingSchedules.add(
                    PendingSchedule(
                        reminder.id,
                        reminder.remindAt,
                        requiresDatabaseUpdate = false,
                    ),
                )
            }
        }

        // Advance every overdue repeating reminder in one transaction, then arm alarms.
        val updatedIds = CallReminderStore.updateReminderSchedules(context, overdueUpdates)
        pendingSchedules.forEach { pending ->
            if (!pending.requiresDatabaseUpdate || pending.id in updatedIds) {
                schedule(context, pending.id, pending.remindAt)
            }
        }
    }

    private data class PendingSchedule(
        val id: Int,
        val remindAt: Long,
        val requiresDatabaseUpdate: Boolean,
    )

    private fun reminderPendingIntent(
        context: Context,
        reminderId: Int,
        extraFlag: Int,
    ): PendingIntent? {
        val intent = Intent(context, CallReminderReceiver::class.java)
            .setAction(ACTION_FIRE_REMINDER)
            .putExtra(EXTRA_REMINDER_ID, reminderId)
        val flags = extraFlag or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(context, reminderId, intent, flags)
    }

    private fun showReminderUi(context: Context, reminderId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getActivity(
            context,
            reminderId xor SHOW_UI_REQUEST_CODE_MASK,
            intent,
            flags,
        )
    }

    private const val TAG = "CallReminderScheduler"
    private const val SHOW_UI_REQUEST_CODE_MASK = 0x40000000
}

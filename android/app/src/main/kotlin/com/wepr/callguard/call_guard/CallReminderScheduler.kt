package com.wepr.callguard.call_guard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object CallReminderScheduler {
    const val ACTION_FIRE_REMINDER = "com.wepr.callguard.action.FIRE_REMINDER"
    const val ACTION_MARK_REMINDER_DONE = "com.wepr.callguard.action.MARK_REMINDER_DONE"
    const val EXTRA_REMINDER_ID = "reminder_id"

    fun schedule(context: Context, reminderId: Int, remindAt: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pendingIntent = reminderPendingIntent(
            context,
            reminderId,
            PendingIntent.FLAG_UPDATE_CURRENT,
        ) ?: return
        val triggerAt = remindAt.coerceAtLeast(System.currentTimeMillis())

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        } catch (securityException: SecurityException) {
            Log.w(TAG, "Exact alarm permission is unavailable; using an inexact idle-safe alarm")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }
    }

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

    fun restorePending(context: Context) {
        CallReminderStore.pendingReminders(context).forEach { reminder ->
            schedule(context, reminder.id, reminder.remindAt)
        }
    }

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

    private const val TAG = "CallReminderScheduler"
}

package com.wepr.callguard.call_guard

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import java.util.concurrent.Executors

class CallReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        val reminderId = intent.getIntExtra(CallReminderScheduler.EXTRA_REMINDER_ID, -1)
        if (reminderId <= 0) return

        val wakeLock = (appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager)
            ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$TAG:Reminder")
        runCatching { wakeLock?.acquire(WAKE_LOCK_TIMEOUT_MS) }
            .onFailure { Log.w(TAG, "Could not acquire reminder wake lock", it) }
        val pendingResult = goAsync()
        worker.execute {
            try {
                when (intent.action) {
                    CallReminderScheduler.ACTION_MARK_REMINDER_DONE -> {
                        CallReminderStore.markDone(appContext, reminderId)
                        CallReminderScheduler.cancel(appContext, reminderId)
                        (appContext.getSystemService(Context.NOTIFICATION_SERVICE)
                            as? NotificationManager)?.cancel(reminderId)
                    }
                    CallReminderScheduler.ACTION_FIRE_REMINDER -> {
                        val reminder = CallReminderStore.findReminder(appContext, reminderId)
                        if (reminder == null || reminder.isDone) {
                            CallReminderScheduler.cancel(appContext, reminderId)
                        } else {
                            CallNotificationHelper.showReminder(appContext, reminder)
                            if (reminder.repeatType == "none") {
                                // One-time reminders must never fire again, even when the
                                // notification could not be shown (disabled channel/permission).
                                CallReminderStore.markFired(appContext, reminder.id)
                            } else {
                                // Repeating reminders must advance even if notifications are
                                // disabled, otherwise they would stay stuck in the past.
                                val now = System.currentTimeMillis()
                                val next = ReminderRepeatPolicy.nextOccurrence(reminder, now)
                                if (next != null && CallReminderStore.updateReminderSchedule(
                                        appContext,
                                        reminder.id,
                                        next,
                                        reminder.repeatType,
                                        reminder.repeatInterval,
                                        lastFiredAt = now,
                                    )
                                ) {
                                    CallReminderScheduler.schedule(appContext, reminder.id, next)
                                }
                            }
                        }
                    }
                }
            } catch (error: Exception) {
                Log.e(TAG, "Could not process call reminder $reminderId", error)
            } finally {
                runCatching {
                    if (wakeLock?.isHeld == true) wakeLock.release()
                }.onFailure { Log.w(TAG, "Could not release reminder wake lock", it) }
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "CallReminderReceiver"
        const val WAKE_LOCK_TIMEOUT_MS = 10_000L
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardReminderWorker").apply { isDaemon = true }
        }
    }
}

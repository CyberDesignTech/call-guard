package com.wepr.callguard.call_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

class CallReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val reminderId = intent.getIntExtra(CallReminderScheduler.EXTRA_REMINDER_ID, -1)
        if (reminderId <= 0) return

        val pendingResult = goAsync()
        worker.execute {
            try {
                when (intent.action) {
                    CallReminderScheduler.ACTION_MARK_REMINDER_DONE -> {
                        CallReminderStore.markDone(context, reminderId)
                        CallReminderScheduler.cancel(context, reminderId)
                        (context.getSystemService(Context.NOTIFICATION_SERVICE)
                            as? android.app.NotificationManager)?.cancel(reminderId)
                    }
                    CallReminderScheduler.ACTION_FIRE_REMINDER -> {
                        val reminder = CallReminderStore.findReminder(context, reminderId)
                        if (reminder == null || reminder.isDone) {
                            CallReminderScheduler.cancel(context, reminderId)
                        } else {
                            CallNotificationHelper.showReminder(context, reminder)
                        }
                    }
                }
            } catch (error: Exception) {
                Log.e(TAG, "Could not process call reminder $reminderId", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "CallReminderReceiver"
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardReminderWorker").apply { isDaemon = true }
        }
    }
}

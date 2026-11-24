package com.wepr.callguard

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

class AnsweringActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val phone = intent.getStringExtra(EXTRA_PHONE)?.trim().orEmpty()
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (!intent.hasExtra(EXTRA_NOTIFICATION_ID) || phone.isBlank() || isHiddenPhone(phone)) return

        val appContext = context.applicationContext
        val pendingResult = goAsync()
        worker.execute {
            try {
                when (action) {
                    ACTION_REMIND_30M -> createReminder(appContext, phone)
                    ACTION_ADD_WHITELIST -> CallReminderStore.addToWhitelistIfAbsent(
                        appContext,
                        phone,
                    )
                }
            } catch (error: Exception) {
                Log.e(TAG, "Could not process callback assistant action", error)
            } finally {
                (appContext.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                    ?.cancel(notificationId)
                pendingResult.finish()
            }
        }
    }

    private fun createReminder(context: Context, phone: String) {
        val remindAt = System.currentTimeMillis() + REMIND_AFTER_30_MINUTES_MS
        val reminderId = CallReminderStore.insertReminderIfNotRecentlyCreated(
            context = context,
            phone = phone,
            remindAt = remindAt,
            note = "@reminderNewNote",
        ) ?: return
        CallReminderScheduler.schedule(context, reminderId, remindAt)
    }

    private fun isHiddenPhone(phone: String): Boolean =
        PhoneNumbers.isHidden(phone) ||
            phone.equals(PhoneNumbers.HIDDEN_NUMBER, ignoreCase = true)

    companion object {
        const val ACTION_REMIND_30M = "com.wepr.callguard.action.REMIND_30M"
        const val ACTION_ADD_WHITELIST = "com.wepr.callguard.action.ADD_WHITELIST"
        const val EXTRA_PHONE = "answering_action_phone"
        const val EXTRA_NOTIFICATION_ID = "answering_action_notification_id"

        private const val TAG = "AnsweringActionReceiver"
        private const val REMIND_AFTER_30_MINUTES_MS = 30 * 60 * 1000L
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardAnsweringActions").apply { isDaemon = true }
        }
    }
}

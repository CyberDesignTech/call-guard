package com.wepr.callguard.call_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in RESTORE_ACTIONS) return
        val appContext = context.applicationContext
        val pendingResult = goAsync()
        worker.execute {
            try {
                CallReminderScheduler.restorePending(appContext, afterBoot = true)
            } catch (error: Exception) {
                Log.e(TAG, "Could not restore call reminders after ${intent.action}", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "BootCompletedReceiver"
        val RESTORE_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardBootRestore").apply { isDaemon = true }
        }
    }
}

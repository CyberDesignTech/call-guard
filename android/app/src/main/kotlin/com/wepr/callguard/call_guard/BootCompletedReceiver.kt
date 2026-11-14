package com.wepr.callguard.call_guard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val pendingResult = goAsync()
        worker.execute {
            try {
                CallReminderScheduler.restorePending(context)
            } catch (error: Exception) {
                Log.e(TAG, "Could not restore call reminders after reboot", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "BootCompletedReceiver"
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardBootRestore").apply { isDaemon = true }
        }
    }
}

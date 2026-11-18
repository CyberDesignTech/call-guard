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
                runCatching {
                    val settings = CallGuardDatabase.readSettings(appContext)
                    CallNotificationHelper.updateStatusIndicator(
                        context = appContext,
                        enabled = settings[DbContract.SettingKeys.STATUS_INDICATOR_ENABLED]
                            ?.toBooleanStrictOrNull() ?: true,
                        protectionEnabled = settings[DbContract.SettingKeys.PROTECTION_ENABLED]
                            ?.toBooleanStrictOrNull() ?: true,
                        drivingMode = settings[DbContract.SettingKeys.DRIVING_MODE]
                            ?.toBooleanStrictOrNull() ?: false,
                        locale = settings[DbContract.SettingKeys.LOCALE] ?: "english",
                    )
                }.onFailure {
                    Log.w(TAG, "Could not restore the CallGate status indicator", it)
                }
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

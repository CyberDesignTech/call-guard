package com.wepr.callguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/** Applies DND state when a configured quiet-schedule boundary is reached. */
class DndScheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != DndScheduleScheduler.ACTION_SYNC_SCHEDULE) return
        val appContext = context.applicationContext
        val pendingResult = goAsync()
        worker.execute {
            try {
                DndSyncController.syncWithActiveModes(appContext)
                val settings = CallGuardDatabase.readSettings(appContext)
                CallNotificationHelper.updateStatusIndicator(
                    context = appContext,
                    enabled = BootCompletedReceiver.hasCallScreeningRole(appContext) &&
                        settings[DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED]
                            ?.toBooleanStrictOrNull() != false,
                    protectionEnabled = settings[DbContract.SettingKeys.PROTECTION_ENABLED]
                        ?.toBooleanStrictOrNull() ?: true,
                    drivingMode = settings[DbContract.SettingKeys.DRIVING_MODE]
                        ?.toBooleanStrictOrNull() ?: false,
                    locale = settings[DbContract.SettingKeys.LOCALE] ?: "english",
                )
                CallGateWidgetProvider.requestUpdate(appContext)
            } catch (error: Exception) {
                Log.w(TAG, "Could not synchronize DND at the schedule boundary", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "CallGateDndSchedule"
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGateDndSchedule").apply { isDaemon = true }
        }
    }
}

package com.wepr.callguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.util.concurrent.Executors

/** Expires quick silence without starting Flutter. */
class QuickSilenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != QuickSilenceScheduler.ACTION_EXPIRE_QUICK_SILENCE) return
        val appContext = context.applicationContext
        val pendingResult = goAsync()
        worker.execute {
            try {
                val expired = CallGateModeStore.clearExpiredQuickSilence(
                    appContext,
                    System.currentTimeMillis(),
                )
                if (expired) {
                    DndSyncController.syncWithActiveModes(appContext)
                    CallGateModeStore.publish(appContext, CallGuardDatabase.readSettings(appContext))
                } else {
                    QuickSilenceScheduler.syncAlarm(
                        appContext,
                        CallGuardDatabase.readSettings(appContext),
                    )
                }
            } catch (error: Exception) {
                Log.e(TAG, "Could not expire quick silence", error)
            } finally {
                pendingResult.finish()
            }
        }
    }

    private companion object {
        const val TAG = "CallGateQuickSilence"
        val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGateQuickSilenceExpiry").apply { isDaemon = true }
        }
    }
}

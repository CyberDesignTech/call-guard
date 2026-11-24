package com.wepr.callguard

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** Persists and restores the one-hour quick-silence AlarmManager callback. */
internal object QuickSilenceScheduler {
    private const val REQUEST_CODE = 0x43475153

    fun syncAlarm(context: Context, settings: Map<String, String>) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = pendingIntent(context) ?: return
        val untilMillis = settings[DbContract.SettingKeys.QUICK_SILENCE_UNTIL]
            ?.toLongOrNull() ?: 0L
        if (untilMillis <= System.currentTimeMillis()) {
            manager.cancel(pendingIntent)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && manager.canScheduleExactAlarms()) {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, untilMillis, pendingIntent)
            } else {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, untilMillis, pendingIntent)
            }
        } catch (error: SecurityException) {
            runCatching {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, untilMillis, pendingIntent)
            }.onFailure { Log.w(TAG, "Could not schedule quick-silence expiry", it) }
        }
    }

    fun restoreAfterBoot(context: Context, settings: Map<String, String>) {
        syncAlarm(context, settings)
    }

    private fun pendingIntent(context: Context): PendingIntent? {
        val intent = Intent(context, QuickSilenceReceiver::class.java)
            .setAction(ACTION_EXPIRE_QUICK_SILENCE)
            .setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }

    internal const val ACTION_EXPIRE_QUICK_SILENCE =
        "com.wepr.callguard.action.EXPIRE_QUICK_SILENCE"
    private const val TAG = "CallGateQuickSilence"
}

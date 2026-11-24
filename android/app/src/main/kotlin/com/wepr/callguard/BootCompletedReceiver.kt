package com.wepr.callguard

import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.concurrent.Executors

/**
 * Restores alarms, DND synchronization, and the status notification after
 * boot, package replacement, clock changes, or timezone changes.
 */
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
                    DndSyncController.syncWithActiveModes(appContext)
                }.onFailure {
                    Log.w(TAG, "Could not restore DND synchronization", it)
                }
                runCatching {
                    val settings = CallGuardDatabase.readSettings(appContext)
                    val quickSilenceUntil = settings[
                        DbContract.SettingKeys.QUICK_SILENCE_UNTIL
                    ]?.toLongOrNull() ?: 0L
                    if (quickSilenceUntil in 1 until System.currentTimeMillis()) {
                        CallGateModeStore.clearExpiredQuickSilence(
                            appContext,
                            System.currentTimeMillis(),
                        )
                    }
                    QuickSilenceScheduler.restoreAfterBoot(appContext, settings)
                    val trayEnabled = hasCallScreeningRole(appContext) &&
                        settings[DbContract.SettingKeys.STATUS_TRAY_ICON_ENABLED]
                            ?.toBooleanStrictOrNull() != false
                    CallNotificationHelper.updateStatusIndicator(
                        context = appContext,
                        enabled = trayEnabled,
                        protectionEnabled = settings[DbContract.SettingKeys.PROTECTION_ENABLED]
                            ?.toBooleanStrictOrNull() ?: true,
                        drivingMode = settings[DbContract.SettingKeys.DRIVING_MODE]
                            ?.toBooleanStrictOrNull() ?: false,
                        locale = settings[DbContract.SettingKeys.LOCALE] ?: "english",
                    )
                }.onFailure {
                    Log.w(TAG, "Could not restore the CallGate status indicator", it)
                }
                CallGateWidgetProvider.requestUpdate(appContext)
                pendingResult.finish()
            }
        }
    }

    companion object {
        internal fun hasCallScreeningRole(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
            val roleManager = context.getSystemService(RoleManager::class.java) ?: return false
            return roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
                roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        }

        private const val TAG = "BootCompletedReceiver"
        private val RESTORE_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
        )
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardBootRestore").apply { isDaemon = true }
        }
    }
}

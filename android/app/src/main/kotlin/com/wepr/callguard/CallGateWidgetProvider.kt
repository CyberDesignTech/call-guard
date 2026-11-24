package com.wepr.callguard

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import android.widget.Toast
import android.text.format.DateFormat
import java.util.Date
import java.util.concurrent.Executors

/** Home-screen controls for CallGate, backed by the app's shared SQLite settings. */
class CallGateWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val settings = readSettings(context)
        appWidgetIds.forEach { manager.updateAppWidget(it, createViews(context, settings)) }
    }

    override fun onEnabled(context: Context) {
        requestUpdate(context)
    }

    override fun onDisabled(context: Context) {
        // Do not alter active modes or their alarm when the final widget is removed.
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = when (intent.action) {
            ACTION_TOGGLE_DRIVING -> CallGateWidgetAction.TOGGLE_DRIVING
            ACTION_TOGGLE_WHITELIST -> CallGateWidgetAction.TOGGLE_WHITELIST
            ACTION_TOGGLE_SCHEDULE -> CallGateWidgetAction.TOGGLE_SCHEDULE
            else -> null
        }
        if (action == null) {
            super.onReceive(context, intent)
        } else {
            handleAction(context.applicationContext, action)
        }
    }

    private fun handleAction(context: Context, action: CallGateWidgetAction) {
        val pendingResult = goAsync()
        try {
            worker.execute {
                try {
                    val (before, after) = CallGateModeStore.apply(context, action)
                    CallGateModeStore.publish(context, after)
                    DndSyncController.syncWithActiveModes(context)
                    maybeExplainMissingDndAccess(context, before, after)
                } catch (error: Exception) {
                    Log.e(TAG, "Could not apply widget action $action", error)
                    showToast(context, R.string.widget_action_failed)
                } finally {
                    pendingResult.finish()
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not queue widget action $action", error)
            pendingResult.finish()
        }
    }

    private fun maybeExplainMissingDndAccess(
        context: Context,
        before: Map<String, String>,
        after: Map<String, String>,
    ) {
        val now = System.currentTimeMillis()
        val wasModeActive = CallGateWidgetState.from(before, now).mode !=
            CallGateWidgetState.Mode.NORMAL
        val isModeActive = CallGateWidgetState.from(after, now).mode !=
            CallGateWidgetState.Mode.NORMAL
        val dndSyncEnabled = after[DbContract.SettingKeys.DND_SYNC_ENABLED]
            ?.toBooleanStrictOrNull() == true || after[DbContract.SettingKeys.MANUAL_MESSENGER_MUTE]
            ?.toBooleanStrictOrNull() == true
        if (!dndSyncEnabled ||
            (!wasModeActive && !isModeActive) || DndSyncController.hasPolicyAccess(context)
        ) return

        showToast(context, R.string.widget_dnd_permission_hint)
        if (!DndSyncController.openPolicyAccessSettings(context)) {
            runCatching {
                context.startActivity(
                    Intent(context, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                )
            }.onFailure { Log.w(TAG, "Could not open CallGate after missing DND access", it) }
        }
    }

    private fun showToast(context: Context, messageRes: Int) {
        mainHandler.post { Toast.makeText(context, messageRes, Toast.LENGTH_SHORT).show() }
    }

    private fun createViews(context: Context, settings: Map<String, String>): RemoteViews {
        val state = CallGateWidgetState.from(settings, System.currentTimeMillis())
        val views = RemoteViews(context.packageName, R.layout.widget_callgate_4x1)
        val status = when (state.mode) {
            CallGateWidgetState.Mode.DRIVING -> context.getString(R.string.widget_status_driving)
            CallGateWidgetState.Mode.QUICK_SILENCE -> state.quickSilenceUntilMillis?.let { until ->
                context.getString(
                    R.string.widget_status_quiet_until,
                    DateFormat.getTimeFormat(context).format(Date(until)),
                )
            } ?: context.getString(R.string.widget_status_quiet)
            CallGateWidgetState.Mode.WHITELIST ->
                context.getString(R.string.widget_status_whitelist)
            CallGateWidgetState.Mode.SCHEDULE ->
                context.getString(R.string.widget_status_schedule)
            CallGateWidgetState.Mode.NORMAL -> context.getString(R.string.widget_status_normal)
        }
        views.setTextViewText(R.id.widget_status_text, status)
        views.setTextViewText(
            R.id.widget_status_dot,
            context.getString(R.string.widget_status_dot),
        )
        val statusColor = when (state.mode) {
            CallGateWidgetState.Mode.DRIVING -> context.getColor(R.color.widget_drive_accent)
            CallGateWidgetState.Mode.QUICK_SILENCE -> context.getColor(R.color.widget_silence_accent)
            CallGateWidgetState.Mode.WHITELIST -> context.getColor(R.color.widget_whitelist_accent)
            CallGateWidgetState.Mode.SCHEDULE -> context.getColor(R.color.widget_schedule_accent)
            CallGateWidgetState.Mode.NORMAL -> context.getColor(R.color.widget_normal_accent)
        }
        views.setTextColor(R.id.widget_status_dot, statusColor)
        views.setOnClickPendingIntent(R.id.widget_status_area, openAppPendingIntent(context))

        setActionButton(
            context,
            views,
            R.id.widget_action_driving,
            R.id.widget_icon_driving,
            R.id.widget_label_driving,
            R.drawable.ic_widget_drive,
            R.string.widget_action_driving,
            state.drivingMode,
            R.drawable.widget_button_driving_active,
            ACTION_TOGGLE_DRIVING,
            REQUEST_DRIVING,
        )
        setActionButton(
            context,
            views,
            R.id.widget_action_whitelist,
            R.id.widget_icon_whitelist,
            R.id.widget_label_whitelist,
            R.drawable.ic_widget_whitelist,
            R.string.widget_action_whitelist,
            state.whitelistOnly,
            R.drawable.widget_button_whitelist_active,
            ACTION_TOGGLE_WHITELIST,
            REQUEST_WHITELIST,
        )
        setActionButton(
            context,
            views,
            R.id.widget_action_schedule,
            R.id.widget_icon_schedule,
            R.id.widget_label_schedule,
            R.drawable.ic_widget_schedule,
            R.string.widget_action_schedule,
            state.automaticSilence,
            R.drawable.widget_button_active,
            ACTION_TOGGLE_SCHEDULE,
            REQUEST_SCHEDULE,
        )
        return views
    }

    private fun setActionButton(
        context: Context,
        views: RemoteViews,
        buttonId: Int,
        iconId: Int,
        labelId: Int,
        iconRes: Int,
        labelRes: Int,
        selected: Boolean,
        selectedBackgroundRes: Int,
        action: String,
        requestCode: Int,
    ) {
        views.setImageViewResource(iconId, iconRes)
        views.setTextViewText(labelId, context.getString(labelRes))
        views.setInt(
            buttonId,
            "setBackgroundResource",
            if (selected) selectedBackgroundRes else R.drawable.widget_button_idle,
        )
        val foreground = context.getColor(
            if (selected) R.color.widget_text_active else R.color.widget_text_idle,
        )
        views.setInt(iconId, "setColorFilter", foreground)
        views.setTextColor(labelId, foreground)
        views.setContentDescription(
            buttonId,
            context.getString(
                if (selected) R.string.widget_mode_on else R.string.widget_mode_off,
                context.getString(labelRes),
            ),
        )
        val intent = Intent(context, CallGateWidgetProvider::class.java)
            .setAction(action)
            .setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        val pendingIntent = PendingIntent.getBroadcast(context, requestCode, intent, flags)
        views.setOnClickPendingIntent(buttonId, pendingIntent)
    }

    private fun openAppPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
        return PendingIntent.getActivity(context, REQUEST_OPEN_APP, intent, flags)
    }

    companion object {
        const val ACTION_TOGGLE_DRIVING = "com.wepr.callguard.widget.TOGGLE_DRIVING"
        const val ACTION_TOGGLE_WHITELIST = "com.wepr.callguard.widget.TOGGLE_WHITELIST"
        const val ACTION_TOGGLE_SCHEDULE = "com.wepr.callguard.widget.TOGGLE_SCHEDULE"

        private const val REQUEST_OPEN_APP = 0x43475700
        private const val REQUEST_DRIVING = 0x43475702
        private const val REQUEST_WHITELIST = 0x43475703
        private const val REQUEST_SCHEDULE = 0x43475704
        private const val TAG = "CallGateWidget"
        private val mainHandler = Handler(Looper.getMainLooper())
        private val worker = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGateWidgetActions").apply { isDaemon = true }
        }

        /** Immediately renders all placed widget instances from current shared settings. */
        @JvmStatic
        fun requestUpdate(context: Context) {
            runCatching {
                val appContext = context.applicationContext
                val manager = AppWidgetManager.getInstance(appContext)
                val component = ComponentName(appContext, CallGateWidgetProvider::class.java)
                val ids = manager.getAppWidgetIds(component)
                if (ids.isEmpty()) return
                val settings = readSettings(appContext)
                val views = CallGateWidgetProvider().createViews(appContext, settings)
                manager.updateAppWidget(ids, views)
            }.onFailure { Log.w(TAG, "Could not update CallGate home-screen widget", it) }
        }

        private fun readSettings(context: Context): Map<String, String> = runCatching {
            CallGuardDatabase.readSettings(context)
        }.onFailure { Log.w(TAG, "Could not read widget settings", it) }
            .getOrDefault(emptyMap())
    }
}

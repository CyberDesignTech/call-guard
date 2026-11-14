package com.wepr.callguard.call_guard

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.util.Locale

object CallNotificationHelper {
    const val REMINDER_CHANNEL_ID = "call_guard_reminders_v2"
    const val MISSED_CALL_CHANNEL_ID = "call_guard_missed_calls_v3"
    const val QUIET_MISSED_CALL_CHANNEL_ID = "call_guard_missed_calls_quiet_v1"

    fun showReminder(context: Context, reminder: CallReminderRecord): Boolean {
        val localizedContext = localizedContext(context)
        createChannel(
            context,
            localizedContext.getString(R.string.call_reminder_channel_name),
            localizedContext.getString(R.string.call_reminder_channel_description),
            REMINDER_CHANNEL_ID,
        )
        if (!canPostNotifications(context) || !isChannelEnabled(context, REMINDER_CHANNEL_ID)) {
            return false
        }

        val dialIntent = dialIntent(context, reminder.phone)
        val dialPendingIntent = PendingIntent.getActivity(
            context,
            reminder.id,
            dialIntent,
            pendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT),
        )
        val doneIntent = Intent(context, CallReminderReceiver::class.java)
            .setAction(CallReminderScheduler.ACTION_MARK_REMINDER_DONE)
            .putExtra(CallReminderScheduler.EXTRA_REMINDER_ID, reminder.id)
        val donePendingIntent = PendingIntent.getBroadcast(
            context,
            reminder.id,
            doneIntent,
            pendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT),
        )

        val title = localizedDatabaseText(localizedContext, reminder.contactName)
            ?: localizedContext.getString(R.string.call_reminder_title)
        val body = buildString {
            append(reminder.phone)
            localizedDatabaseText(localizedContext, reminder.note)?.let {
                append('\n')
                append(it)
            }
        }
        val notification = notificationBuilder(
            localizedContext,
            REMINDER_CHANNEL_ID,
        )
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setDefaults(Notification.DEFAULT_ALL)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(dialPendingIntent)
            .addAction(
                android.R.drawable.ic_menu_call,
                localizedContext.getString(R.string.call_reminder_action_call),
                dialPendingIntent,
            )
            .addAction(
                android.R.drawable.checkbox_on_background,
                localizedContext.getString(R.string.call_reminder_action_done),
                donePendingIntent,
            )
            .build()

        return notify(context, reminder.id, notification)
    }

    fun showMissedCall(
        context: Context,
        phone: String,
        quietMode: Boolean = false,
    ): Boolean {
        val localizedContext = localizedContext(context)
        val hiddenNumber = isHiddenPhone(phone)
        val channelId = if (quietMode) QUIET_MISSED_CALL_CHANNEL_ID else MISSED_CALL_CHANNEL_ID
        createChannel(
            context,
            localizedContext.getString(R.string.missed_call_channel_name),
            localizedContext.getString(R.string.missed_call_channel_description),
            channelId,
            importance = if (quietMode) {
                NotificationManager.IMPORTANCE_LOW
            } else {
                NotificationManager.IMPORTANCE_HIGH
            },
            lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE,
            silent = quietMode,
        )
        if (!canPostNotifications(context) || !isChannelEnabled(context, channelId)) {
            return false
        }

        val notificationId = ANSWERING_NOTIFICATION_ID_BASE + phone.hashCode()
        val contentPendingIntent = if (hiddenNumber) {
            PendingIntent.getActivity(
                context,
                notificationId,
                Intent(context, MainActivity::class.java)
                    .putExtra(BridgeContract.Extras.OPEN_CALL_JOURNAL, true)
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    ),
                pendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT),
            )
        } else {
            PendingIntent.getActivity(
                context,
                notificationId,
                dialIntent(context, phone),
                pendingIntentFlags(PendingIntent.FLAG_UPDATE_CURRENT),
            )
        }
        val publicNotification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentTitle(localizedContext.getString(R.string.missed_call_public_title))
            .setContentText(localizedContext.getString(R.string.missed_call_public_text))
            .setCategory(Notification.CATEGORY_CALL)
            .build()
        val builder = NotificationCompat.Builder(localizedContext, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setDefaults(if (quietMode) 0 else Notification.DEFAULT_ALL)
            .setSilent(quietMode)
            .setContentTitle(
                localizedContext.getString(
                    if (hiddenNumber) R.string.missed_call_hidden_title
                    else R.string.missed_call_title,
                ),
            )
            .setContentText(
                if (hiddenNumber) {
                    localizedContext.getString(R.string.missed_call_hidden_text)
                } else {
                    phone
                },
            )
            .setCategory(Notification.CATEGORY_CALL)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .setPublicVersion(publicNotification)
        if (!hiddenNumber) {
            builder.addAction(
                android.R.drawable.ic_menu_call,
                localizedContext.getString(R.string.missed_call_action_dial),
                contentPendingIntent,
            )
        }
        return notify(context, notificationId, builder.build())
    }

    private fun dialIntent(context: Context, phone: String): Intent =
        Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(phone)}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    private fun isHiddenPhone(phone: String): Boolean =
        PhoneNumbers.isHidden(phone) ||
            phone.equals(PhoneNumbers.HIDDEN_NUMBER, ignoreCase = true)

    private fun localizedDatabaseText(context: Context, value: String?): String? {
        if (value.isNullOrBlank()) return null
        if (!value.startsWith('@')) return value
        return when (value.removePrefix("@")) {
            "reminderOlena" -> context.getString(R.string.reminder_contact_olena)
            "reminderUnknown" -> context.getString(R.string.reminder_contact_unknown)
            "reminderNew" -> context.getString(R.string.reminder_contact_new)
            "reminderNoteMeeting" -> context.getString(R.string.reminder_note_meeting)
            "reminderNoteCheck" -> context.getString(R.string.reminder_note_check)
            "reminderNewNote" -> context.getString(R.string.reminder_note_new)
            else -> value.removePrefix("@")
        }
    }

    private fun notificationBuilder(context: Context, channelId: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }

    private fun createChannel(
        context: Context,
        name: String,
        description: String,
        channelId: String,
        importance: Int = NotificationManager.IMPORTANCE_HIGH,
        lockscreenVisibility: Int = Notification.VISIBILITY_PUBLIC,
        silent: Boolean = false,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            channelId,
            name,
            importance,
        ).apply {
            this.description = description
            this.lockscreenVisibility = lockscreenVisibility
            enableVibration(!silent)
            if (silent) {
                setSound(null, null)
            } else {
                vibrationPattern = longArrayOf(0L, 250L, 150L, 250L)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            }
        }
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
            ?.createNotificationChannel(channel)
    }

    private fun canPostNotifications(context: Context): Boolean =
        NotificationManagerCompat.from(context).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 ||
                context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED)

    private fun isChannelEnabled(context: Context, channelId: String): Boolean =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            true
        } else {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.getNotificationChannel(channelId)?.let {
                it.importance != NotificationManager.IMPORTANCE_NONE
            } ?: false
        }

    private fun notify(context: Context, notificationId: Int, notification: Notification): Boolean =
        runCatching {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)
                ?.notify(notificationId, notification)
                ?: return false
            true
        }.onFailure { Log.w(TAG, "Could not show a local call notification", it) }
            .getOrDefault(false)

    private fun pendingIntentFlags(extra: Int): Int =
        extra or if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

    private fun localizedContext(context: Context): Context {
        val setting = runCatching {
            CallReminderStore.getSetting(context, DbContract.SettingKeys.LOCALE, "english")
        }.getOrDefault("english")
        val language = when (setting) {
            "ukrainian" -> "uk"
            "polish" -> "pl"
            "german" -> "de"
            "spanish" -> "es"
            "french" -> "fr"
            else -> "en"
        }
        val configuration = Configuration(context.resources.configuration)
        configuration.setLocale(Locale.forLanguageTag(language))
        return context.createConfigurationContext(configuration)
    }

    private const val TAG = "CallGuardNotifications"
    private const val ANSWERING_NOTIFICATION_ID_BASE = 0x43470000
}

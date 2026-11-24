package com.wepr.callguard

import java.util.Calendar

/** Resolves the four persistent status-notification states and their resources. */
internal object StatusNotificationHelper {
    fun modeFor(
        protectionEnabled: Boolean,
        drivingMode: Boolean,
        silenceMode: Boolean,
    ): StatusNotificationMode = when {
        !protectionEnabled -> StatusNotificationMode.PAUSED
        drivingMode -> StatusNotificationMode.DRIVING
        silenceMode -> StatusNotificationMode.SILENCE
        else -> StatusNotificationMode.ACTIVE
    }

    fun iconFor(mode: StatusNotificationMode): Int = when (mode) {
        StatusNotificationMode.PAUSED -> R.drawable.ic_stat_shield_paused
        StatusNotificationMode.DRIVING -> R.drawable.ic_stat_shield_driving
        StatusNotificationMode.SILENCE -> R.drawable.ic_stat_shield_silence
        StatusNotificationMode.ACTIVE -> R.drawable.ic_stat_shield_active
    }

    fun titleFor(mode: StatusNotificationMode, messengerMute: Boolean): Int = when (mode) {
        StatusNotificationMode.PAUSED -> R.string.status_paused_title
        StatusNotificationMode.DRIVING -> R.string.status_driving_title
        StatusNotificationMode.SILENCE -> if (messengerMute) {
            R.string.status_messenger_mute_title
        } else {
            R.string.status_silence_title
        }
        StatusNotificationMode.ACTIVE -> R.string.status_active_title
    }

    fun textFor(
        mode: StatusNotificationMode,
        quietMode: Boolean,
        messengerMute: Boolean,
    ): Int = when (mode) {
        StatusNotificationMode.PAUSED -> R.string.status_paused_text
        StatusNotificationMode.DRIVING -> R.string.status_driving_text
        StatusNotificationMode.SILENCE -> when {
            quietMode && messengerMute -> R.string.status_silence_messenger_text
            messengerMute -> R.string.status_messenger_mute_text
            else -> R.string.status_silence_text
        }
        StatusNotificationMode.ACTIVE -> R.string.status_active_text
    }

    fun quietModeActive(settings: Map<String, String>, now: Calendar): Boolean =
        settings.booleanSetting(DbContract.SettingKeys.MANUAL_SILENCE_ENABLED) ||
            settings.booleanSetting(DbContract.SettingKeys.MANUAL_SILENCE) ||
            settings.booleanSetting(DbContract.SettingKeys.SILENCE_MANUAL) ||
            CallGateWidgetState.quickSilenceActive(settings, now.timeInMillis) ||
            settings.booleanSetting(DbContract.SettingKeys.AUTOMATIC_SILENCE) &&
            QuietSchedulePolicy.isWithin(settings, now)

    fun messengerMuteEnabled(settings: Map<String, String>): Boolean =
        settings.booleanSetting(DbContract.SettingKeys.MANUAL_MESSENGER_MUTE)

    private fun Map<String, String>.booleanSetting(key: String): Boolean =
        this[key]?.toBooleanStrictOrNull() == true
}

internal enum class StatusNotificationMode {
    PAUSED,
    DRIVING,
    SILENCE,
    ACTIVE,
}

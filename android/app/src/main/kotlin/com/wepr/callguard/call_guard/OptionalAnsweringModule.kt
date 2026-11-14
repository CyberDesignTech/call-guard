package com.wepr.callguard.call_guard

import android.content.Context
import android.util.Log

/** Optional, removable call-back helper; it never answers calls or sends messages. */
object OptionalAnsweringModule {
    /**
     * Optional scenario rule, limited to default-allowed calls so explicit allow rules win.
     *
     * @param settings snapshot from [CallGuardDatabase.readSettings] for the current call;
     * null falls back to a single fresh read.
     */
    fun shouldRejectUnknownCall(
        context: Context,
        phoneNumber: String,
        ruleVerdict: CallRuleVerdict,
        settings: Map<String, String>?,
    ): Boolean {
        if (!ruleVerdict.allowed || ruleVerdict.reason != "default_allow") return false
        val snapshot = settingsOrLoad(context, settings)
        if (!isEnabledForScenario(snapshot, SCENARIO_UNKNOWN_NUMBERS)) return false
        return isUnknownNumber(context, phoneNumber)
    }

    /** Returns true when this rejected call matches the selected callback scenario. */
    fun handleRejectedCall(
        context: Context,
        phoneNumber: String,
        ruleReason: String,
        settings: Map<String, String>?,
    ): Boolean {
        val snapshot = settingsOrLoad(context, settings)
        val scenario = snapshot[DbContract.SettingKeys.ANSWERING_SCENARIO] ?: SCENARIO_SILENCE
        if (!isEnabled(snapshot)) return false
        val applies = when (scenario) {
            SCENARIO_SILENCE -> ruleReason == "silent_schedule"
            SCENARIO_UNKNOWN_NUMBERS -> isUnknownNumber(context, phoneNumber)
            else -> false
        }
        if (!applies) return false

        if (isAutoReminderEnabled(snapshot) && !isHiddenNumber(phoneNumber)) {
            val reminderMinutes = autoReminderMinutes(snapshot)
            val remindAt = System.currentTimeMillis() + reminderMinutes * MILLIS_PER_MINUTE
            runCatching {
                CallReminderStore.insertReminderIfNotRecentlyCreated(
                    context = context,
                    phone = phoneNumber,
                    remindAt = remindAt,
                    note = REMINDER_NOTE_KEY,
                )?.let { reminderId ->
                    CallReminderScheduler.schedule(context, reminderId, remindAt)
                }
            }.onFailure {
                Log.e(TAG, "Could not create the automatic callback reminder", it)
            }
        }

        val showNotification = (
            snapshot[DbContract.SettingKeys.ANSWERING_LOCAL_NOTIFICATION] ?: "true"
            ).equals("true", ignoreCase = true)
        if (showNotification) {
            runCatching {
                CallNotificationHelper.showMissedCall(
                    context,
                    phoneNumber,
                    quietMode = ruleReason == "silent_schedule",
                )
            }.onFailure {
                Log.e(TAG, "Could not notify about the rejected call", it)
            }
        }
        return true
    }

    private fun settingsOrLoad(
        context: Context,
        settings: Map<String, String>?,
    ): Map<String, String> = settings ?: runCatching {
        CallGuardDatabase.readSettings(context)
    }.getOrElse {
        Log.w(TAG, "Could not read answering-module settings", it)
        emptyMap()
    }

    private fun isEnabledForScenario(settings: Map<String, String>, scenario: String): Boolean =
        isEnabled(settings) &&
            settings[DbContract.SettingKeys.ANSWERING_SCENARIO] == scenario

    private fun isEnabled(settings: Map<String, String>): Boolean =
        (settings[DbContract.SettingKeys.ANSWERING_ENABLED] ?: "false")
            .equals("true", ignoreCase = true)

    private fun isUnknownNumber(context: Context, phoneNumber: String): Boolean {
        if (isHiddenNumber(phoneNumber)) return true
        if (!ContactLookup.hasPermission(context)) return false
        return ContactLookup.isUnknownNumber(
            context,
            PhoneNumbers.normalize(phoneNumber.trim()),
        )
    }

    private fun isHiddenMarker(phoneNumber: String): Boolean =
        phoneNumber.equals(PhoneNumbers.HIDDEN_NUMBER, ignoreCase = true)

    private fun isHiddenNumber(phoneNumber: String): Boolean =
        PhoneNumbers.isHidden(phoneNumber) || isHiddenMarker(phoneNumber)

    private fun isAutoReminderEnabled(settings: Map<String, String>): Boolean =
        settings[DbContract.SettingKeys.ANSWERING_AUTO_REMIND]
            ?.toBooleanStrictOrNull() ?: false

    private fun autoReminderMinutes(settings: Map<String, String>): Long =
        settings[DbContract.SettingKeys.ANSWERING_AUTO_REMIND_MINUTES]
            ?.toIntOrNull()
            ?.takeIf { it in AUTO_REMINDER_MINUTES }
            ?.toLong()
            ?: DEFAULT_AUTO_REMINDER_MINUTES

    private const val TAG = "OptionalAnsweringModule"
    private const val REMINDER_NOTE_KEY = "@reminderNewNote"
    private const val DEFAULT_AUTO_REMINDER_MINUTES = 30L
    private const val MILLIS_PER_MINUTE = 60_000L
    private val AUTO_REMINDER_MINUTES = setOf(15, 30, 60)
    const val SCENARIO_SILENCE = "quiet_mode"
    const val SCENARIO_UNKNOWN_NUMBERS = "unknown_numbers"
}

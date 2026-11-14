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

    /** Returns true when this rejected call was handled by the optional module. */
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

        return try {
            CallReminderStore.insertCallLog(context, phoneNumber, ANSWERING_REASON)
            val showNotification = (
                snapshot[DbContract.SettingKeys.ANSWERING_LOCAL_NOTIFICATION] ?: "true"
                ).equals("true", ignoreCase = true)
            if (showNotification) CallNotificationHelper.showMissedCall(context, phoneNumber)
            true
        } catch (error: Exception) {
            Log.e(TAG, "Could not handle rejected call in the optional module", error)
            false
        }
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
        if (PhoneNumbers.isHidden(phoneNumber)) return true
        if (!ContactLookup.hasPermission(context)) return false
        return ContactLookup.isUnknownNumber(
            context,
            PhoneNumbers.normalize(phoneNumber.trim()),
        )
    }

    private const val TAG = "OptionalAnsweringModule"
    private const val ANSWERING_REASON = "answering_machine"
    const val SCENARIO_SILENCE = "quiet_mode"
    const val SCENARIO_UNKNOWN_NUMBERS = "unknown_numbers"
}

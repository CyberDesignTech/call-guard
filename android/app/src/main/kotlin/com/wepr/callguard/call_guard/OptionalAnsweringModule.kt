package com.wepr.callguard.call_guard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telephony.PhoneNumberUtils
import android.util.Log

/** Optional, removable call-back helper; it never answers calls or sends messages. */
object OptionalAnsweringModule {
    /** Optional scenario rule, limited to default-allowed calls so explicit allow rules win. */
    fun shouldRejectUnknownCall(
        context: Context,
        phoneNumber: String,
        ruleVerdict: CallRuleVerdict,
    ): Boolean {
        if (!ruleVerdict.allowed || ruleVerdict.reason != "default_allow") return false
        if (!isEnabledForScenario(context, SCENARIO_UNKNOWN_NUMBERS)) return false
        return isUnknownNumber(context, phoneNumber)
    }

    /** Returns true when this rejected call was handled by the optional module. */
    fun handleRejectedCall(context: Context, phoneNumber: String, ruleReason: String): Boolean {
        val scenario = runCatching {
            CallReminderStore.getSetting(context, "answering_scenario", SCENARIO_SILENCE)
        }.getOrDefault(SCENARIO_SILENCE)
        val enabled = isEnabled(context)
        if (!enabled) return false
        val applies = when (scenario) {
            SCENARIO_SILENCE -> ruleReason == "silent_schedule"
            SCENARIO_UNKNOWN_NUMBERS -> isUnknownNumber(context, phoneNumber)
            else -> false
        }
        if (!applies) return false

        return try {
            CallReminderStore.insertCallLog(context, phoneNumber, ANSWERING_REASON)
            val showNotification = CallReminderStore.getSetting(
                context,
                "answering_local_notification",
                "true",
            ).equals("true", ignoreCase = true)
            if (showNotification) CallNotificationHelper.showMissedCall(context, phoneNumber)
            true
        } catch (error: Exception) {
            Log.e(TAG, "Could not handle rejected call in the optional module", error)
            false
        }
    }

    private fun isEnabledForScenario(context: Context, scenario: String): Boolean =
        isEnabled(context) && runCatching {
            CallReminderStore.getSetting(context, "answering_scenario", SCENARIO_SILENCE) == scenario
        }.getOrDefault(false)

    private fun isEnabled(context: Context): Boolean = runCatching {
        CallReminderStore.getSetting(context, "answering_enabled", "false")
            .equals("true", ignoreCase = true)
    }.onFailure { Log.w(TAG, "Could not read answering-module settings", it) }
        .getOrDefault(false)

    private fun isUnknownNumber(context: Context, phoneNumber: String): Boolean {
        val normalized = phoneNumber.trim()
        if (normalized.isBlank() || normalized.uppercase() in HIDDEN_NUMBER_MARKERS) return true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            context.checkSelfPermission(Manifest.permission.READ_CONTACTS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }

        val lookupNumber = PhoneNumberUtils.normalizeNumber(normalized)
        val lookupUri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(lookupNumber),
        )
        return runCatching {
            context.contentResolver.query(
                lookupUri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null,
                null,
                null,
            )?.use { !it.moveToFirst() } ?: false
        }.onFailure { Log.w(TAG, "Could not check whether caller is a contact", it) }
            .getOrDefault(false)
    }

    private const val TAG = "OptionalAnsweringModule"
    private const val ANSWERING_REASON = "answering_machine"
    const val SCENARIO_SILENCE = "quiet_mode"
    const val SCENARIO_UNKNOWN_NUMBERS = "unknown_numbers"
    private val HIDDEN_NUMBER_MARKERS = setOf(
        "UNKNOWN",
        "PRIVATE",
        "PRESENTATION_RESTRICTED",
        "RESTRICTED",
        "UNAVAILABLE",
    )
}

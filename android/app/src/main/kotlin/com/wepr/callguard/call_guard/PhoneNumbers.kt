package com.wepr.callguard.call_guard

import android.content.Context
import android.os.Build
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager
import java.util.Locale

/** Shared phone-number normalization used by call screening and the answering module. */
object PhoneNumbers {
    const val HIDDEN_NUMBER = "@numberHidden"

    private val hiddenNumberMarkers = setOf(
        "UNKNOWN",
        "PRIVATE",
        "PRESENTATION_RESTRICTED",
        "RESTRICTED",
        "UNAVAILABLE",
    )

    fun normalize(phone: String): String = PhoneNumberUtils.normalizeNumber(phone)

    fun digits(value: String): String =
        normalize(value).filter { it in '0'..'9' }

    fun isHidden(phone: String): Boolean {
        val value = phone.trim().uppercase(Locale.ROOT)
        return value.isEmpty() || value in hiddenNumberMarkers
    }

    fun canonicalize(context: Context, phone: String): String {
        val normalized = normalize(phone)
        val phoneDigits = digits(normalized)
        if (phoneDigits.isEmpty()) return ""
        val trimmed = phone.trim()
        if (trimmed.startsWith("+") || phoneDigits.startsWith("00")) {
            return "+${if (phoneDigits.startsWith("00")) phoneDigits.drop(2) else phoneDigits}"
        }

        val region = homeCountryIso(context) ?: return phoneDigits
        return runCatching {
            PhoneNumberUtils.formatNumberToE164(phone, region)
        }.getOrNull()?.takeIf(String::isNotBlank) ?: phoneDigits
    }

    fun logValue(rawPhone: String, canonicalPhone: String): String =
        if (isHidden(rawPhone)) HIDDEN_NUMBER else canonicalPhone.ifBlank { rawPhone }

    fun compare(context: Context, first: String, second: String): Boolean =
        runCatching {
            PhoneNumberUtils.compare(context, first, second)
        }.getOrDefault(false)

    fun homeCountryIso(context: Context): String? {
        val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val networkIso = runCatching { telephony?.networkCountryIso }
            .getOrNull()
            ?.takeIf(String::isNotBlank)
        if (networkIso != null) return networkIso.uppercase(Locale.ROOT)
        val configuration = context.applicationContext.resources.configuration
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            configuration.locale
        }
        return locale.country.takeIf(String::isNotBlank)?.uppercase(Locale.ROOT)
    }
}

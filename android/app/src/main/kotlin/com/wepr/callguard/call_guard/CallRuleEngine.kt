package com.wepr.callguard.call_guard

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import java.util.Calendar
import java.util.Locale

data class CallRuleVerdict(
    val allowed: Boolean,
    val reason: String,
    val phoneNumber: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        BridgeContract.ResultKeys.VERDICT to
            if (allowed) BridgeContract.Verdicts.ALLOW else BridgeContract.Verdicts.REJECT,
        BridgeContract.ResultKeys.REASON to reason,
        BridgeContract.ResultKeys.PHONE_NUMBER to phoneNumber,
    )
}

/** Reads the same SQLite file and setting keys used by Flutter's sqflite layer. */
class CallRuleEngine(context: Context) {
    private val appContext = context.applicationContext

    fun evaluate(phoneNumber: String?): CallRuleVerdict =
        evaluate(phoneNumber, settings = null)

    /**
     * @param settings optional snapshot from [CallGuardDatabase.readSettings] so a single
     * call-screening pass can share one read of app_settings.
     */
    fun evaluate(
        phoneNumber: String?,
        settings: Map<String, String>?,
    ): CallRuleVerdict {
        val rawPhone = phoneNumber.orEmpty().trim()
        return try {
            val snapshot = settings ?: CallGuardDatabase.readSettings(appContext)
            CallGuardDatabase.withDatabase(appContext) { database ->
                evaluate(database, rawPhone, snapshot)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not evaluate call rules; allowing the call", error)
            verdict(allowed = true, reason = "database_unavailable", rawPhone)
        }
    }

    fun recordCallLog(phoneNumber: String, reason: String, contactName: String? = null) {
        try {
            CallGuardDatabase.withDatabase(appContext) { database ->
                val values = ContentValues().apply {
                    put(DbContract.CallLogs.PHONE, phoneNumber.ifBlank { PhoneNumbers.HIDDEN_NUMBER })
                    put(DbContract.CallLogs.CONTACT_NAME, contactName)
                    put(DbContract.CallLogs.REASON, reason)
                    put(DbContract.CallLogs.TIMESTAMP, System.currentTimeMillis())
                }
                database.insertOrThrow(DbContract.CallLogs.TABLE, null, values)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Could not persist blocked-call log", error)
        }
    }

    private fun evaluate(
        database: SQLiteDatabase,
        rawPhone: String,
        settings: Map<String, String>,
    ): CallRuleVerdict {
        purgeExpiredPhoneRules(database)
        if (!settings.bool(DbContract.SettingKeys.PROTECTION_ENABLED, true)) {
            return verdict(true, "protection_disabled", rawPhone)
        }

        val hidden = PhoneNumbers.isHidden(rawPhone)
        val canonicalPhone = if (hidden) "" else PhoneNumbers.canonicalize(appContext, rawPhone)

        if (!hidden && matchesPhoneRule(database, "white", rawPhone, canonicalPhone)) {
            return verdict(true, "allowlist", canonicalPhone)
        }

        val calendar = Calendar.getInstance()
        val silenceActive = settings.bool(DbContract.SettingKeys.MANUAL_SILENCE_ENABLED, false) ||
            settings.bool(DbContract.SettingKeys.MANUAL_SILENCE, false) ||
            settings.bool(DbContract.SettingKeys.SILENCE_MANUAL, false) ||
            (
                settings.bool(DbContract.SettingKeys.AUTOMATIC_SILENCE, false) &&
                    isWithinQuietSchedule(settings, calendar)
            )
        if (silenceActive) {
            val emergencyRepeatEnabled = settings.bool(
                DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT,
                false,
            ) && settings.bool(DbContract.SettingKeys.ANSWERING_ENABLED, false)
            if (emergencyRepeatEnabled && !hidden && canonicalPhone.isNotBlank() &&
                !isExplicitlyBlocked(database, rawPhone, canonicalPhone, settings) &&
                hasRecentRejectedSilenceCalls(database, canonicalPhone)
            ) {
                return verdict(true, "emergency_repeat", canonicalPhone)
            }
            return verdict(false, "silent_schedule", PhoneNumbers.logValue(rawPhone, canonicalPhone))
        }

        if (hidden && settings.bool(DbContract.SettingKeys.BLOCK_HIDDEN, true)) {
            return verdict(false, "hidden_number", PhoneNumbers.HIDDEN_NUMBER)
        }

        if (settings.bool(DbContract.SettingKeys.BLOCK_NON_CONTACTS, false) &&
            ContactLookup.hasPermission(appContext) &&
            !ContactLookup.isInContacts(appContext, canonicalPhone.ifBlank { rawPhone })
        ) {
            return verdict(false, "not_in_contacts", PhoneNumbers.logValue(rawPhone, canonicalPhone))
        }

        val countries = readCountries(database)
        val phoneDigits = PhoneNumbers.digits(canonicalPhone)
        val matchedCountry = countries
            .filter { it.dialDigits.isNotEmpty() && phoneDigits.startsWith(it.dialDigits) }
            .maxByOrNull { it.dialDigits.length }

        if (matchedCountry != null) {
            val nationalDigits = phoneDigits.drop(matchedCountry.dialDigits.length)
            val operatorAction = findOperatorAction(
                database,
                matchedCountry.isoCode,
                nationalDigits,
            )
            if (operatorAction == ACTION_BLOCK) {
                return verdict(false, "operator_block", canonicalPhone)
            }
            if (operatorAction == ACTION_ALLOW) {
                return verdict(true, "operator_allow", canonicalPhone)
            }

            when (matchedCountry.action) {
                ACTION_BLOCK -> return verdict(false, "country_block", canonicalPhone)
                ACTION_ALLOW -> return verdict(true, "country_allow", canonicalPhone)
            }
        }

        if (settings.bool(DbContract.SettingKeys.BLOCK_INTERNATIONAL, false) &&
            isInternational(rawPhone, canonicalPhone, matchedCountry, countries)
        ) {
            return verdict(
                false,
                "international_block",
                PhoneNumbers.logValue(rawPhone, canonicalPhone),
            )
        }

        if (!hidden && matchesPhoneRule(database, "black", rawPhone, canonicalPhone)) {
            return verdict(false, "blacklist", canonicalPhone)
        }

        if (settings.bool(DbContract.SettingKeys.ALLOW_ONLY_WHITELIST, false)) {
            return verdict(false, "allowlist_only", canonicalPhone.ifBlank { rawPhone })
        }

        return verdict(true, "default_allow", canonicalPhone.ifBlank { rawPhone })
    }

    private fun readCountries(database: SQLiteDatabase): List<CountryRule> {
        val countries = ArrayList<CountryRule>()
        database.rawQuery(
            "SELECT ${DbContract.CountryRules.ISO_CODE}, ${DbContract.CountryRules.DIAL_CODE}, " +
                "${DbContract.CountryRules.ACTION} FROM ${DbContract.CountryRules.TABLE}",
            null,
        ).use { cursor ->
            val isoColumn = cursor.getColumnIndexOrThrow(DbContract.CountryRules.ISO_CODE)
            val dialColumn = cursor.getColumnIndexOrThrow(DbContract.CountryRules.DIAL_CODE)
            val actionColumn = cursor.getColumnIndexOrThrow(DbContract.CountryRules.ACTION)
            while (cursor.moveToNext()) {
                countries.add(
                    CountryRule(
                        isoCode = cursor.getString(isoColumn),
                        dialDigits = PhoneNumbers.digits(cursor.getString(dialColumn)),
                        action = cursor.getString(actionColumn).lowercase(Locale.ROOT),
                    ),
                )
            }
        }
        return countries
    }

    private fun findOperatorAction(
        database: SQLiteDatabase,
        countryIso: String,
        nationalDigits: String,
    ): String? {
        if (nationalDigits.isEmpty()) return null
        val matching = ArrayList<Pair<String, String>>()
        database.rawQuery(
            "SELECT ${DbContract.OperatorRules.PREFIXES}, ${DbContract.OperatorRules.ACTION} " +
                "FROM ${DbContract.OperatorRules.TABLE} " +
                "WHERE ${DbContract.OperatorRules.COUNTRY_ISO} = ? " +
                "ORDER BY ${DbContract.OperatorRules.ID}",
            arrayOf(countryIso),
        ).use { cursor ->
            val prefixesColumn = cursor.getColumnIndexOrThrow(DbContract.OperatorRules.PREFIXES)
            val actionColumn = cursor.getColumnIndexOrThrow(DbContract.OperatorRules.ACTION)
            while (cursor.moveToNext()) {
                val action = cursor.getString(actionColumn).lowercase(Locale.ROOT)
                cursor.getString(prefixesColumn)
                    .split(',')
                    .map(PhoneNumbers::digits)
                    .filter { it.isNotEmpty() && nationalDigits.startsWith(it) }
                    .forEach { matching.add(it to action) }
            }
        }
        return matching.maxByOrNull { it.first.length }?.second
    }

    private fun matchesPhoneRule(
        database: SQLiteDatabase,
        listType: String,
        rawPhone: String,
        canonicalPhone: String,
    ): Boolean {
        val now = System.currentTimeMillis()
        database.rawQuery(
            "SELECT ${DbContract.PhoneRules.PHONE} FROM ${DbContract.PhoneRules.TABLE} " +
                "WHERE ${DbContract.PhoneRules.LIST_TYPE} = ? AND " +
                "(${DbContract.PhoneRules.EXPIRES_AT} IS NULL OR " +
                "${DbContract.PhoneRules.EXPIRES_AT} > ?)",
            arrayOf(listType, now.toString()),
        ).use { cursor ->
            val phoneColumn = cursor.getColumnIndexOrThrow(DbContract.PhoneRules.PHONE)
            while (cursor.moveToNext()) {
                val storedPhone = cursor.getString(phoneColumn).orEmpty()
                if (samePhone(rawPhone, canonicalPhone, storedPhone)) return true
            }
        }
        return false
    }

    private fun purgeExpiredPhoneRules(database: SQLiteDatabase) {
        database.delete(
            DbContract.PhoneRules.TABLE,
            "${DbContract.PhoneRules.EXPIRES_AT} IS NOT NULL AND " +
                "${DbContract.PhoneRules.EXPIRES_AT} <= ?",
            arrayOf(System.currentTimeMillis().toString()),
        )
    }

    /**
     * True once the same canonical number already has at least
     * [EMERGENCY_REPEAT_MIN_REJECTED_CALLS] rejected calls inside the emergency window.
     * With a threshold of two, the third and every following call within
     * [EMERGENCY_REPEAT_WINDOW_MS] breaks through, while spammers' double auto-dials do not.
     */
    private fun hasRecentRejectedSilenceCalls(
        database: SQLiteDatabase,
        canonicalPhone: String,
    ): Boolean {
        val cutoff = System.currentTimeMillis() - EMERGENCY_REPEAT_WINDOW_MS
        val targetDigits = PhoneNumbers.digits(canonicalPhone)
        if (targetDigits.isEmpty()) return false

        var rejectedMatches = 0
        database.rawQuery(
            "SELECT ${DbContract.CallLogs.PHONE} FROM ${DbContract.CallLogs.TABLE} " +
                "WHERE ${DbContract.CallLogs.TIMESTAMP} >= ? AND " +
                "${DbContract.CallLogs.REASON} = ?",
            arrayOf(cutoff.toString(), "silent_schedule"),
        ).use { cursor ->
            val phoneColumn = cursor.getColumnIndexOrThrow(DbContract.CallLogs.PHONE)
            while (cursor.moveToNext()) {
                val recentPhone = cursor.getString(phoneColumn).orEmpty()
                if (PhoneNumbers.isHidden(recentPhone)) continue
                val recentCanonical = PhoneNumbers.canonicalize(appContext, recentPhone)
                if (PhoneNumbers.digits(recentCanonical) == targetDigits) {
                    rejectedMatches++
                    if (rejectedMatches >= EMERGENCY_REPEAT_MIN_REJECTED_CALLS) return true
                }
            }
        }
        return false
    }

    /**
     * True when the number is blocked by a conscious rule (blacklist, country, operator or
     * international block). The emergency repeat must never bypass those decisions.
     */
    private fun isExplicitlyBlocked(
        database: SQLiteDatabase,
        rawPhone: String,
        canonicalPhone: String,
        settings: Map<String, String>,
    ): Boolean {
        if (matchesPhoneRule(database, DbContract.PhoneRules.BLACK, rawPhone, canonicalPhone)) {
            return true
        }

        val countries = readCountries(database)
        val phoneDigits = PhoneNumbers.digits(canonicalPhone)
        val matchedCountry = countries
            .filter { it.dialDigits.isNotEmpty() && phoneDigits.startsWith(it.dialDigits) }
            .maxByOrNull { it.dialDigits.length }

        if (matchedCountry != null) {
            val nationalDigits = phoneDigits.drop(matchedCountry.dialDigits.length)
            if (findOperatorAction(database, matchedCountry.isoCode, nationalDigits) == ACTION_BLOCK) {
                return true
            }
            if (matchedCountry.action == ACTION_BLOCK) return true
        }

        return settings.bool(DbContract.SettingKeys.BLOCK_INTERNATIONAL, false) &&
            isInternational(rawPhone, canonicalPhone, matchedCountry, countries)
    }

    private fun samePhone(rawPhone: String, canonicalPhone: String, storedPhone: String): Boolean {
        val storedCanonical = PhoneNumbers.canonicalize(appContext, storedPhone)
        val incomingDigits = PhoneNumbers.digits(canonicalPhone)
        val storedDigits = PhoneNumbers.digits(storedCanonical)
        if (incomingDigits.isNotEmpty() && incomingDigits == storedDigits) return true
        return PhoneNumbers.compare(
            appContext,
            canonicalPhone.ifBlank { rawPhone },
            storedPhone,
        )
    }

    private fun isInternational(
        rawPhone: String,
        canonicalPhone: String,
        matchedCountry: CountryRule?,
        countries: List<CountryRule>,
    ): Boolean {
        val rawDigits = PhoneNumbers.digits(rawPhone)
        val explicitInternational = rawPhone.trim().startsWith("+") || rawDigits.startsWith("00")
        val homeDialCode = homeDialCode(countries)
        if (matchedCountry != null && homeDialCode != null) {
            return matchedCountry.dialDigits != homeDialCode
        }
        if (matchedCountry != null && !explicitInternational) return false
        return explicitInternational || canonicalPhone.startsWith("+") && matchedCountry == null
    }

    private fun homeDialCode(countries: List<CountryRule>): String? {
        val homeIso = PhoneNumbers.homeCountryIso(appContext) ?: return null
        return countries.firstOrNull { country ->
            country.isoCode.equals(homeIso, ignoreCase = true) ||
                (country.isoCode == "US-CA" && homeIso in setOf("US", "CA"))
        }?.dialDigits
    }

    private fun isWithinQuietSchedule(settings: Map<String, String>, calendar: Calendar): Boolean {
        val weekdays = settings[DbContract.SettingKeys.SILENCE_WEEKDAYS]
            ?.split(',')
            ?.mapNotNull(String::toIntOrNull)
            ?.filter { it in 1..7 }
            ?.toSet()
            ?: (1..7).toSet()
        if (weekdays.isEmpty()) return false

        val start = settings.int(
            DbContract.SettingKeys.SILENCE_START_MINUTE,
            DEFAULT_START_MINUTE,
        ).coerceIn(0, 1439)
        val end = settings.int(
            DbContract.SettingKeys.SILENCE_END_MINUTE,
            DEFAULT_END_MINUTE,
        ).coerceIn(0, 1439)
        val minuteOfDay = calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        val isoWeekday = ((calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

        if (start == end) return isoWeekday in weekdays
        if (start < end) return isoWeekday in weekdays && minuteOfDay in start until end
        if (minuteOfDay >= start) return isoWeekday in weekdays
        if (minuteOfDay < end) {
            val previousWeekday = if (isoWeekday == 1) 7 else isoWeekday - 1
            return previousWeekday in weekdays
        }
        return false
    }

    private fun Map<String, String>.bool(key: String, default: Boolean): Boolean =
        this[key]?.toBooleanStrictOrNull() ?: default

    private fun Map<String, String>.int(key: String, default: Int): Int =
        this[key]?.toIntOrNull() ?: default

    private fun verdict(allowed: Boolean, reason: String, phone: String) =
        CallRuleVerdict(allowed = allowed, reason = reason, phoneNumber = phone)

    private data class CountryRule(
        val isoCode: String,
        val dialDigits: String,
        val action: String,
    )

    private companion object {
        const val TAG = "CallGuardRuleEngine"
        const val ACTION_ALLOW = "allow"
        const val ACTION_BLOCK = "block"
        const val DEFAULT_START_MINUTE = 22 * 60
        const val DEFAULT_END_MINUTE = 7 * 60
        const val EMERGENCY_REPEAT_WINDOW_MS = 5 * 60 * 1000L
        const val EMERGENCY_REPEAT_MIN_REJECTED_CALLS = 2
    }
}

package com.wepr.callguard.call_guard

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telephony.PhoneNumberUtils
import android.telephony.TelephonyManager
import android.util.Log
import java.io.File
import java.util.Calendar
import java.util.Locale

data class CallRuleVerdict(
    val allowed: Boolean,
    val reason: String,
    val phoneNumber: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "verdict" to if (allowed) "ALLOW" else "REJECT",
        "reason" to reason,
        "phoneNumber" to phoneNumber,
    )
}

/** Reads the same SQLite file and setting keys used by Flutter's sqflite layer. */
class CallRuleEngine(context: Context) {
    private val appContext = context.applicationContext

    fun evaluate(phoneNumber: String?): CallRuleVerdict {
        val rawPhone = phoneNumber.orEmpty().trim()
        return try {
            openDatabase().use { database -> evaluate(database, rawPhone) }
        } catch (error: Exception) {
            Log.e(TAG, "Could not evaluate call rules; allowing the call", error)
            verdict(allowed = true, reason = "database_unavailable", rawPhone)
        }
    }

    /** Evaluates and persists rejected calls to the shared call_logs table. */
    fun evaluateAndRecord(phoneNumber: String?): CallRuleVerdict {
        val result = evaluate(phoneNumber)
        if (!result.allowed) {
            try {
                openDatabase().use { database ->
                    val values = android.content.ContentValues().apply {
                        put("phone", result.phoneNumber.ifBlank { "@numberHidden" })
                        put("reason", result.reason)
                        put("timestamp", System.currentTimeMillis())
                    }
                    database.insertOrThrow("call_logs", null, values)
                }
            } catch (error: Exception) {
                Log.e(TAG, "Could not persist blocked-call log", error)
            }
        }
        return result
    }

    private fun evaluate(database: SQLiteDatabase, rawPhone: String): CallRuleVerdict {
        val settings = readSettings(database)
        if (!settings.bool("protection_enabled", true)) {
            return verdict(true, "protection_disabled", rawPhone)
        }

        val hidden = isHiddenNumber(rawPhone)
        val canonicalPhone = if (hidden) "" else canonicalize(rawPhone)

        if (!hidden && matchesPhoneRule(database, "white", rawPhone, canonicalPhone)) {
            return verdict(true, "allowlist", canonicalPhone)
        }

        val calendar = Calendar.getInstance()
        if (settings.bool("manual_silence_enabled", false) ||
            settings.bool("manual_silence", false) ||
            settings.bool("silence_manual", false) ||
            (settings.bool("automatic_silence", false) && isWithinQuietSchedule(settings, calendar))
        ) {
            return verdict(false, "silent_schedule", logPhone(rawPhone, canonicalPhone))
        }

        if (hidden && settings.bool("block_hidden", true)) {
            return verdict(false, "hidden_number", "@numberHidden")
        }

        if (settings.bool("block_non_contacts", false) && hasContactsPermission() &&
            !isInContacts(rawPhone, canonicalPhone)
        ) {
            return verdict(false, "not_in_contacts", logPhone(rawPhone, canonicalPhone))
        }

        val countries = readCountries(database)
        val phoneDigits = digits(canonicalPhone)
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

        if (settings.bool("block_international", false) &&
            isInternational(rawPhone, canonicalPhone, matchedCountry, countries)
        ) {
            return verdict(false, "international_block", logPhone(rawPhone, canonicalPhone))
        }

        if (!hidden && matchesPhoneRule(database, "black", rawPhone, canonicalPhone)) {
            return verdict(false, "blacklist", canonicalPhone)
        }

        return verdict(true, "default_allow", canonicalPhone.ifBlank { rawPhone })
    }

    private fun openDatabase(): SQLiteDatabase {
        // sqflite's Android getDatabasesPath() resolves to Context.getDatabasePath().
        val databaseFile: File = appContext.getDatabasePath(DATABASE_NAME)
        check(databaseFile.isFile) { "Call Guard database does not exist" }
        return SQLiteDatabase.openDatabase(
            databaseFile.absolutePath,
            null,
            SQLiteDatabase.OPEN_READWRITE,
        ).apply {
            rawQuery("PRAGMA busy_timeout = 3000", null).use { }
        }
    }

    private fun readSettings(database: SQLiteDatabase): Map<String, String> {
        val settings = HashMap<String, String>()
        database.rawQuery("SELECT `key`, `value` FROM app_settings", null).use { cursor ->
            val keyColumn = cursor.getColumnIndexOrThrow("key")
            val valueColumn = cursor.getColumnIndexOrThrow("value")
            while (cursor.moveToNext()) {
                settings[cursor.getString(keyColumn)] = cursor.getString(valueColumn).orEmpty()
            }
        }
        return settings
    }

    private fun readCountries(database: SQLiteDatabase): List<CountryRule> {
        val countries = ArrayList<CountryRule>()
        database.rawQuery(
            "SELECT iso_code, dial_code, action FROM country_rules",
            null,
        ).use { cursor ->
            val isoColumn = cursor.getColumnIndexOrThrow("iso_code")
            val dialColumn = cursor.getColumnIndexOrThrow("dial_code")
            val actionColumn = cursor.getColumnIndexOrThrow("action")
            while (cursor.moveToNext()) {
                countries.add(
                    CountryRule(
                        isoCode = cursor.getString(isoColumn),
                        dialDigits = digits(cursor.getString(dialColumn)),
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
            "SELECT prefixes, action FROM operator_rules WHERE country_iso = ? ORDER BY id",
            arrayOf(countryIso),
        ).use { cursor ->
            val prefixesColumn = cursor.getColumnIndexOrThrow("prefixes")
            val actionColumn = cursor.getColumnIndexOrThrow("action")
            while (cursor.moveToNext()) {
                val action = cursor.getString(actionColumn).lowercase(Locale.ROOT)
                cursor.getString(prefixesColumn)
                    .split(',')
                    .map(::digits)
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
        database.rawQuery(
            "SELECT phone FROM phone_rules WHERE list_type = ?",
            arrayOf(listType),
        ).use { cursor ->
            val phoneColumn = cursor.getColumnIndexOrThrow("phone")
            while (cursor.moveToNext()) {
                val storedPhone = cursor.getString(phoneColumn).orEmpty()
                if (samePhone(rawPhone, canonicalPhone, storedPhone)) return true
            }
        }
        return false
    }

    private fun samePhone(rawPhone: String, canonicalPhone: String, storedPhone: String): Boolean {
        val storedCanonical = canonicalize(storedPhone)
        val incomingDigits = digits(canonicalPhone)
        val storedDigits = digits(storedCanonical)
        if (incomingDigits.isNotEmpty() && incomingDigits == storedDigits) return true
        return runCatching {
            PhoneNumberUtils.compare(appContext, canonicalPhone.ifBlank { rawPhone }, storedPhone)
        }.getOrDefault(false)
    }

    private fun isInContacts(rawPhone: String, canonicalPhone: String): Boolean {
        val lookupNumber = canonicalPhone.ifBlank { rawPhone }
        if (lookupNumber.isBlank()) return false
        val lookupUri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
            Uri.encode(lookupNumber),
        )
        return runCatching {
            appContext.contentResolver.query(
                lookupUri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null,
                null,
                null,
            )?.use { it.moveToFirst() } ?: false
        }.onFailure { Log.w(TAG, "Could not query the local contacts provider", it) }
            .getOrDefault(true)
    }

    private fun hasContactsPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            appContext.checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun isHiddenNumber(phone: String): Boolean {
        val value = phone.trim().uppercase(Locale.ROOT)
        return value.isEmpty() || value in HIDDEN_NUMBER_MARKERS
    }

    private fun canonicalize(phone: String): String {
        val normalized = PhoneNumberUtils.normalizeNumber(phone)
        val phoneDigits = digits(normalized)
        if (phoneDigits.isEmpty()) return ""
        val trimmed = phone.trim()
        if (trimmed.startsWith("+") || phoneDigits.startsWith("00")) {
            return "+${if (phoneDigits.startsWith("00")) phoneDigits.drop(2) else phoneDigits}"
        }

        val region = homeCountryIso() ?: return phoneDigits
        return runCatching {
            PhoneNumberUtils.formatNumberToE164(phone, region)
        }.getOrNull()?.takeIf(String::isNotBlank) ?: phoneDigits
    }

    private fun isInternational(
        rawPhone: String,
        canonicalPhone: String,
        matchedCountry: CountryRule?,
        countries: List<CountryRule>,
    ): Boolean {
        val rawDigits = digits(rawPhone)
        val explicitInternational = rawPhone.trim().startsWith("+") || rawDigits.startsWith("00")
        val homeDialCode = homeDialCode(countries)
        if (matchedCountry != null && homeDialCode != null) {
            return matchedCountry.dialDigits != homeDialCode
        }
        if (matchedCountry != null && !explicitInternational) return false
        return explicitInternational || canonicalPhone.startsWith("+") && matchedCountry == null
    }

    private fun homeDialCode(countries: List<CountryRule>): String? {
        val homeIso = homeCountryIso() ?: return null
        return countries.firstOrNull { country ->
            country.isoCode.equals(homeIso, ignoreCase = true) ||
                (country.isoCode == "US-CA" && homeIso in setOf("US", "CA"))
        }?.dialDigits
    }

    private fun homeCountryIso(): String? {
        val telephony = appContext.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        val networkIso = runCatching { telephony?.networkCountryIso }
            .getOrNull()
            ?.takeIf(String::isNotBlank)
        if (networkIso != null) return networkIso.uppercase(Locale.ROOT)
        val configuration = appContext.resources.configuration
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            configuration.locales[0]
        } else {
            @Suppress("DEPRECATION")
            configuration.locale
        }
        return locale.country.takeIf(String::isNotBlank)?.uppercase(Locale.ROOT)
    }

    private fun isWithinQuietSchedule(settings: Map<String, String>, calendar: Calendar): Boolean {
        val weekdays = settings["silence_weekdays"]
            ?.split(',')
            ?.mapNotNull(String::toIntOrNull)
            ?.filter { it in 1..7 }
            ?.toSet()
            ?: (1..7).toSet()
        if (weekdays.isEmpty()) return false

        val start = settings.int("silence_start_minute", DEFAULT_START_MINUTE).coerceIn(0, 1439)
        val end = settings.int("silence_end_minute", DEFAULT_END_MINUTE).coerceIn(0, 1439)
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

    private fun logPhone(rawPhone: String, canonicalPhone: String): String =
        if (isHiddenNumber(rawPhone)) "@numberHidden" else canonicalPhone.ifBlank { rawPhone }

    private fun digits(value: String): String =
        PhoneNumberUtils.normalizeNumber(value).filter { it in '0'..'9' }

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
        const val DATABASE_NAME = "call_guard.db"
        const val ACTION_ALLOW = "allow"
        const val ACTION_BLOCK = "block"
        const val DEFAULT_START_MINUTE = 22 * 60
        const val DEFAULT_END_MINUTE = 7 * 60
        val HIDDEN_NUMBER_MARKERS = setOf(
            "UNKNOWN",
            "PRIVATE",
            "PRESENTATION_RESTRICTED",
            "RESTRICTED",
            "UNAVAILABLE",
        )
    }
}

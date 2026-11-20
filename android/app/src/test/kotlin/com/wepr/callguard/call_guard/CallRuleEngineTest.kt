package com.wepr.callguard.call_guard

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CallRuleEngineTest {
    @Test
    fun blacklistRejectsNumberEvenWhenCountryIsAllowed() {
        val context = RuntimeEnvironment.getApplication()
        val databaseFile = context.getDatabasePath(DbContract.DATABASE_NAME)
        databaseFile.parentFile?.mkdirs()
        databaseFile.delete()

        val fixture = SQLiteDatabase.openOrCreateDatabase(databaseFile, null)
        try {
            createSchema(fixture)
            fixture.insertOrThrow(
                DbContract.CountryRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.CountryRules.ISO_CODE, "UA")
                    put(DbContract.CountryRules.DIAL_CODE, "+380")
                    put("name_key", "countryUkraine")
                    put("custom_name", null as String?)
                    put(DbContract.CountryRules.ACTION, "allow")
                    put(DbContract.CountryRules.AREA_CODES, "")
                },
            )
            fixture.insertOrThrow(
                DbContract.PhoneRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.PhoneRules.PHONE, "+380 67 123 45 67")
                    put(DbContract.PhoneRules.LABEL, "Explicit block")
                    put(DbContract.PhoneRules.LIST_TYPE, DbContract.PhoneRules.BLACK)
                    put(DbContract.PhoneRules.CREATED_AT, 1L)
                    putNull(DbContract.PhoneRules.EXPIRES_AT)
                },
            )
            fixture.insertOrThrow(
                DbContract.PhoneRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.PhoneRules.PHONE, "112")
                    put(DbContract.PhoneRules.LABEL, "Explicit emergency block")
                    put(DbContract.PhoneRules.LIST_TYPE, DbContract.PhoneRules.BLACK)
                    put(DbContract.PhoneRules.CREATED_AT, 1L)
                    putNull(DbContract.PhoneRules.EXPIRES_AT)
                },
            )
        } finally {
            fixture.close()
        }

        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "false",
            DbContract.SettingKeys.AUTOMATIC_SILENCE to "false",
            DbContract.SettingKeys.BLOCK_HIDDEN to "false",
            DbContract.SettingKeys.BLOCK_NON_CONTACTS to "false",
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "false",
        )
        val verdict = CallRuleEngine(context).evaluate("+380 67 123 45 67", settings)

        assertFalse(verdict.allowed)
        assertEquals("blacklist", verdict.reason)
        assertEquals(
            BridgeContract.Verdicts.REJECT,
            verdict.toMap()[BridgeContract.ResultKeys.VERDICT],
        )
        val emergencyOverridesRules = CallRuleEngine(context).evaluate(
            "112",
            settings + mapOf(
                DbContract.SettingKeys.DRIVING_MODE to "true",
                DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true",
            ),
        )
        assertEquals(true, emergencyOverridesRules.allowed)
        assertEquals("emergency_service", emergencyOverridesRules.reason)

        val shortSettings = settings + mapOf(
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "true",
            DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "false",
        )
        val shortAllowlistOff = CallRuleEngine(context) { _, _ -> false }
        assertEquals("default_allow", shortAllowlistOff.evaluate("3700", shortSettings).reason)
        assertEquals("default_allow", shortAllowlistOff.evaluate("466", shortSettings).reason)

        val shortBlockingSettings = shortSettings +
            (DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true")
        val blockedShort = shortAllowlistOff.evaluate("3700", shortBlockingSettings)
        assertFalse(blockedShort.allowed)
        assertEquals("short_number_block", blockedShort.reason)

        val contactShort = CallRuleEngine(context) { _, _ -> true }
            .evaluate("3700", shortBlockingSettings)
        assertEquals("default_allow", contactShort.reason)

        CallGuardDatabase.withDatabase(context) { database ->
            database.insertOrThrow(
                DbContract.PhoneRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.PhoneRules.PHONE, "3700")
                    put(DbContract.PhoneRules.LABEL, "Short code contact allow")
                    put(DbContract.PhoneRules.LIST_TYPE, DbContract.PhoneRules.WHITE)
                    put(DbContract.PhoneRules.CREATED_AT, 1L)
                    putNull(DbContract.PhoneRules.EXPIRES_AT)
                },
            )
        }
        val allowlistedShort = shortAllowlistOff.evaluate("3700", shortBlockingSettings)
        assertEquals("allowlist", allowlistedShort.reason)
    }

    @Test
    fun emergencyServiceNumbersAlwaysPassBeforeCallRules() {
        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.DRIVING_MODE to "true",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
            DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true",
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "true",
        )
        val engine = CallRuleEngine(RuntimeEnvironment.getApplication())

        listOf("101", "102", "103", "104", "112", "911", "999", "+1 12", "00-911")
            .forEach { phone ->
                val verdict = engine.evaluate(phone, settings)
                assertEquals("$phone must be allowed", true, verdict.allowed)
                assertEquals("$phone", "emergency_service", verdict.reason)
            }
    }

    private fun createSchema(database: SQLiteDatabase) {
        database.execSQL(
            "CREATE TABLE ${DbContract.PhoneRules.TABLE} (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "${DbContract.PhoneRules.PHONE} TEXT NOT NULL, " +
                "${DbContract.PhoneRules.LABEL} TEXT, " +
                "${DbContract.PhoneRules.LIST_TYPE} TEXT NOT NULL, " +
                "${DbContract.PhoneRules.CREATED_AT} INTEGER NOT NULL, " +
                "${DbContract.PhoneRules.EXPIRES_AT} INTEGER)",
        )
        database.execSQL(
            "CREATE TABLE ${DbContract.CountryRules.TABLE} (" +
                "${DbContract.CountryRules.ISO_CODE} TEXT PRIMARY KEY, " +
                "${DbContract.CountryRules.DIAL_CODE} TEXT NOT NULL, " +
                "name_key TEXT NOT NULL, custom_name TEXT, " +
                "${DbContract.CountryRules.ACTION} TEXT NOT NULL, " +
                "${DbContract.CountryRules.AREA_CODES} TEXT NOT NULL DEFAULT '')",
        )
        database.execSQL(
            "CREATE TABLE ${DbContract.OperatorRules.TABLE} (" +
                "${DbContract.OperatorRules.ID} INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "${DbContract.OperatorRules.COUNTRY_ISO} TEXT NOT NULL, " +
                "${DbContract.OperatorRules.OPERATOR_NAME} TEXT NOT NULL, " +
                "${DbContract.OperatorRules.PREFIXES} TEXT NOT NULL, " +
                "${DbContract.OperatorRules.ACTION} TEXT NOT NULL)",
        )
        database.execSQL(
            "CREATE TABLE ${DbContract.CallReminders.TABLE} (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, phone TEXT NOT NULL, " +
                "contact_name TEXT, remind_at INTEGER NOT NULL, note TEXT, " +
                "is_done INTEGER NOT NULL DEFAULT 0, repeat_type TEXT NOT NULL DEFAULT 'none', " +
                "repeat_interval INTEGER NOT NULL DEFAULT 1, last_fired_at INTEGER, " +
                "created_at INTEGER NOT NULL DEFAULT 0)",
        )
        database.execSQL(
            "CREATE TABLE ${DbContract.CallLogs.TABLE} (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT, phone TEXT NOT NULL, " +
                "contact_name TEXT, reason TEXT NOT NULL, timestamp INTEGER NOT NULL)",
        )
        database.execSQL(
            "CREATE TABLE ${DbContract.AppSettings.TABLE} (" +
                "${DbContract.AppSettings.KEY} TEXT PRIMARY KEY, " +
                "${DbContract.AppSettings.VALUE} TEXT NOT NULL)",
        )
    }
}

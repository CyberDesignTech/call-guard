package com.wepr.callguard

import android.Manifest
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class CallRuleEngineTest {
    @Test
    fun manualSilenceRejectionIsLoggedAndNotifiesCallHandled() {
        val context = RuntimeEnvironment.getApplication()
        val databaseFile = context.getDatabasePath(DbContract.DATABASE_NAME)
        databaseFile.parentFile?.mkdirs()
        databaseFile.delete()

        val fixture = SQLiteDatabase.openOrCreateDatabase(databaseFile, null)
        try {
            createSchema(fixture)
        } finally {
            fixture.close()
        }

        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
            DbContract.SettingKeys.AUTOMATIC_SILENCE to "false",
            DbContract.SettingKeys.BLOCK_HIDDEN to "false",
            DbContract.SettingKeys.BLOCK_NON_CONTACTS to "false",
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "false",
        )
        try {
            val engine = CallRuleEngine(context)
            val verdict = engine.evaluate("+1 202 555 0123", settings)
            assertFalse(verdict.allowed)
            assertEquals("silent_schedule", verdict.reason)

            var callHandledNotified = false
            var completionDelivered = false
            CallScreeningPostResponseWork.complete(
                verdict = verdict,
                onRejectedCall = { throw IllegalStateException("Optional work failed") },
                recordCallLog = {
                    engine.recordCallLog(verdict.phoneNumber, verdict.reason, "Test caller")
                },
                notifyCallHandled = { onDelivered ->
                    callHandledNotified = true
                    onDelivered()
                },
                onComplete = { completionDelivered = true },
            )

            assertTrue(callHandledNotified)
            assertTrue(completionDelivered)
            CallGuardDatabase.withDatabase(context) { database ->
                database.rawQuery(
                    "SELECT phone, reason FROM ${DbContract.CallLogs.TABLE} " +
                        "ORDER BY ${DbContract.CallLogs.TIMESTAMP} DESC LIMIT 1",
                    null,
                ).use { cursor ->
                    assertTrue(cursor.moveToFirst())
                    assertEquals(verdict.phoneNumber, cursor.getString(0))
                    assertEquals("silent_schedule", cursor.getString(1))
                }
            }
        } finally {
            CallGuardDatabase.closeForTesting()
        }
    }

    @Test
    fun everyBlockedIncomingCallIsPersistedAndAllowedCallsAreNot() {
        val context = RuntimeEnvironment.getApplication()
        val databaseFile = context.getDatabasePath(DbContract.DATABASE_NAME)
        databaseFile.parentFile?.mkdirs()
        CallGuardDatabase.closeForTesting()
        databaseFile.delete()

        val fixture = SQLiteDatabase.openOrCreateDatabase(databaseFile, null)
        try {
            createSchema(fixture)
            listOf(
                Triple("UA", "+380", "neutral"),
                Triple("PL", "+48", "block"),
            ).forEach { (iso, dialCode, action) ->
                fixture.insertOrThrow(
                    DbContract.CountryRules.TABLE,
                    null,
                    ContentValues().apply {
                        put(DbContract.CountryRules.ISO_CODE, iso)
                        put(DbContract.CountryRules.DIAL_CODE, dialCode)
                        put("name_key", "country$iso")
                        putNull("custom_name")
                        put(DbContract.CountryRules.ACTION, action)
                        put(DbContract.CountryRules.AREA_CODES, "")
                    },
                )
            }
            fixture.insertOrThrow(
                DbContract.OperatorRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.OperatorRules.COUNTRY_ISO, "UA")
                    put(DbContract.OperatorRules.OPERATOR_NAME, "Test operator")
                    put(DbContract.OperatorRules.PREFIXES, "63")
                    put(DbContract.OperatorRules.ACTION, "block")
                },
            )
            fun addPhoneRule(phone: String, listType: String, expiresAt: Long? = null) {
                fixture.insertOrThrow(
                    DbContract.PhoneRules.TABLE,
                    null,
                    ContentValues().apply {
                        put(DbContract.PhoneRules.PHONE, phone)
                        put(DbContract.PhoneRules.LABEL, "Test rule")
                        put(DbContract.PhoneRules.LIST_TYPE, listType)
                        put(DbContract.PhoneRules.CREATED_AT, System.currentTimeMillis())
                        if (expiresAt == null) putNull(DbContract.PhoneRules.EXPIRES_AT)
                        else put(DbContract.PhoneRules.EXPIRES_AT, expiresAt)
                    },
                )
            }
            addPhoneRule("+380 50 111 22 33", DbContract.PhoneRules.BLACK)
            addPhoneRule(
                "+380 50 222 33 44",
                DbContract.PhoneRules.BLACK,
                System.currentTimeMillis() + 60 * 60 * 1000L,
            )
            addPhoneRule("+380 67 123 45 67", DbContract.PhoneRules.WHITE)
        } finally {
            fixture.close()
        }

        shadowOf(context).grantPermissions(Manifest.permission.READ_CONTACTS)

        val baseSettings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "false",
            DbContract.SettingKeys.AUTOMATIC_SILENCE to "false",
            DbContract.SettingKeys.BLOCK_HIDDEN to "true",
            DbContract.SettingKeys.BLOCK_NON_CONTACTS to "false",
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "false",
            DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "false",
            DbContract.SettingKeys.ANSWERING_ENABLED to "false",
            DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT to "false",
        )
        val engine = CallRuleEngine(context) { _, _ -> false }
        var expectedLogCount = 0

        fun currentLogs(): List<Pair<String, String>> =
            CallGuardDatabase.withDatabase(context) { database ->
                val logs = mutableListOf<Pair<String, String>>()
                database.rawQuery(
                    "SELECT ${DbContract.CallLogs.PHONE}, ${DbContract.CallLogs.REASON} " +
                        "FROM ${DbContract.CallLogs.TABLE} " +
                        "ORDER BY ${DbContract.CallLogs.TIMESTAMP} DESC, " +
                        "${DbContract.CallLogs.ID} DESC",
                    null,
                ).use { cursor ->
                    while (cursor.moveToNext()) {
                        logs.add(cursor.getString(0) to cursor.getString(1))
                    }
                }
                logs
            }

        fun screen(phone: String?, settings: Map<String, String> = baseSettings): CallRuleVerdict {
            val verdict = engine.evaluate(phone, settings)
            CallScreeningPostResponseWork.complete(
                verdict = verdict,
                onRejectedCall = {},
                recordCallLog = {
                    engine.recordCallLog(verdict.phoneNumber, verdict.reason)
                },
                notifyCallHandled = { onDelivered -> onDelivered() },
                onComplete = {},
            )
            return verdict
        }

        fun assertRejectedAndLogged(
            phone: String?,
            reason: String,
            settings: Map<String, String> = baseSettings,
        ): CallRuleVerdict {
            val verdict = screen(phone, settings)
            assertFalse("$phone should be rejected", verdict.allowed)
            assertEquals(reason, verdict.reason)
            expectedLogCount++
            val logs = currentLogs()
            assertEquals(expectedLogCount, logs.size)
            assertEquals(verdict.phoneNumber to reason, logs.first())
            return verdict
        }

        try {
            assertRejectedAndLogged("+380 50 111 22 33", "blacklist")
            assertRejectedAndLogged("+380 50 222 33 44", "blacklist")

            repeat(3) { index ->
                val hidden = assertRejectedAndLogged(
                    listOf(null, "", "PRESENTATION_RESTRICTED")[index],
                    "hidden_number",
                )
                assertEquals(PhoneNumbers.HIDDEN_NUMBER, hidden.phoneNumber)
            }

            assertRejectedAndLogged(
                "+380 50 333 44 55",
                "not_in_contacts",
                baseSettings + (DbContract.SettingKeys.BLOCK_NON_CONTACTS to "true"),
            )

            val shortSettings = baseSettings +
                (DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true")
            assertRejectedAndLogged("466", "short_number_block", shortSettings)
            assertRejectedAndLogged("3700", "short_number_block", shortSettings)

            assertRejectedAndLogged(
                "+44 20 7123 4567",
                "international_block",
                baseSettings + (DbContract.SettingKeys.BLOCK_INTERNATIONAL to "true"),
            )
            assertRejectedAndLogged("+48 501 234 567", "country_block")
            assertRejectedAndLogged("+380 63 555 01 02", "operator_block")

            val silentSettings = baseSettings + mapOf(
                DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
                DbContract.SettingKeys.ANSWERING_ENABLED to "true",
                DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT to "true",
            )
            val urgentNumber = "+380 50 444 55 66"
            assertRejectedAndLogged(urgentNumber, "silent_schedule", silentSettings)
            assertRejectedAndLogged(urgentNumber, "silent_schedule", silentSettings)
            val thirdUrgentCall = screen(urgentNumber, silentSettings)
            assertTrue(thirdUrgentCall.allowed)
            assertEquals("emergency_repeat", thirdUrgentCall.reason)
            assertEquals(expectedLogCount, currentLogs().size)

            assertRejectedAndLogged(
                "+380 67 123 45 67",
                "driving_mode",
                baseSettings + (DbContract.SettingKeys.DRIVING_MODE to "true"),
            )

            for (emergency in listOf("103", "112")) {
                val verdict = screen(
                    emergency,
                    baseSettings + mapOf(
                        DbContract.SettingKeys.DRIVING_MODE to "true",
                        DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
                        DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true",
                    ),
                )
                assertTrue("$emergency must pass", verdict.allowed)
                assertEquals("emergency_service", verdict.reason)
                assertEquals(expectedLogCount, currentLogs().size)
            }
        } finally {
            CallGuardDatabase.closeForTesting()
        }
    }

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
                DbContract.CountryRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.CountryRules.ISO_CODE, "LT")
                    put(DbContract.CountryRules.DIAL_CODE, "+37")
                    put("name_key", "countryLithuania")
                    put("custom_name", null as String?)
                    put(DbContract.CountryRules.ACTION, "block")
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
        listOf("11", "3700", "080050", "+3700").forEach { number ->
            val shortAllowed = shortAllowlistOff.evaluate(number, shortSettings)
            assertTrue("$number should be allowed", shortAllowed.allowed)
            assertEquals(
                "$number should skip country and international rules",
                "default_allow",
                shortAllowed.reason,
            )
        }
        listOf("7", "1234567", "1234567890").forEach { number ->
            val normalAllowed = shortAllowlistOff.evaluate(number, shortSettings)
            assertFalse(
                "$number must not be classified as a short code",
                normalAllowed.reason == "short_number_block",
            )
        }

        val shortBlockingSettings = shortSettings +
            (DbContract.SettingKeys.BLOCK_SHORT_NUMBERS to "true")
        listOf("11", "3700", "080050", "+3700").forEach { number ->
            val blockedShort = shortAllowlistOff.evaluate(number, shortBlockingSettings)
            assertFalse("$number should be rejected", blockedShort.allowed)
            assertEquals("short_number_block", blockedShort.reason)
        }
        listOf("7", "1234567", "1234567890").forEach { number ->
            val normalAllowed = shortAllowlistOff.evaluate(number, shortBlockingSettings)
            assertFalse(
                "$number must use normal-number rules",
                normalAllowed.reason == "short_number_block",
            )
        }

        val contactShort = CallRuleEngine(context) { _, _ -> true }
            .evaluate("080050", shortBlockingSettings)
        assertEquals("default_allow", contactShort.reason)

        CallGuardDatabase.withDatabase(context) { database ->
            database.insertOrThrow(
                DbContract.PhoneRules.TABLE,
                null,
                ContentValues().apply {
                    put(DbContract.PhoneRules.PHONE, "080050")
                    put(DbContract.PhoneRules.LABEL, "Short code contact allow")
                    put(DbContract.PhoneRules.LIST_TYPE, DbContract.PhoneRules.WHITE)
                    put(DbContract.PhoneRules.CREATED_AT, 1L)
                    putNull(DbContract.PhoneRules.EXPIRES_AT)
                },
            )
        }
        val allowlistedShort = shortAllowlistOff.evaluate("080050", shortBlockingSettings)
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

    @Test
    fun emergencyRepeatRequiresTheScenariosMasterSwitch() {
        val context = RuntimeEnvironment.getApplication()
        val databaseFile = context.getDatabasePath(DbContract.DATABASE_NAME)
        databaseFile.parentFile?.mkdirs()
        CallGuardDatabase.closeForTesting()
        databaseFile.delete()

        val fixture = SQLiteDatabase.openOrCreateDatabase(databaseFile, null)
        try {
            createSchema(fixture)
            repeat(2) { offset ->
                fixture.insertOrThrow(
                    DbContract.CallLogs.TABLE,
                    null,
                    ContentValues().apply {
                        put(DbContract.CallLogs.PHONE, "+380 63 555 01 02")
                        put(DbContract.CallLogs.REASON, "silent_schedule")
                        put(DbContract.CallLogs.TIMESTAMP, System.currentTimeMillis() - offset * 1000L)
                    },
                )
            }
        } finally {
            fixture.close()
        }

        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
            DbContract.SettingKeys.AUTOMATIC_SILENCE to "false",
            DbContract.SettingKeys.BLOCK_HIDDEN to "false",
            DbContract.SettingKeys.BLOCK_NON_CONTACTS to "false",
            DbContract.SettingKeys.BLOCK_INTERNATIONAL to "false",
            DbContract.SettingKeys.ANSWERING_EMERGENCY_REPEAT to "true",
            DbContract.SettingKeys.ANSWERING_ENABLED to "false",
        )
        try {
            val engine = CallRuleEngine(context)
            val withoutMaster = engine.evaluate("+380 63 555 01 02", settings)
            assertFalse(withoutMaster.allowed)
            assertEquals("silent_schedule", withoutMaster.reason)

            val withMaster = engine.evaluate(
                "+380 63 555 01 02",
                settings + (DbContract.SettingKeys.ANSWERING_ENABLED to "true"),
            )
            assertTrue(withMaster.allowed)
            assertEquals("emergency_repeat", withMaster.reason)
        } finally {
            CallGuardDatabase.closeForTesting()
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

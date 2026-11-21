package com.wepr.callguard.call_guard

import org.junit.Assert.assertFalse
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class OptionalAnsweringModuleTest {
    @Test
    fun disabledMasterPreventsScenarioRejectionNotificationAndReminder() {
        val context = RuntimeEnvironment.getApplication()
        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "true",
            DbContract.SettingKeys.ANSWERING_ENABLED to "false",
            DbContract.SettingKeys.ANSWERING_SCENARIO to
                OptionalAnsweringModule.SCENARIO_UNKNOWN_NUMBERS,
            DbContract.SettingKeys.ANSWERING_LOCAL_NOTIFICATION to "true",
            DbContract.SettingKeys.ANSWERING_AUTO_REMIND to "true",
        )

        assertFalse(
            OptionalAnsweringModule.shouldRejectUnknownCall(
                context = context,
                phoneNumber = "+1 202 555 0142",
                ruleVerdict = CallRuleVerdict(true, "default_allow", "+12025550142"),
                settings = settings,
            ),
        )
        assertFalse(
            OptionalAnsweringModule.handleRejectedCall(
                context = context,
                phoneNumber = "+1 202 555 0142",
                ruleReason = "silent_schedule",
                settings = settings,
            ),
        )
    }

    @Test
    fun disabledMainProtectionAlsoDisablesEveryOptionalScenarioAction() {
        val settings = mapOf(
            DbContract.SettingKeys.PROTECTION_ENABLED to "false",
            DbContract.SettingKeys.ANSWERING_ENABLED to "true",
            DbContract.SettingKeys.ANSWERING_SCENARIO to
                OptionalAnsweringModule.SCENARIO_SILENCE,
            DbContract.SettingKeys.ANSWERING_LOCAL_NOTIFICATION to "true",
            DbContract.SettingKeys.ANSWERING_AUTO_REMIND to "true",
        )

        assertFalse(OptionalAnsweringModule.isEnabled(settings))
        assertFalse(
            OptionalAnsweringModule.handleRejectedCall(
                context = RuntimeEnvironment.getApplication(),
                phoneNumber = "+1 202 555 0142",
                ruleReason = "silent_schedule",
                settings = settings,
            ),
        )
    }
}

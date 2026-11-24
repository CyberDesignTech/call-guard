package com.wepr.callguard

import org.junit.Assert.assertEquals
import org.junit.Test

class StatusNotificationHelperTest {
    @Test
    fun choosesPausedDrivingSilenceAndActiveIconsInPriorityOrder() {
        assertEquals(
            R.drawable.ic_stat_shield_paused,
            StatusNotificationHelper.iconFor(
                StatusNotificationHelper.modeFor(
                    protectionEnabled = false,
                    drivingMode = true,
                    silenceMode = true,
                ),
            ),
        )
        assertEquals(
            R.drawable.ic_stat_shield_driving,
            StatusNotificationHelper.iconFor(
                StatusNotificationHelper.modeFor(
                    protectionEnabled = true,
                    drivingMode = true,
                    silenceMode = true,
                ),
            ),
        )
        assertEquals(
            R.drawable.ic_stat_shield_silence,
            StatusNotificationHelper.iconFor(
                StatusNotificationHelper.modeFor(
                    protectionEnabled = true,
                    drivingMode = false,
                    silenceMode = true,
                ),
            ),
        )
        assertEquals(
            R.drawable.ic_stat_shield_active,
            StatusNotificationHelper.iconFor(
                StatusNotificationHelper.modeFor(
                    protectionEnabled = true,
                    drivingMode = false,
                    silenceMode = false,
                ),
            ),
        )
    }
}

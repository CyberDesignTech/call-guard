package com.wepr.callguard.call_guard

import android.app.NotificationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class DndSyncControllerTest {
    @Test
    fun activeModeSavesAllAndEnablesPriorityThenRestoresPreviousFilter() {
        val state = FakeFilter()
        val activeSettings = activeSettings()

        sync(activeSettings, state)

        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, state.filter)
        assertEquals(
            NotificationManager.INTERRUPTION_FILTER_ALL.toString(),
            state.previousFilter,
        )

        sync(
            activeSettings + mapOf(
                DbContract.SettingKeys.DRIVING_MODE to "false",
                DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter,
            ),
            state,
        )

        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALL, state.filter)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), state.previousFilter)
    }

    @Test
    fun doesNotTakeOverOrRestoreManualDndFilter() {
        val manualFilter = FakeFilter(filter = NotificationManager.INTERRUPTION_FILTER_NONE)
        sync(activeSettings(), manualFilter)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_NONE, manualFilter.filter)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), manualFilter.previousFilter)
        assertTrue(manualFilter.appliedFilters.isEmpty())

        val changedByUser = FakeFilter(
            filter = NotificationManager.INTERRUPTION_FILTER_NONE,
            previousFilter = NotificationManager.INTERRUPTION_FILTER_ALL.toString(),
        )
        sync(
            activeSettings() + mapOf(
                DbContract.SettingKeys.DRIVING_MODE to "false",
                DbContract.SettingKeys.DND_PREVIOUS_FILTER to changedByUser.previousFilter,
            ),
            changedByUser,
        )
        assertEquals(NotificationManager.INTERRUPTION_FILTER_NONE, changedByUser.filter)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), changedByUser.previousFilter)
        assertTrue(changedByUser.appliedFilters.isEmpty())
    }

    @Test
    fun requiresProtectionSyncSwitchAndGrantedPolicyAccess() {
        val noProtection = FakeFilter()
        sync(activeSettings() + (DbContract.SettingKeys.PROTECTION_ENABLED to "false"), noProtection)
        assertFalse(noProtection.appliedFilters.isNotEmpty())

        val syncDisabled = FakeFilter()
        sync(activeSettings() + (DbContract.SettingKeys.DND_SYNC_ENABLED to "false"), syncDisabled)
        assertTrue(syncDisabled.appliedFilters.isEmpty())

        val noPolicyAccess = FakeFilter(policyAccess = false)
        sync(activeSettings(), noPolicyAccess)
        assertTrue(noPolicyAccess.appliedFilters.isEmpty())
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), noPolicyAccess.previousFilter)
    }

    @Test
    fun manualSilenceAndActiveScheduleAlsoEnableDnd() {
        val manual = FakeFilter()
        sync(
            activeSettings() + mapOf(
                DbContract.SettingKeys.DRIVING_MODE to "false",
                DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "true",
            ),
            manual,
        )
        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, manual.filter)

        val scheduled = FakeFilter()
        val scheduleSettings = activeSettings() + mapOf(
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "false",
            DbContract.SettingKeys.AUTOMATIC_SILENCE to "true",
            DbContract.SettingKeys.SILENCE_START_MINUTE to "1320",
            DbContract.SettingKeys.SILENCE_END_MINUTE to "420",
            DbContract.SettingKeys.SILENCE_WEEKDAYS to "1",
        )
        sync(scheduleSettings, scheduled, mondayAt(22, 30))
        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, scheduled.filter)
    }

    @Test
    fun findsTheNextQuietScheduleTransition() {
        val settings = mapOf(
            DbContract.SettingKeys.SILENCE_START_MINUTE to "1320",
            DbContract.SettingKeys.SILENCE_END_MINUTE to "420",
            DbContract.SettingKeys.SILENCE_WEEKDAYS to "1",
        )
        val now = mondayAt(21, 59)
        val next = QuietSchedulePolicy.nextTransitionAtMillis(settings, now)
        val expected = mondayAt(22, 0).timeInMillis

        assertEquals(expected, next)
    }

    private fun sync(
        settings: Map<String, String>,
        state: FakeFilter,
        now: Calendar = mondayAt(12, 0),
    ) {
        DndSyncController.reconcile(
            settings = settings + (DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter),
            hasPolicyAccess = state.policyAccess,
            currentFilter = state.filter,
            persistPreviousFilter = { state.previousFilter = it },
            setInterruptionFilter = {
                state.appliedFilters.add(it)
                state.filter = it
            },
            now = now,
        )
    }

    private fun activeSettings(): Map<String, String> = mapOf(
        DbContract.SettingKeys.PROTECTION_ENABLED to "true",
        DbContract.SettingKeys.DND_SYNC_ENABLED to "true",
        DbContract.SettingKeys.DRIVING_MODE to "true",
        DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "false",
        DbContract.SettingKeys.AUTOMATIC_SILENCE to "false",
        DbContract.SettingKeys.DND_PREVIOUS_FILTER to "-1",
    )

    private fun mondayAt(hour: Int, minute: Int): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            set(2026, Calendar.JUNE, 1, hour, minute, 0) // Monday
            set(Calendar.MILLISECOND, 0)
        }

    private class FakeFilter(
        var filter: Int = NotificationManager.INTERRUPTION_FILTER_ALL,
        var previousFilter: String = DndSyncController.NO_PREVIOUS_FILTER.toString(),
        val policyAccess: Boolean = true,
    ) {
        val appliedFilters = mutableListOf<Int>()
    }
}

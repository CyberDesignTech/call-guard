package com.wepr.callguard

import android.app.NotificationManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Calendar
import java.util.TimeZone

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DndSyncControllerTest {
    @Test
    fun activeModeSavesAllAndEnablesPriorityThenRestoresPreviousFilter() {
        val state = FakeFilter()
        val activeSettings = activeSettings()
        val originalPolicy = state.policy

        sync(activeSettings, state)

        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, state.filter)
        assertEquals(
            NotificationManager.INTERRUPTION_FILTER_ALL.toString(),
            state.previousFilter,
        )
        assertEquals(originalPolicy, state.previousPolicy)
        assertEquals(
            NotificationManager.Policy.PRIORITY_CATEGORY_CALLS or
                NotificationManager.Policy.PRIORITY_CATEGORY_REPEAT_CALLERS,
            state.policy.priorityCategories,
        )
        assertEquals(
            NotificationManager.Policy.PRIORITY_SENDERS_ANY,
            state.policy.priorityCallSenders,
        )
        assertEquals(
            NotificationManager.Policy.PRIORITY_SENDERS_CONTACTS,
            state.policy.priorityMessageSenders,
        )
        assertEquals(
            originalPolicy.suppressedVisualEffects or
                NotificationManager.Policy.SUPPRESSED_EFFECT_PEEK,
            state.policy.suppressedVisualEffects,
        )

        sync(
            activeSettings + mapOf(
                DbContract.SettingKeys.DRIVING_MODE to "false",
                DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter,
            ),
            state,
        )

        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALL, state.filter)
        assertEquals(originalPolicy, state.policy)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), state.previousFilter)
        assertEquals(null, state.previousPolicy)
    }

    @Test
    fun doesNotTakeOverOrRestoreManualDndFilter() {
        val manualFilter = FakeFilter(filter = NotificationManager.INTERRUPTION_FILTER_NONE)
        sync(activeSettings(), manualFilter)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_NONE, manualFilter.filter)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), manualFilter.previousFilter)
        assertTrue(manualFilter.appliedFilters.isEmpty())
        assertTrue(manualFilter.appliedPolicies.isEmpty())

        val changedByUser = FakeFilter(
            filter = NotificationManager.INTERRUPTION_FILTER_NONE,
            previousFilter = NotificationManager.INTERRUPTION_FILTER_ALL.toString(),
            previousPolicy = FakeFilter.originalPolicy,
        )
        val userPolicy = DndSyncController.DndPolicySnapshot(
            priorityCategories = NotificationManager.Policy.PRIORITY_CATEGORY_REMINDERS,
            priorityCallSenders = NotificationManager.Policy.PRIORITY_SENDERS_STARRED,
            priorityMessageSenders = NotificationManager.Policy.PRIORITY_SENDERS_CONTACTS,
            suppressedVisualEffects = 0,
        )
        changedByUser.policy = userPolicy
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
        assertTrue(changedByUser.appliedPolicies.isEmpty())
        assertEquals(userPolicy, changedByUser.policy)
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
        assertTrue(noPolicyAccess.appliedPolicies.isEmpty())
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
    fun quickSilenceEnablesDndUntilItsPersistedDeadline() {
        val now = mondayAt(12, 0)
        val state = FakeFilter()
        val active = activeSettings() + mapOf(
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.MANUAL_SILENCE_ENABLED to "false",
            DbContract.SettingKeys.QUICK_SILENCE_UNTIL to
                (now.timeInMillis + 60 * 60 * 1000L).toString(),
        )

        sync(active, state, now)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, state.filter)

        sync(
            active + mapOf(
                DbContract.SettingKeys.QUICK_SILENCE_UNTIL to
                    (now.timeInMillis - 1).toString(),
                DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter,
            ),
            state,
            now,
        )
        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALL, state.filter)
    }

    @Test
    fun manualMessengerMuteWorksWithoutAutomaticModeSync() {
        val state = FakeFilter()
        val settings = activeSettings() + mapOf(
            DbContract.SettingKeys.DRIVING_MODE to "false",
            DbContract.SettingKeys.DND_SYNC_ENABLED to "false",
            DbContract.SettingKeys.MANUAL_MESSENGER_MUTE to "true",
        )

        sync(settings, state)

        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, state.filter)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALL.toString(), state.previousFilter)

        sync(
            settings + mapOf(
                DbContract.SettingKeys.MANUAL_MESSENGER_MUTE to "false",
                DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter,
            ),
            state,
        )

        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALL, state.filter)
        assertEquals(DndSyncController.NO_PREVIOUS_FILTER.toString(), state.previousFilter)
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
        val savedPolicy = state.previousPolicy
        val savedSettings = settings + mapOf(
            DbContract.SettingKeys.DND_PREVIOUS_FILTER to state.previousFilter,
            DbContract.SettingKeys.DND_PREVIOUS_POLICY_CATEGORIES to
                (savedPolicy?.priorityCategories?.toString() ?: "-1"),
            DbContract.SettingKeys.DND_PREVIOUS_POLICY_CALL_SENDERS to
                (savedPolicy?.priorityCallSenders?.toString() ?: "-1"),
            DbContract.SettingKeys.DND_PREVIOUS_POLICY_MSG_SENDERS to
                (savedPolicy?.priorityMessageSenders?.toString() ?: "-1"),
            DbContract.SettingKeys.DND_PREVIOUS_POLICY_SUPPRESSED to
                (savedPolicy?.suppressedVisualEffects?.toString() ?: "-1"),
        )
        DndSyncController.reconcile(
            settings = savedSettings,
            hasPolicyAccess = state.policyAccess,
            currentFilter = state.filter,
            currentPolicy = state.policy,
            persistPreviousState = { filter, policy ->
                state.previousFilter = filter.toString()
                state.previousPolicy = policy
            },
            clearPreviousState = {
                state.previousFilter = DndSyncController.NO_PREVIOUS_FILTER.toString()
                state.previousPolicy = null
            },
            setNotificationPolicy = {
                val snapshot = DndSyncController.DndPolicySnapshot.from(it)
                state.appliedPolicies.add(snapshot)
                state.policy = snapshot
            },
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
        var previousPolicy: DndSyncController.DndPolicySnapshot? = null,
        val policyAccess: Boolean = true,
    ) {
        var policy: DndSyncController.DndPolicySnapshot = originalPolicy
        val appliedFilters = mutableListOf<Int>()
        val appliedPolicies = mutableListOf<DndSyncController.DndPolicySnapshot>()

        companion object {
            val originalPolicy = DndSyncController.DndPolicySnapshot(
                priorityCategories = NotificationManager.Policy.PRIORITY_CATEGORY_EVENTS,
                priorityCallSenders = NotificationManager.Policy.PRIORITY_SENDERS_CONTACTS,
                priorityMessageSenders = NotificationManager.Policy.PRIORITY_SENDERS_STARRED,
                suppressedVisualEffects = 0x20,
            )
        }
    }
}

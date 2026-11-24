package com.wepr.callguard

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CallGateWidgetStateTest {
    private val now = 1_800_000_000_000L

    @Test
    fun resolvesEachToggleAndTheEffectiveStatus() {
        val keys = DbContract.SettingKeys
        val normal = CallGateWidgetState.from(emptyMap(), now)
        assertEquals(CallGateWidgetState.Mode.NORMAL, normal.mode)
        assertFalse(normal.drivingMode)
        assertTrue(normal.whitelistOnly)
        assertFalse(normal.automaticSilence)

        val driving = CallGateWidgetState.from(mapOf(keys.DRIVING_MODE to "true"), now)
        assertEquals(CallGateWidgetState.Mode.DRIVING, driving.mode)
        assertTrue(driving.drivingMode)

        val whitelistSchedule = CallGateWidgetState.from(
            mapOf(keys.AUTOMATIC_SILENCE to "true", keys.ALLOW_ONLY_WHITELIST to "true"),
            now,
        )
        assertEquals(CallGateWidgetState.Mode.WHITELIST, whitelistSchedule.mode)
        assertTrue(whitelistSchedule.whitelistOnly)
        assertTrue(whitelistSchedule.automaticSilence)

        val schedule = CallGateWidgetState.from(
            mapOf(keys.AUTOMATIC_SILENCE to "true", keys.ALLOW_ONLY_WHITELIST to "false"),
            now,
        )
        assertEquals(CallGateWidgetState.Mode.SCHEDULE, schedule.mode)
    }

    @Test
    fun drivingHasStatusPriorityAndQuickOrManualSilenceRemainsVisible() {
        val keys = DbContract.SettingKeys
        val quick = CallGateWidgetState.from(
            mapOf(keys.QUICK_SILENCE_UNTIL to (now + 3_600_000).toString()),
            now,
        )
        assertEquals(CallGateWidgetState.Mode.QUICK_SILENCE, quick.mode)
        assertEquals(now + 3_600_000, quick.quickSilenceUntilMillis)

        assertEquals(
            CallGateWidgetState.Mode.QUICK_SILENCE,
            CallGateWidgetState.from(mapOf(keys.MANUAL_SILENCE_ENABLED to "true"), now).mode,
        )
        assertEquals(
            CallGateWidgetState.Mode.DRIVING,
            CallGateWidgetState.from(
                mapOf(
                    keys.DRIVING_MODE to "true",
                    keys.AUTOMATIC_SILENCE to "true",
                    keys.ALLOW_ONLY_WHITELIST to "true",
                ),
                now,
            ).mode,
        )
    }

    @Test
    fun everyActionFlipsOnlyItsOwnAppSettingsFlag() {
        val keys = DbContract.SettingKeys
        val cases = listOf(
            CallGateWidgetAction.TOGGLE_DRIVING to keys.DRIVING_MODE,
            CallGateWidgetAction.TOGGLE_WHITELIST to keys.ALLOW_ONLY_WHITELIST,
            CallGateWidgetAction.TOGGLE_SCHEDULE to keys.AUTOMATIC_SILENCE,
        )
        cases.forEach { (action, key) ->
            val changes = action.changes(
                mapOf(
                    keys.DRIVING_MODE to "false",
                    keys.ALLOW_ONLY_WHITELIST to "false",
                    keys.AUTOMATIC_SILENCE to "false",
                    keys.QUICK_SILENCE_UNTIL to (now + 1_000).toString(),
                ),
                now,
            )
            assertEquals(mapOf(key to "true"), changes)
            assertEquals(mapOf(key to "false"), action.changes(mapOf(key to "true"), now))
        }
        assertEquals(
            mapOf(keys.ALLOW_ONLY_WHITELIST to "false"),
            CallGateWidgetAction.TOGGLE_WHITELIST.changes(emptyMap(), now),
        )
    }

    @Test
    fun widgetHasThreeCompactActionsAndLocalizedCopy() {
        val resources = locateAndroidResources()
        val requiredStrings = setOf(
            "widget_brand",
            "widget_status_normal",
            "widget_status_driving",
            "widget_status_whitelist",
            "widget_status_schedule",
            "widget_action_driving",
            "widget_action_whitelist",
            "widget_action_schedule",
            "widget_mode_on",
            "widget_mode_off",
            "widget_dnd_permission_hint",
            "widget_action_failed",
        )
        listOf("values", "values-uk").forEach { directory ->
            val file = File(resources, "$directory/strings.xml")
            val nodes = DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(file)
                .getElementsByTagName("string")
            val names = (0 until nodes.length).map {
                nodes.item(it).attributes.getNamedItem("name").nodeValue
            }.toSet()
            assertTrue("Missing strings in $directory: ${requiredStrings - names}", names.containsAll(requiredStrings))
        }

        val layout = File(resources, "layout/widget_callgate_4x1.xml").readText()
        assertEquals(3, Regex("android:id=\\\"@\\+id/widget_action_").findAll(layout).count())
        assertTrue(layout.contains("android:layout_height=\"38dp\""))
        val widgetInfo = File(resources, "xml/callgate_widget_info.xml").readText()
        assertTrue(widgetInfo.contains("android:minHeight=\"48dp\""))
        assertTrue(widgetInfo.contains("android:targetCellWidth=\"4\""))
        assertTrue(widgetInfo.contains("android:targetCellHeight=\"1\""))
    }

    private fun locateAndroidResources(): File {
        var directory: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (directory != null) {
            val moduleResources = File(directory, "src/main/res")
            if (File(moduleResources, "values/strings.xml").isFile) return moduleResources
            val repositoryResources = File(directory, "android/app/src/main/res")
            if (File(repositoryResources, "values/strings.xml").isFile) return repositoryResources
            directory = directory.parentFile
        }
        error("Could not locate Android string resources")
    }
}

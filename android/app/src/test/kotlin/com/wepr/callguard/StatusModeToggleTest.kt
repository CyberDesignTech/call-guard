package com.wepr.callguard

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StatusModeToggleTest {
    @Test
    fun protectionToggleInvertsStateAndSelectsOppositeActionLabel() {
        val toggle = StatusModeToggle.PROTECTION

        assertEquals(DbContract.SettingKeys.PROTECTION_ENABLED, toggle.settingKey)
        assertTrue(toggle.defaultValue)
        assertFalse(toggle.nextValue(true))
        assertTrue(toggle.nextValue(false))
        assertEquals(R.string.status_action_enable_protection, toggle.actionLabelRes(false))
        assertEquals(R.string.status_action_disable_protection, toggle.actionLabelRes(true))
    }

    @Test
    fun drivingToggleInvertsStateAndSelectsOppositeActionLabel() {
        val toggle = StatusModeToggle.DRIVING

        assertEquals(DbContract.SettingKeys.DRIVING_MODE, toggle.settingKey)
        assertFalse(toggle.defaultValue)
        assertTrue(toggle.nextValue(false))
        assertFalse(toggle.nextValue(true))
        assertEquals(R.string.status_action_enable_driving, toggle.actionLabelRes(false))
        assertEquals(R.string.status_action_disable_driving, toggle.actionLabelRes(true))
    }

    @Test
    fun toggleActionsAndPendingIntentRequestCodesDoNotConflict() {
        assertNotEquals(StatusModeToggle.PROTECTION.action, StatusModeToggle.DRIVING.action)
        assertNotEquals(
            StatusModeToggle.PROTECTION.requestCode,
            StatusModeToggle.DRIVING.requestCode,
        )
        assertEquals(
            StatusModeToggle.PROTECTION,
            StatusModeToggle.fromAction(StatusModeToggle.PROTECTION.action),
        )
        assertEquals(
            StatusModeToggle.DRIVING,
            StatusModeToggle.fromAction(StatusModeToggle.DRIVING.action),
        )
        assertNull(StatusModeToggle.fromAction("com.example.EXTERNAL_ACTION"))
    }

    @Test
    fun notificationActionLabelsExistForEveryAndroidLocale() {
        val requiredNames = setOf(
            "status_action_enable_protection",
            "status_action_disable_protection",
            "status_action_enable_driving",
            "status_action_disable_driving",
        )
        val resourceRoot = locateAndroidResources()
        val localeDirectories = listOf(
            "values",
            "values-uk",
            "values-pl",
            "values-de",
            "values-es",
            "values-fr",
        )

        localeDirectories.forEach { localeDirectory ->
            val stringsFile = File(resourceRoot, "$localeDirectory/strings.xml")
            assertTrue("Missing $stringsFile", stringsFile.isFile)
            val document = DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(stringsFile)
            val nodes = document.getElementsByTagName("string")
            val strings = (0 until nodes.length).associate { index ->
                val node = nodes.item(index)
                node.attributes.getNamedItem("name").nodeValue to node.textContent.trim()
            }

            requiredNames.forEach { name ->
                assertNotNull("$localeDirectory is missing $name", strings[name])
                assertFalse("$localeDirectory has an empty $name", strings[name].isNullOrBlank())
            }
        }
    }

    private fun locateAndroidResources(): File {
        var directory: File? =
            File(System.getProperty("user.dir") ?: ".").absoluteFile
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

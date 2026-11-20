package com.wepr.callguard.call_guard

/** Shared status-notification action metadata and pure toggle behavior. */
internal enum class StatusModeToggle(
    val action: String,
    val settingKey: String,
    val defaultValue: Boolean,
    val requestCode: Int,
    val enableLabelRes: Int,
    val disableLabelRes: Int,
    val logLabel: String,
) {
    PROTECTION(
        action = "com.wepr.callguard.action.STATUS_TOGGLE_PROTECTION",
        settingKey = DbContract.SettingKeys.PROTECTION_ENABLED,
        defaultValue = true,
        requestCode = 0x43474155,
        enableLabelRes = R.string.status_action_enable_protection,
        disableLabelRes = R.string.status_action_disable_protection,
        logLabel = "protection",
    ),
    DRIVING(
        action = "com.wepr.callguard.action.STATUS_TOGGLE_DRIVING",
        settingKey = DbContract.SettingKeys.DRIVING_MODE,
        defaultValue = false,
        requestCode = 0x43474156,
        enableLabelRes = R.string.status_action_enable_driving,
        disableLabelRes = R.string.status_action_disable_driving,
        logLabel = "driving mode",
    ),
    ;

    fun nextValue(currentValue: Boolean): Boolean = !currentValue

    fun actionLabelRes(currentValue: Boolean): Int =
        if (currentValue) disableLabelRes else enableLabelRes

    companion object {
        fun fromAction(action: String?): StatusModeToggle? =
            entries.firstOrNull { it.action == action }
    }
}

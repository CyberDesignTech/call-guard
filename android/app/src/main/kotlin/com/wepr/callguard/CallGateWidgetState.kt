package com.wepr.callguard

/** Pure widget mode resolution and mutations, shared by the provider and unit tests. */
internal data class CallGateWidgetState(
    val mode: Mode,
    val drivingMode: Boolean,
    val whitelistOnly: Boolean,
    val automaticSilence: Boolean,
    val quickSilenceUntilMillis: Long? = null,
) {
    enum class Mode { NORMAL, QUICK_SILENCE, DRIVING, WHITELIST, SCHEDULE }

    companion object {
        fun quickSilenceActive(settings: Map<String, String>, nowMillis: Long): Boolean =
            settings[DbContract.SettingKeys.QUICK_SILENCE_UNTIL]
                ?.toLongOrNull()
                ?.let { it > nowMillis }
                ?: false

        fun from(settings: Map<String, String>, nowMillis: Long): CallGateWidgetState {
            fun setting(key: String, fallback: Boolean = false): Boolean =
                settings[key]?.toBooleanStrictOrNull() ?: fallback

            val drivingMode = setting(DbContract.SettingKeys.DRIVING_MODE)
            val whitelistOnly = setting(DbContract.SettingKeys.ALLOW_ONLY_WHITELIST, true)
            val automaticSilence = setting(DbContract.SettingKeys.AUTOMATIC_SILENCE)
            val quickUntil = settings[DbContract.SettingKeys.QUICK_SILENCE_UNTIL]
                ?.toLongOrNull()
                ?.takeIf { it > nowMillis }
            val manualSilence = listOf(
                DbContract.SettingKeys.MANUAL_SILENCE_ENABLED,
                DbContract.SettingKeys.MANUAL_SILENCE,
                DbContract.SettingKeys.SILENCE_MANUAL,
            ).any { settings[it]?.toBooleanStrictOrNull() == true }

            val mode = when {
                drivingMode -> Mode.DRIVING
                quickUntil != null || manualSilence -> Mode.QUICK_SILENCE
                automaticSilence && whitelistOnly -> Mode.WHITELIST
                automaticSilence -> Mode.SCHEDULE
                else -> Mode.NORMAL
            }
            return CallGateWidgetState(
                mode = mode,
                drivingMode = drivingMode,
                whitelistOnly = whitelistOnly,
                automaticSilence = automaticSilence,
                quickSilenceUntilMillis = quickUntil,
            )
        }
    }
}

internal enum class CallGateWidgetAction {
    TOGGLE_DRIVING,
    TOGGLE_WHITELIST,
    TOGGLE_SCHEDULE,
    ;

    /** Changes only the corresponding persistent mode; unrelated preferences stay intact. */
    fun changes(settings: Map<String, String>, @Suppress("UNUSED_PARAMETER") nowMillis: Long): Map<String, String> {
        val key = when (this) {
            TOGGLE_DRIVING -> DbContract.SettingKeys.DRIVING_MODE
            TOGGLE_WHITELIST -> DbContract.SettingKeys.ALLOW_ONLY_WHITELIST
            TOGGLE_SCHEDULE -> DbContract.SettingKeys.AUTOMATIC_SILENCE
        }
        val currentValue = settings[key]?.toBooleanStrictOrNull()
            ?: (key == DbContract.SettingKeys.ALLOW_ONLY_WHITELIST)
        return mapOf(key to (!currentValue).toString())
    }
}

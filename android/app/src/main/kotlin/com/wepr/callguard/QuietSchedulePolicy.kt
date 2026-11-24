package com.wepr.callguard

import java.util.Calendar

/** Shared schedule calculation for call filtering and Android DND synchronization. */
internal object QuietSchedulePolicy {
    fun isWithin(settings: Map<String, String>, calendar: Calendar): Boolean {
        val weekdays = weekdays(settings)
        if (weekdays.isEmpty()) return false

        val start = settings.intSetting(
            DbContract.SettingKeys.SILENCE_START_MINUTE,
            DEFAULT_START_MINUTE,
        ).coerceIn(0, 1439)
        val end = settings.intSetting(
            DbContract.SettingKeys.SILENCE_END_MINUTE,
            DEFAULT_END_MINUTE,
        ).coerceIn(0, 1439)
        val minuteOfDay = calendar.get(Calendar.HOUR_OF_DAY) * 60 +
            calendar.get(Calendar.MINUTE)
        val isoWeekday = isoWeekday(calendar)

        if (start == end) return isoWeekday in weekdays
        if (start < end) return isoWeekday in weekdays && minuteOfDay in start until end
        if (minuteOfDay >= start) return isoWeekday in weekdays
        if (minuteOfDay < end) {
            val previousWeekday = if (isoWeekday == 1) 7 else isoWeekday - 1
            return previousWeekday in weekdays
        }
        return false
    }

    /** Finds the next local-time schedule edge that actually changes active state. */
    fun nextTransitionAtMillis(settings: Map<String, String>, now: Calendar): Long? {
        val start = settings.intSetting(
            DbContract.SettingKeys.SILENCE_START_MINUTE,
            DEFAULT_START_MINUTE,
        ).coerceIn(0, 1439)
        val end = settings.intSetting(
            DbContract.SettingKeys.SILENCE_END_MINUTE,
            DEFAULT_END_MINUTE,
        ).coerceIn(0, 1439)
        val boundaryMinutes = if (start == end) listOf(start) else listOf(start, end)
        val candidates = mutableSetOf<Long>()

        for (dayOffset in 0..8) {
            for (minute in boundaryMinutes) {
                val candidate = (now.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_YEAR, dayOffset)
                    set(Calendar.HOUR_OF_DAY, minute / 60)
                    set(Calendar.MINUTE, minute % 60)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val candidateTime = candidate.timeInMillis
                if (candidateTime <= now.timeInMillis) continue

                val before = (candidate.clone() as Calendar).apply {
                    add(Calendar.MILLISECOND, -1)
                }
                val after = (candidate.clone() as Calendar).apply {
                    add(Calendar.MILLISECOND, 1)
                }
                if (isWithin(settings, before) != isWithin(settings, after)) {
                    candidates.add(candidateTime)
                }
            }
        }
        return candidates.minOrNull()
    }

    private fun weekdays(settings: Map<String, String>): Set<Int> =
        settings[DbContract.SettingKeys.SILENCE_WEEKDAYS]
            ?.split(',')
            ?.mapNotNull(String::toIntOrNull)
            ?.filter { it in 1..7 }
            ?.toSet()
            ?: (1..7).toSet()

    private fun isoWeekday(calendar: Calendar): Int =
        ((calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

    private fun Map<String, String>.intSetting(key: String, default: Int): Int =
        this[key]?.toIntOrNull() ?: default

    private const val DEFAULT_START_MINUTE = 22 * 60
    private const val DEFAULT_END_MINUTE = 7 * 60
}

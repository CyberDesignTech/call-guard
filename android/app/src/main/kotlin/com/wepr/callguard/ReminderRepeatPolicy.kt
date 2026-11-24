package com.wepr.callguard

import java.util.Calendar

object ReminderRepeatPolicy {
    fun nextOccurrence(reminder: CallReminderRecord, now: Long = System.currentTimeMillis()): Long? {
        val days = when (reminder.repeatType) {
            "daily" -> 1
            "weekly" -> 7
            "custom" -> reminder.repeatInterval.coerceIn(1, 365)
            else -> return null
        }

        val calendar = Calendar.getInstance().apply { timeInMillis = reminder.remindAt }
        do {
            calendar.add(Calendar.DAY_OF_YEAR, days)
        } while (calendar.timeInMillis <= now)
        return calendar.timeInMillis
    }
}

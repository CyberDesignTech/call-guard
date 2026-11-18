package com.wepr.callguard.call_guard

/** Shared schema of the SQLite database created by Flutter's sqflite helper. */
object DbContract {
    const val DATABASE_NAME = "call_guard.db"
    const val BUSY_TIMEOUT_MS = 3000

    object AppSettings {
        const val TABLE = "app_settings"
        const val KEY = "key"
        const val VALUE = "value"
    }

    object PhoneRules {
        const val TABLE = "phone_rules"
        const val PHONE = "phone"
        const val LABEL = "label"
        const val LIST_TYPE = "list_type"
        const val CREATED_AT = "created_at"
        const val EXPIRES_AT = "expires_at"
        const val WHITE = "white"
        const val BLACK = "black"
    }

    object CountryRules {
        const val TABLE = "country_rules"
        const val ISO_CODE = "iso_code"
        const val DIAL_CODE = "dial_code"
        const val AREA_CODES = "area_codes"
        const val ACTION = "action"
    }

    object OperatorRules {
        const val TABLE = "operator_rules"
        const val ID = "id"
        const val COUNTRY_ISO = "country_iso"
        const val OPERATOR_NAME = "operator_name"
        const val PREFIXES = "prefixes"
        const val ACTION = "action"
    }

    object CallReminders {
        const val TABLE = "call_reminders"
        const val ID = "id"
        const val PHONE = "phone"
        const val CONTACT_NAME = "contact_name"
        const val REMIND_AT = "remind_at"
        const val NOTE = "note"
        const val IS_DONE = "is_done"
        const val REPEAT_TYPE = "repeat_type"
        const val REPEAT_INTERVAL = "repeat_interval"
        const val LAST_FIRED_AT = "last_fired_at"
        const val CREATED_AT = "created_at"
    }

    object CallLogs {
        const val TABLE = "call_logs"
        const val PHONE = "phone"
        const val CONTACT_NAME = "contact_name"
        const val REASON = "reason"
        const val TIMESTAMP = "timestamp"
    }

    object SettingKeys {
        const val PROTECTION_ENABLED = "protection_enabled"
        const val MANUAL_SILENCE_ENABLED = "manual_silence_enabled"
        const val MANUAL_SILENCE = "manual_silence"
        const val SILENCE_MANUAL = "silence_manual"
        const val AUTOMATIC_SILENCE = "automatic_silence"
        const val DRIVING_MODE = "driving_mode"
        const val STATUS_TRAY_ICON_ENABLED = "status_tray_icon_enabled"
        const val STATUS_TRAY_USER_OVERRIDDEN = "status_tray_user_overridden"
        const val STATUS_TRAY_ACTIVATED = "status_tray_activated"
        const val STATUS_TRAY_PERMISSION_PROMPTED = "status_tray_permission_prompted"
        const val LEGACY_STATUS_INDICATOR_ENABLED = "status_indicator_enabled"
        const val SILENCE_START_MINUTE = "silence_start_minute"
        const val SILENCE_END_MINUTE = "silence_end_minute"
        const val SILENCE_WEEKDAYS = "silence_weekdays"
        const val BLOCK_HIDDEN = "block_hidden"
        const val BLOCK_NON_CONTACTS = "block_non_contacts"
        const val BLOCK_INTERNATIONAL = "block_international"
        const val ALLOW_ONLY_WHITELIST = "allow_only_whitelist"
        const val ANSWERING_SCENARIO = "answering_scenario"
        const val ANSWERING_ENABLED = "answering_enabled"
        const val ANSWERING_LOCAL_NOTIFICATION = "answering_local_notification"
        const val ANSWERING_AUTO_REMIND = "answering_auto_remind"
        const val ANSWERING_AUTO_REMIND_MINUTES = "answering_auto_remind_minutes"
        const val ANSWERING_EMERGENCY_REPEAT = "answering_emergency_repeat"
        const val LOCALE = "locale"
    }
}

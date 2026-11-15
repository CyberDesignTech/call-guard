package com.wepr.callguard.call_guard

/** Single source of truth for the Flutter <-> Android MethodChannel bridge. */
object BridgeContract {
    const val CHANNEL_NAME = "com.wepr.callguard/screening"

    object Methods {
        const val CHECK_PERMISSIONS = "checkPermissions"
        const val REQUEST_CALL_SCREENING_ROLE = "requestCallScreeningRole"
        const val OPEN_DEFAULT_APPS_SETTINGS = "openDefaultAppsSettings"
        const val REQUEST_CONTACTS_PERMISSION = "requestContactsPermission"
        const val PICK_CONTACT = "pickContact"
        const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
        const val OPEN_NOTIFICATION_SETTINGS = "openNotificationSettings"
        const val SCHEDULE_REMINDER = "scheduleReminder"
        const val CANCEL_REMINDER = "cancelReminder"
        const val RESTORE_PENDING_REMINDERS = "restorePendingReminders"
        const val OPEN_DIALER = "openDialer"
        const val SIMULATE_CALL = "simulateCall"
        const val CONSUME_PENDING_CALL_JOURNAL = "consumePendingCallJournal"
        const val OPEN_CALL_JOURNAL = "openCallJournal"
        const val OPEN_EXTERNAL_URL = "openExternalUrl"
    }

    object Arguments {
        const val ID = "id"
        const val REMIND_AT = "remindAt"
        const val PHONE_NUMBER = "phoneNumber"
        const val URL = "url"
    }

    object ResultKeys {
        const val VERDICT = "verdict"
        const val REASON = "reason"
        const val PHONE_NUMBER = "phoneNumber"
        const val PERMISSION_REQUIRED = "permissionRequired"
        const val NAME = "name"
        const val PHONE = "phone"
        const val ROLE_AVAILABLE = "roleAvailable"
        const val CALL_SCREENING_ROLE = "callScreeningRole"
        const val READ_CONTACTS = "readContacts"
        const val NOTIFICATIONS_GRANTED = "notificationsGranted"
    }

    object Verdicts {
        const val ALLOW = "ALLOW"
        const val REJECT = "REJECT"
    }

    object Errors {
        const val ACTIVITY_DESTROYED = "ACTIVITY_DESTROYED"
    }

    object Extras {
        const val OPEN_CALL_JOURNAL = "com.wepr.callguard.extra.OPEN_CALL_JOURNAL"
    }
}

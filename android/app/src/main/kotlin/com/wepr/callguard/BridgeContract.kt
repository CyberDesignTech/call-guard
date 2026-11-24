package com.wepr.callguard

/**
 * Single source of truth for the Flutter-to-Android MethodChannel contract.
 *
 * Keeping names and payload keys here prevents silent drift between Dart UI
 * code and the native components that own system permissions and alarms.
 */
object BridgeContract {
    const val CHANNEL_NAME = "com.wepr.callguard/screening"

    object Methods {
        const val CHECK_PERMISSIONS = "checkPermissions"
        const val REQUEST_CALL_SCREENING_ROLE = "requestCallScreeningRole"
        const val OPEN_DEFAULT_APPS_SETTINGS = "openDefaultAppsSettings"
        const val REQUEST_CONTACTS_PERMISSION = "requestContactsPermission"
        const val PICK_CONTACT = "pickContact"
        const val LOOKUP_CONTACT_NAME = "lookupContactName"
        const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"
        const val OPEN_NOTIFICATION_SETTINGS = "openNotificationSettings"
        const val IS_DND_POLICY_ACCESS_GRANTED = "isDndPolicyAccessGranted"
        const val OPEN_DND_POLICY_ACCESS_SETTINGS = "openDndPolicyAccessSettings"
        const val SYNC_DND_STATE = "syncDndState"
        const val UPDATE_STATUS_INDICATOR = "updateStatusIndicator"
        const val SCHEDULE_REMINDER = "scheduleReminder"
        const val CANCEL_REMINDER = "cancelReminder"
        const val RESTORE_PENDING_REMINDERS = "restorePendingReminders"
        const val OPEN_DIALER = "openDialer"
        const val SIMULATE_CALL = "simulateCall"
        const val CONSUME_PENDING_CALL_JOURNAL = "consumePendingCallJournal"
        const val OPEN_CALL_JOURNAL = "openCallJournal"
        const val OPEN_EXTERNAL_URL = "openExternalUrl"
        const val GET_RECENT_CALL_LOG = "getRecentCallLog"
        const val OPEN_CALL_LOG_SETTINGS = "openCallLogSettings"
        const val STATUS_MODES_CHANGED = "statusModesChanged"
        const val CALL_HANDLED = "callHandled"
    }

    object Actions {
        const val STATUS_MODES_CHANGED = "com.wepr.callguard.action.STATUS_MODES_CHANGED"
    }

    object Arguments {
        const val ID = "id"
        const val REMIND_AT = "remindAt"
        const val PHONE_NUMBER = "phoneNumber"
        const val URL = "url"
        const val LIMIT = "limit"
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
        const val PERMISSION_GRANTED = "permissionGranted"
        const val PERMANENTLY_DENIED = "permanentlyDenied"
        const val CALLS = "calls"
        const val NUMBER = "number"
        const val TYPE = "type"
        const val TIMESTAMP = "timestamp"
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

package com.wepr.callguard.call_guard

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.ActivityNotFoundException
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingRoleResult: MethodChannel.Result? = null
    private var pendingContactsResult: MethodChannel.Result? = null
    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingContactPickerResult: MethodChannel.Result? = null
    private var pendingCallLogResult: MethodChannel.Result? = null
    private var pendingCallLogLimit = DEFAULT_CALL_LOG_LIMIT
    private var screeningChannel: MethodChannel? = null
    private var pendingCallJournalOpen = false
    private var statusModesReceiverRegistered = false
    private val statusModesChangedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            screeningChannel?.invokeMethod(BridgeContract.Methods.STATUS_MODES_CHANGED, null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        screeningChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BridgeContract.CHANNEL_NAME,
        ).also { channel ->
            CallScreeningEvents.attach(channel)
            channel.setMethodCallHandler { call, result -> handleScreeningMethod(call, result) }
        }
        captureCallJournalIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureCallJournalIntent(intent)
        dispatchCallJournalRequest()
    }

    override fun onStart() {
        super.onStart()
        if (!statusModesReceiverRegistered) {
            ContextCompat.registerReceiver(
                this,
                statusModesChangedReceiver,
                IntentFilter(BridgeContract.Actions.STATUS_MODES_CHANGED),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            statusModesReceiverRegistered = true
        }
    }

    override fun onStop() {
        if (statusModesReceiverRegistered) {
            unregisterReceiver(statusModesChangedReceiver)
            statusModesReceiverRegistered = false
        }
        super.onStop()
    }

    private fun captureCallJournalIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(BridgeContract.Extras.OPEN_CALL_JOURNAL, false) == true) {
            pendingCallJournalOpen = true
            intent.removeExtra(BridgeContract.Extras.OPEN_CALL_JOURNAL)
        }
    }

    private fun dispatchCallJournalRequest() {
        screeningChannel?.invokeMethod(
            BridgeContract.Methods.OPEN_CALL_JOURNAL,
            null,
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    if (result == true) pendingCallJournalOpen = false
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = Unit

                override fun notImplemented() = Unit
            },
        )
    }

    private fun handleScreeningMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            BridgeContract.Methods.CHECK_PERMISSIONS -> result.success(permissionState())
            BridgeContract.Methods.CONSUME_PENDING_CALL_JOURNAL -> {
                val shouldOpenJournal = pendingCallJournalOpen
                pendingCallJournalOpen = false
                result.success(shouldOpenJournal)
            }
            BridgeContract.Methods.REQUEST_CALL_SCREENING_ROLE -> requestCallScreeningRole(result)
            BridgeContract.Methods.OPEN_DEFAULT_APPS_SETTINGS -> openDefaultAppsSettings(result)
            BridgeContract.Methods.REQUEST_CONTACTS_PERMISSION -> requestContactsPermission(result)
            BridgeContract.Methods.PICK_CONTACT -> pickContact(result)
            BridgeContract.Methods.LOOKUP_CONTACT_NAME -> lookupContactName(call, result)
            BridgeContract.Methods.GET_RECENT_CALL_LOG -> getRecentCallLog(call, result)
            BridgeContract.Methods.OPEN_CALL_LOG_SETTINGS -> openCallLogSettings(result)
            BridgeContract.Methods.REQUEST_NOTIFICATION_PERMISSION ->
                requestNotificationPermission(result)
            BridgeContract.Methods.OPEN_NOTIFICATION_SETTINGS -> openNotificationSettings(result)
            BridgeContract.Methods.IS_DND_POLICY_ACCESS_GRANTED ->
                result.success(DndSyncController.isPolicyAccessGranted(applicationContext))
            BridgeContract.Methods.OPEN_DND_POLICY_ACCESS_SETTINGS ->
                result.success(DndSyncController.openPolicyAccessSettings(applicationContext))
            BridgeContract.Methods.SYNC_DND_STATE -> syncDndState(result)
            BridgeContract.Methods.UPDATE_STATUS_INDICATOR -> updateStatusIndicator(call, result)
            BridgeContract.Methods.SCHEDULE_REMINDER -> scheduleReminder(call, result)
            BridgeContract.Methods.CANCEL_REMINDER -> cancelReminder(call, result)
            BridgeContract.Methods.RESTORE_PENDING_REMINDERS -> restorePendingReminders(result)
            BridgeContract.Methods.OPEN_DIALER -> openDialer(call, result)
            BridgeContract.Methods.OPEN_EXTERNAL_URL -> openExternalUrl(call, result)
            BridgeContract.Methods.SIMULATE_CALL -> simulateCall(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestCallScreeningRole(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("ROLE_UNAVAILABLE", "Call-screening role requires Android 10 or newer", null)
            return
        }

        val roleManager = getSystemService(RoleManager::class.java)
        if (!roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            result.error("ROLE_UNAVAILABLE", "Call-screening role is not available on this device", null)
            return
        }
        if (pendingRoleResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A role request is already in progress", null)
            return
        }

        pendingRoleResult = result
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(
                roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING),
                REQUEST_SCREENING_ROLE,
            )
        } catch (error: Exception) {
            pendingRoleResult = null
            result.error("ROLE_REQUEST_FAILED", error.message, null)
        }
    }

    private fun openDefaultAppsSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))
            result.success(true)
        } catch (settingsError: Exception) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null),
                    ),
                )
                result.success(true)
            } catch (fallbackError: Exception) {
                result.error(
                    "DEFAULT_APPS_SETTINGS_UNAVAILABLE",
                    fallbackError.message ?: settingsError.message,
                    null,
                )
            }
        }
    }

    private fun requestContactsPermission(result: MethodChannel.Result) {
        if (hasContactsPermission()) {
            result.success(permissionState())
            return
        }
        if (pendingContactsResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A contacts permission request is already in progress", null)
            return
        }

        pendingContactsResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), REQUEST_READ_CONTACTS)
    }

    private fun getRecentCallLog(call: MethodCall, result: MethodChannel.Result) {
        val limit = (call.argument<Int>(BridgeContract.Arguments.LIMIT) ?: DEFAULT_CALL_LOG_LIMIT)
            .coerceIn(1, MAX_CALL_LOG_LIMIT)
        if (hasCallLogPermission()) {
            readRecentCallLog(limit, result)
            return
        }
        if (pendingCallLogResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A call-log permission request is already in progress", null)
            return
        }

        val preferences = getSharedPreferences(CALL_LOG_PREFERENCES, MODE_PRIVATE)
        val denialCount = preferences.getInt(CALL_LOG_DENIAL_COUNT, 0)
        if (denialCount > 0 && !shouldShowRequestPermissionRationale(Manifest.permission.READ_CALL_LOG)) {
            result.success(callLogResponse(permissionGranted = false, permanentlyDenied = true))
            return
        }

        pendingCallLogResult = result
        pendingCallLogLimit = limit
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_CALL_LOG),
            REQUEST_READ_CALL_LOG,
        )
    }

    private fun openCallLogSettings(result: MethodChannel.Result) {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
            result.success(true)
        } catch (error: Exception) {
            result.error("CALL_LOG_SETTINGS_UNAVAILABLE", error.message, null)
        }
    }

    private fun readRecentCallLog(limit: Int, result: MethodChannel.Result) {
        simulationExecutor.execute {
            try {
                val calls = mutableListOf<Map<String, Any>>()
                var previousNumber: String? = null
                contentResolver.query(
                    CallLog.Calls.CONTENT_URI,
                    arrayOf(
                        CallLog.Calls.NUMBER,
                        CallLog.Calls.CACHED_NAME,
                        CallLog.Calls.TYPE,
                        CallLog.Calls.DATE,
                    ),
                    null,
                    null,
                    "${CallLog.Calls.DATE} DESC",
                )?.use { cursor ->
                    val numberIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.NUMBER)
                    val nameIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.CACHED_NAME)
                    val typeIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.TYPE)
                    val dateIndex = cursor.getColumnIndexOrThrow(CallLog.Calls.DATE)
                    while (cursor.moveToNext() && calls.size < limit) {
                        val rawNumber = cursor.getString(numberIndex)?.trim().orEmpty()
                        val digits = rawNumber.filter(Char::isDigit)
                        if (digits.isEmpty()) continue
                        val number = if (rawNumber.startsWith("+")) "+$digits" else digits
                        if (number == previousNumber) continue
                        previousNumber = number
                        val type = when (cursor.getInt(typeIndex)) {
                            CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                            CallLog.Calls.MISSED_TYPE -> "missed"
                            CallLog.Calls.REJECTED_TYPE -> "rejected"
                            CallLog.Calls.BLOCKED_TYPE -> "blocked"
                            else -> "incoming"
                        }
                        calls += mapOf(
                            BridgeContract.ResultKeys.NUMBER to number,
                            BridgeContract.ResultKeys.NAME to cursor.getString(nameIndex).orEmpty(),
                            BridgeContract.ResultKeys.TYPE to type,
                            BridgeContract.ResultKeys.TIMESTAMP to cursor.getLong(dateIndex),
                        )
                    }
                }
                runOnUiThread {
                    result.success(
                        callLogResponse(
                            permissionGranted = true,
                            calls = calls,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("CALL_LOG_READ_FAILED", error.message, null)
                }
            }
        }
    }

    private fun callLogResponse(
        permissionGranted: Boolean,
        permanentlyDenied: Boolean = false,
        calls: List<Map<String, Any>> = emptyList(),
    ): Map<String, Any> = mapOf(
        BridgeContract.ResultKeys.PERMISSION_GRANTED to permissionGranted,
        BridgeContract.ResultKeys.PERMANENTLY_DENIED to permanentlyDenied,
        BridgeContract.ResultKeys.CALLS to calls,
    )

    private fun pickContact(result: MethodChannel.Result) {
        if (!hasContactsPermission()) {
            result.success(mapOf(BridgeContract.ResultKeys.PERMISSION_REQUIRED to true))
            return
        }
        if (pendingContactPickerResult != null) {
            result.error("PICKER_IN_PROGRESS", "A contact picker is already open", null)
            return
        }

        pendingContactPickerResult = result
        try {
            startActivityForResult(
                Intent(
                    Intent.ACTION_PICK,
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                ),
                REQUEST_PICK_CONTACT,
            )
        } catch (error: Exception) {
            pendingContactPickerResult = null
            result.error("CONTACT_PICKER_UNAVAILABLE", error.message, null)
        }
    }

    private fun lookupContactName(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>(BridgeContract.Arguments.PHONE_NUMBER)
        if (phoneNumber.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
            return
        }
        simulationExecutor.execute {
            val name = ContactLookup.lookupName(applicationContext, phoneNumber)
            runOnUiThread { result.success(name) }
        }
    }

    private fun readPickedContact(uri: Uri): Map<String, String>? =
        contentResolver.query(
            uri,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
            ),
            null,
            null,
            null,
        )?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val name = cursor.getString(0).orEmpty()
            val rawNumber = cursor.getString(1).orEmpty().trim()
            val digits = rawNumber.filter(Char::isDigit)
            val cleanedPhone = if (rawNumber.startsWith("+") && digits.isNotEmpty()) {
                "+$digits"
            } else {
                digits
            }
            if (cleanedPhone.isBlank()) null else mapOf(
                BridgeContract.ResultKeys.NAME to name,
                BridgeContract.ResultKeys.PHONE to cleanedPhone,
            )
        }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (hasNotificationPermission()) {
            result.success(true)
            return
        }
        if (hasPostNotificationsPermission() &&
            !NotificationManagerCompat.from(this).areNotificationsEnabled()
        ) {
            launchNotificationSettings()
            result.success(false)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            launchNotificationSettings()
            result.success(hasNotificationPermission())
            return
        }
        val preferences = getSharedPreferences(NOTIFICATION_PREFERENCES, MODE_PRIVATE)
        if (preferences.getInt(NOTIFICATION_DENIAL_COUNT, 0) >= MAX_NOTIFICATION_DENIALS) {
            launchNotificationSettings()
            result.success(hasNotificationPermission())
            return
        }
        if (pendingNotificationResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A notification permission request is already in progress", null)
            return
        }

        pendingNotificationResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun openNotificationSettings(result: MethodChannel.Result) {
        if (launchNotificationSettings()) {
            result.success(true)
        } else {
            result.error(
                "NOTIFICATION_SETTINGS_UNAVAILABLE",
                "Could not open notification settings",
                null,
            )
        }
    }

    private fun syncDndState(result: MethodChannel.Result) {
        simulationExecutor.execute {
            try {
                DndSyncController.syncWithActiveModes(applicationContext)
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("DND_SYNC_FAILED", error.message, null)
                }
            }
        }
    }

    private fun updateStatusIndicator(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        val protectionEnabled = call.argument<Boolean>("protectionEnabled") ?: true
        val drivingMode = call.argument<Boolean>("drivingMode") ?: false
        val locale = call.argument<String>("locale")
        CallNotificationHelper.updateStatusIndicator(
            context = applicationContext,
            enabled = enabled,
            protectionEnabled = protectionEnabled,
            drivingMode = drivingMode,
            locale = locale,
        )
        result.success(true)
    }

    private fun launchNotificationSettings(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
        )
        true
    } catch (settingsError: Exception) {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                ),
            )
            true
        } catch (fallbackError: Exception) {
            false
        }
    }

    private fun scheduleReminder(call: MethodCall, result: MethodChannel.Result) {
        val reminderId = call.argument<Int>(BridgeContract.Arguments.ID)
        val remindAt = (call.argument<Number>(BridgeContract.Arguments.REMIND_AT))?.toLong()
        if (reminderId == null || reminderId <= 0 || remindAt == null) {
            result.error("INVALID_ARGUMENT", "A valid id and remindAt timestamp are required", null)
            return
        }
        try {
            CallReminderScheduler.schedule(applicationContext, reminderId, remindAt)
            result.success(true)
        } catch (error: Exception) {
            result.error("REMINDER_SCHEDULE_FAILED", error.message, null)
        }
    }

    private fun cancelReminder(call: MethodCall, result: MethodChannel.Result) {
        val reminderId = call.argument<Int>(BridgeContract.Arguments.ID)
        if (reminderId == null || reminderId <= 0) {
            result.error("INVALID_ARGUMENT", "A valid reminder id is required", null)
            return
        }
        CallReminderScheduler.cancel(applicationContext, reminderId)
        result.success(true)
    }

    private fun restorePendingReminders(result: MethodChannel.Result) {
        simulationExecutor.execute {
            try {
                CallReminderScheduler.restorePending(applicationContext)
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("REMINDER_RESTORE_FAILED", error.message, null)
                }
            }
        }
    }

    private fun openDialer(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>(BridgeContract.Arguments.PHONE_NUMBER)?.trim()
        if (phoneNumber.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
            return
        }
        try {
            startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(phoneNumber)}")))
            result.success(true)
        } catch (error: Exception) {
            result.error("DIALER_UNAVAILABLE", error.message, null)
        }
    }

    private fun openExternalUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>(BridgeContract.Arguments.URL)?.trim()
        if (url.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENT", "url is required", null)
            return
        }
        try {
            if (url.startsWith("market://")) {
                val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                if (marketIntent.resolveActivity(packageManager) == null) {
                    val fallbackUrl = url.replace(
                        "market://details?id=",
                        "https://play.google.com/store/apps/details?id=",
                    )
                    val fallbackIntent = Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fallbackIntent)
                    result.success(false)
                    return
                }
                startActivity(marketIntent)
                result.success(true)
                return
            }
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (error: ActivityNotFoundException) {
            if (url.startsWith("market://")) {
                val fallbackUrl = url.replace(
                    "market://details?id=",
                    "https://play.google.com/store/apps/details?id=",
                )
                try {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(fallbackUrl)).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                    result.success(true)
                    return
                } catch (fallbackError: ActivityNotFoundException) {
                    result.success(false)
                    return
                }
            }
            result.success(false)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun simulateCall(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>(BridgeContract.Arguments.PHONE_NUMBER)
        if (phoneNumber == null) {
            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
            return
        }

        simulationExecutor.execute {
            val verdict = CallRuleEngine(applicationContext).evaluate(phoneNumber)
            runOnUiThread { result.success(verdict.toMap()) }
        }
    }

    private fun permissionState(): Map<String, Boolean> {
        val roleAvailable: Boolean
        val callScreeningRoleHeld: Boolean
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            roleAvailable = roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
            callScreeningRoleHeld = roleAvailable &&
                roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
        } else {
            roleAvailable = false
            callScreeningRoleHeld = false
        }
        return mapOf(
            BridgeContract.ResultKeys.ROLE_AVAILABLE to roleAvailable,
            BridgeContract.ResultKeys.CALL_SCREENING_ROLE to callScreeningRoleHeld,
            BridgeContract.ResultKeys.READ_CONTACTS to hasContactsPermission(),
            BridgeContract.ResultKeys.NOTIFICATIONS_GRANTED to hasNotificationPermission(),
        )
    }

    private fun hasContactsPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasCallLogPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CALL_LOG,
            ) == PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission(): Boolean {
        val appNotificationsEnabled = NotificationManagerCompat.from(this)
            .areNotificationsEnabled()
        return appNotificationsEnabled &&
            hasPostNotificationsPermission() &&
            hasMainChannelsEnabled()
    }

    private fun hasMainChannelsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = getSystemService(NotificationManager::class.java) ?: return true
        return MAIN_NOTIFICATION_CHANNELS.all { channelId ->
            manager.getNotificationChannel(channelId)?.importance !=
                NotificationManager.IMPORTANCE_NONE
        }
    }

    private fun hasPostNotificationsPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    @Deprecated("Deprecated in Android, retained for role activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_CONTACT) {
            val result = pendingContactPickerResult
            pendingContactPickerResult = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                result?.success(null)
            } else {
                try {
                    result?.success(readPickedContact(data.data!!))
                } catch (error: Exception) {
                    result?.error("CONTACT_READ_FAILED", error.message, null)
                }
            }
        } else if (requestCode == REQUEST_SCREENING_ROLE) {
            pendingRoleResult?.success(permissionState())
            pendingRoleResult = null
        }
    }

    @Deprecated("Deprecated in Android, retained for runtime permission results")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_READ_CONTACTS) {
            pendingContactsResult?.success(permissionState())
            pendingContactsResult = null
        } else if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted = hasNotificationPermission()
            val preferences = getSharedPreferences(NOTIFICATION_PREFERENCES, MODE_PRIVATE)
            if (granted) {
                preferences.edit().remove(NOTIFICATION_DENIAL_COUNT).apply()
            } else {
                preferences.edit()
                    .putInt(
                        NOTIFICATION_DENIAL_COUNT,
                        preferences.getInt(NOTIFICATION_DENIAL_COUNT, 0) + 1,
                    )
                    .apply()
            }
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        } else if (requestCode == REQUEST_READ_CALL_LOG) {
            val result = pendingCallLogResult
            val limit = pendingCallLogLimit
            pendingCallLogResult = null
            val preferences = getSharedPreferences(CALL_LOG_PREFERENCES, MODE_PRIVATE)
            if (hasCallLogPermission()) {
                preferences.edit().remove(CALL_LOG_DENIAL_COUNT).apply()
                if (result != null) readRecentCallLog(limit, result)
            } else {
                val denialCount = preferences.getInt(CALL_LOG_DENIAL_COUNT, 0) + 1
                preferences.edit().putInt(CALL_LOG_DENIAL_COUNT, denialCount).apply()
                result?.success(
                    callLogResponse(
                        permissionGranted = false,
                        permanentlyDenied = denialCount >= 2 &&
                            !shouldShowRequestPermissionRationale(Manifest.permission.READ_CALL_LOG),
                    ),
                )
            }
        }
    }

    override fun onDestroy() {
        screeningChannel?.let(CallScreeningEvents::detach)
        failPendingResults()
        super.onDestroy()
    }

    /** Completes any bridge call still waiting for an activity/permission result. */
    private fun failPendingResults() {
        val results = listOf(
            pendingRoleResult,
            pendingContactsResult,
            pendingNotificationResult,
            pendingContactPickerResult,
            pendingCallLogResult,
        )
        pendingRoleResult = null
        pendingContactsResult = null
        pendingNotificationResult = null
        pendingContactPickerResult = null
        pendingCallLogResult = null
        results.forEach { result ->
            runCatching {
                result?.error(
                    BridgeContract.Errors.ACTIVITY_DESTROYED,
                    "The activity was destroyed before the request completed",
                    null,
                )
            }
        }
    }

    private companion object {
        const val REQUEST_SCREENING_ROLE = 8401
        const val REQUEST_READ_CONTACTS = 8402
        const val REQUEST_POST_NOTIFICATIONS = 8403
        const val REQUEST_PICK_CONTACT = 8404
        const val REQUEST_READ_CALL_LOG = 8405
        const val DEFAULT_CALL_LOG_LIMIT = 50
        const val MAX_CALL_LOG_LIMIT = 100
        const val CALL_LOG_PREFERENCES = "call_guard_call_log_permissions"
        const val CALL_LOG_DENIAL_COUNT = "denial_count"
        const val NOTIFICATION_PREFERENCES = "call_guard_notification_permissions"
        const val NOTIFICATION_DENIAL_COUNT = "denial_count"
        const val MAX_NOTIFICATION_DENIALS = 2
        val MAIN_NOTIFICATION_CHANNELS = listOf(
            CallNotificationHelper.MISSED_CALL_CHANNEL_ID,
            CallNotificationHelper.REMINDER_CHANNEL_ID,
        )
        val simulationExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardCallSimulation").apply { isDaemon = true }
        }
    }
}

package com.wepr.callguard.call_guard

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.Settings
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREENING_CHANNEL,
        ).setMethodCallHandler { call, result -> handleScreeningMethod(call, result) }
    }

    private fun handleScreeningMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermissions" -> result.success(permissionState())
            "requestCallScreeningRole" -> requestCallScreeningRole(result)
            "openDefaultAppsSettings" -> openDefaultAppsSettings(result)
            "requestContactsPermission" -> requestContactsPermission(result)
            "pickContact" -> pickContact(result)
            "requestNotificationPermission" -> requestNotificationPermission(result)
            "scheduleReminder" -> scheduleReminder(call, result)
            "cancelReminder" -> cancelReminder(call, result)
            "restorePendingReminders" -> restorePendingReminders(result)
            "openDialer" -> openDialer(call, result)
            "simulateCall" -> simulateCall(call, result)
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

    private fun pickContact(result: MethodChannel.Result) {
        if (!hasContactsPermission()) {
            result.success(mapOf("permissionRequired" to true))
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
            if (cleanedPhone.isBlank()) null else mapOf("name" to name, "phone" to cleanedPhone)
        }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || hasNotificationPermission()) {
            result.success(true)
            return
        }
        if (pendingNotificationResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A notification permission request is already in progress", null)
            return
        }

        pendingNotificationResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun scheduleReminder(call: MethodCall, result: MethodChannel.Result) {
        val reminderId = call.argument<Int>("id")
        val remindAt = (call.argument<Number>("remindAt"))?.toLong()
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
        val reminderId = call.argument<Int>("id")
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
        val phoneNumber = call.argument<String>("phoneNumber")?.trim()
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

    private fun simulateCall(call: MethodCall, result: MethodChannel.Result) {
        val phoneNumber = call.argument<String>("phoneNumber")
        if (phoneNumber == null) {
            result.error("INVALID_ARGUMENT", "phoneNumber is required", null)
            return
        }

        simulationExecutor.execute {
            val verdict = CallRuleEngine(applicationContext).evaluateAndRecord(phoneNumber)
            runOnUiThread { result.success(verdict.toMap()) }
        }
    }

    private fun permissionState(): Map<String, Boolean> {
        val roleManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            getSystemService(RoleManager::class.java)
        } else {
            null
        }
        val roleAvailable = roleManager?.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) == true
        return mapOf(
            "roleAvailable" to roleAvailable,
            "callScreeningRole" to (
                roleAvailable && roleManager?.isRoleHeld(RoleManager.ROLE_CALL_SCREENING) == true
            ),
            "readContacts" to hasContactsPermission(),
        )
    }

    private fun hasContactsPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

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
            pendingNotificationResult?.success(hasNotificationPermission())
            pendingNotificationResult = null
        }
    }

    private companion object {
        const val SCREENING_CHANNEL = "com.wepr.callguard/screening"
        const val REQUEST_SCREENING_ROLE = 8401
        const val REQUEST_READ_CONTACTS = 8402
        const val REQUEST_POST_NOTIFICATIONS = 8403
        const val REQUEST_PICK_CONTACT = 8404
        val simulationExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardCallSimulation").apply { isDaemon = true }
        }
    }
}

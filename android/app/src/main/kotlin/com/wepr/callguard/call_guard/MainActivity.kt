package com.wepr.callguard.call_guard

import android.Manifest
import android.app.role.RoleManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var pendingRoleResult: MethodChannel.Result? = null
    private var pendingContactsResult: MethodChannel.Result? = null

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
            "requestContactsPermission" -> requestContactsPermission(result)
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
        if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            result.success(permissionState())
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

    @Deprecated("Deprecated in Android, retained for role activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_SCREENING_ROLE) {
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
        }
    }

    private companion object {
        const val SCREENING_CHANNEL = "com.wepr.callguard/screening"
        const val REQUEST_SCREENING_ROLE = 8401
        const val REQUEST_READ_CONTACTS = 8402
        val simulationExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardCallSimulation").apply { isDaemon = true }
        }
    }
}

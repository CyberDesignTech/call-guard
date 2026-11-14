package com.wepr.callguard.call_guard

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

class CallGuardScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart.orEmpty()
        executor.execute {
            val ruleEngine = CallRuleEngine(applicationContext)
            var verdict = ruleEngine.evaluate(phoneNumber)
            if (OptionalAnsweringModule.shouldRejectUnknownCall(
                    applicationContext,
                    phoneNumber,
                    verdict,
                )
            ) {
                verdict = verdict.copy(allowed = false, reason = "not_in_contacts")
            }
            if (!verdict.allowed) {
                val handledByOptionalModule = OptionalAnsweringModule.handleRejectedCall(
                    applicationContext,
                    verdict.phoneNumber,
                    verdict.reason,
                )
                if (!handledByOptionalModule) {
                    ruleEngine.recordCallLog(verdict.phoneNumber, verdict.reason)
                }
            }
            val response = CallResponse.Builder().apply {
                if (!verdict.allowed) {
                    setDisallowCall(true)
                    setRejectCall(true)
                    setSkipCallLog(false)
                    setSkipNotification(true)
                }
            }.build()

            mainHandler.post {
                try {
                    respondToCall(callDetails, response)
                } catch (error: Exception) {
                    Log.e(TAG, "Could not return the call-screening response", error)
                }
            }
        }
    }

    private companion object {
        const val TAG = "CallGuardScreening"
        val mainHandler = Handler(Looper.getMainLooper())
        val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardScreeningWorker").apply { isDaemon = true }
        }
    }
}

package com.wepr.callguard.call_guard

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.os.Build
import java.util.concurrent.Executors

class CallGuardScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            callDetails.callDirection != Call.Details.DIRECTION_INCOMING
        ) {
            return
        }
        val phoneNumber = callDetails.handle?.schemeSpecificPart.orEmpty()
        executor.execute {
            val appContext = applicationContext
            // One settings snapshot covers both the rule engine and the answering module.
            val settings = runCatching {
                CallGuardDatabase.readSettings(appContext)
            }.getOrNull()
            val ruleEngine = CallRuleEngine(appContext)
            var verdict = ruleEngine.evaluate(phoneNumber, settings)
            if (OptionalAnsweringModule.shouldRejectUnknownCall(
                    appContext,
                    phoneNumber,
                    verdict,
                    settings,
                )
            ) {
                verdict = verdict.copy(
                    allowed = false,
                    reason = "not_in_contacts",
                    phoneNumber = if (
                        PhoneNumbers.isHidden(phoneNumber) ||
                        phoneNumber.equals(PhoneNumbers.HIDDEN_NUMBER, ignoreCase = true)
                    ) {
                        PhoneNumbers.HIDDEN_NUMBER
                    } else {
                        verdict.phoneNumber
                    },
                )
            }
            if (!verdict.allowed) {
                runCatching {
                    OptionalAnsweringModule.handleRejectedCall(
                        appContext,
                        verdict.phoneNumber,
                        verdict.reason,
                        settings,
                    )
                }.onFailure {
                    Log.e(TAG, "Could not process callback-assistant notification", it)
                }
                // The service owns rejection logging so every blocked call is recorded once.
                ruleEngine.recordCallLog(
                    verdict.phoneNumber,
                    verdict.reason,
                    ContactLookup.lookupName(appContext, phoneNumber),
                )
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
                CallScreeningEvents.notifyCallHandled()
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

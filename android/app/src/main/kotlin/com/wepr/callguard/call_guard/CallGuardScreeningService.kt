package com.wepr.callguard.call_guard

import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.os.PowerManager
import java.util.concurrent.Executors

class CallGuardScreeningService : CallScreeningService() {
    override fun onScreenCall(callDetails: Call.Details) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            callDetails.callDirection != Call.Details.DIRECTION_INCOMING
        ) {
            return
        }
        val phoneNumber = callDetails.handle?.schemeSpecificPart.orEmpty()
        val wakeLock = acquireWakeLock()
        executor.execute {
            val appContext = applicationContext
            // One settings snapshot covers both the rule engine and the answering module.
            val settings = runCatching {
                CallGuardDatabase.readSettings(appContext)
            }.getOrNull()
            val ruleEngine = CallRuleEngine(appContext)
            var verdict = ruleEngine.evaluate(phoneNumber, settings)
            val shouldRejectForAnswering = runCatching {
                OptionalAnsweringModule.shouldRejectUnknownCall(
                    appContext,
                    phoneNumber,
                    verdict,
                    settings,
                )
            }.onFailure {
                Log.e(TAG, "Could not evaluate callback-assistant rule", it)
            }.getOrDefault(false)
            if (shouldRejectForAnswering) {
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
                // Reply first, then do optional notification and SQLite work while holding
                // a short wake lock. This prevents Doze from suspending the worker between
                // the rejected response and its durable call-log insert.
                executor.execute {
                    completePostResponseWork(
                        appContext = appContext,
                        originalPhoneNumber = phoneNumber,
                        verdict = verdict,
                        settings = settings,
                        ruleEngine = ruleEngine,
                        wakeLock = wakeLock,
                    )
                }
            }
        }
    }

    private fun completePostResponseWork(
        appContext: Context,
        originalPhoneNumber: String,
        verdict: CallRuleVerdict,
        settings: Map<String, String>?,
        ruleEngine: CallRuleEngine,
        wakeLock: PowerManager.WakeLock?,
    ) {
        CallScreeningPostResponseWork.complete(
            verdict = verdict,
            onRejectedCall = {
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
            },
            recordCallLog = {
                // Contact lookup is best-effort and must not prevent logging the rejection.
                val contactName = runCatching {
                    ContactLookup.lookupName(appContext, originalPhoneNumber)
                }.onFailure {
                    Log.w(TAG, "Could not look up blocked-call contact name", it)
                }.getOrNull()
                ruleEngine.recordCallLog(verdict.phoneNumber, verdict.reason, contactName)
            },
            notifyCallHandled = { onDelivered ->
                CallScreeningEvents.notifyCallHandled(onDelivered)
            },
            onComplete = { releaseWakeLock(wakeLock) },
        )
    }

    private fun acquireWakeLock(): PowerManager.WakeLock? {
        val wakeLock = runCatching {
            (getSystemService(Context.POWER_SERVICE) as? PowerManager)
                ?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$TAG:Screening")
        }.onFailure {
            Log.w(TAG, "Could not create call-screening wake lock", it)
        }.getOrNull() ?: return null
        runCatching { wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS) }
            .onFailure { Log.w(TAG, "Could not acquire call-screening wake lock", it) }
        return wakeLock
    }

    private fun releaseWakeLock(wakeLock: PowerManager.WakeLock?) {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock.release()
        }.onFailure { Log.w(TAG, "Could not release call-screening wake lock", it) }
    }

    private companion object {
        const val TAG = "CallGuardScreening"
        const val WAKE_LOCK_TIMEOUT_MS = 10_000L
        val mainHandler = Handler(Looper.getMainLooper())
        val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "CallGuardScreeningWorker").apply { isDaemon = true }
        }
    }
}

package com.wepr.callguard.call_guard

import java.util.concurrent.atomic.AtomicBoolean

/** Keeps rejection side effects independent so one optional failure cannot skip the log. */
internal object CallScreeningPostResponseWork {
    /**
     * Runs optional rejection effects independently and releases the WakeLock
     * exactly once after the Flutter/native completion notification.
     */
    fun complete(
        verdict: CallRuleVerdict,
        onRejectedCall: () -> Unit,
        recordCallLog: () -> Unit,
        notifyCallHandled: (onDelivered: () -> Unit) -> Unit,
        onComplete: () -> Unit,
    ) {
        val completionDelivered = AtomicBoolean(false)
        val finish = {
            if (completionDelivered.compareAndSet(false, true)) {
                runCatching(onComplete)
            }
        }

        try {
            if (!verdict.allowed) {
                // Optional answering work must never suppress the required call-log insert.
                runCatching(onRejectedCall)
                runCatching(recordCallLog)
            }
        } finally {
            runCatching { notifyCallHandled(finish) }
                .onFailure { finish() }
        }
    }
}

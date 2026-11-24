package com.wepr.callguard

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** Delivers call-screening lifecycle events to the currently attached Flutter activity. */
object CallScreeningEvents {
    @Volatile
    private var channel: MethodChannel? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(targetChannel: MethodChannel) {
        channel = targetChannel
    }

    fun detach(targetChannel: MethodChannel) {
        if (channel === targetChannel) channel = null
    }

    fun notifyCallHandled(onDelivered: () -> Unit = {}) {
        val targetChannel = channel
        if (targetChannel == null) {
            onDelivered()
            return
        }
        val posted = mainHandler.post {
            try {
                if (channel === targetChannel) {
                    targetChannel.invokeMethod(BridgeContract.Methods.CALL_HANDLED, null)
                }
            } finally {
                onDelivered()
            }
        }
        if (!posted) onDelivered()
    }
}

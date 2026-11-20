package com.wepr.callguard.call_guard

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

    fun notifyCallHandled() {
        val targetChannel = channel ?: return
        mainHandler.post {
            if (channel === targetChannel) {
                targetChannel.invokeMethod(BridgeContract.Methods.CALL_HANDLED, null)
            }
        }
    }
}

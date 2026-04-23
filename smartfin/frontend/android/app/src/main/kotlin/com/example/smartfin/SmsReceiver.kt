package com.example.smartfin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log

/**
 * SmsReceiver
 *
 * Manifest-registered receiver — Android delivers SMS_RECEIVED in all app
 * states (foreground, background, killed) because SMS_RECEIVED is one of
 * the explicit broadcast exceptions on Android 8+.
 *
 * Privacy contract
 * ────────────────
 * - Sender address and message body are NEVER written to Logcat.
 * - Only structural metadata (message count, timestamp) is logged.
 * - No network calls are made here or downstream.
 * - Non-bank messages are dropped in Flutter before reaching storage.
 */
class SmsReceiver : BroadcastReceiver() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) {
            Log.w(TAG, "SMS_RECEIVED broadcast contained no messages")
            return
        }

        val sender    = messages[0].originatingAddress ?: "unknown"
        val body      = messages.joinToString("") { it.messageBody ?: "" }
        val timestamp = messages[0].timestampMillis

        // Log only non-sensitive structural metadata — never sender or body.
        Log.d(TAG, "SMS received | parts=${messages.size} | ts=$timestamp")

        SmsForegroundService.start(context.applicationContext)
        forwardToFlutter(sender, body, timestamp, retryCount = 0)
    }

    private fun forwardToFlutter(
        sender: String,
        body: String,
        timestamp: Long,
        retryCount: Int,
    ) {
        mainHandler.post {
            val sink = SmsEventSink.sink
            when {
                sink != null -> {
                    sink.success(mapOf("sender" to sender, "body" to body, "timestamp" to timestamp))
                    Log.d(TAG, "Forwarded to Flutter | ts=$timestamp")
                }
                retryCount < MAX_RETRIES -> {
                    Log.d(TAG, "Sink not ready, retry ${retryCount + 1}/$MAX_RETRIES")
                    mainHandler.postDelayed(
                        { forwardToFlutter(sender, body, timestamp, retryCount + 1) },
                        RETRY_DELAY_MS,
                    )
                }
                else -> {
                    // Sink never became available — message cannot be delivered.
                    // Body is intentionally not logged here.
                    Log.e(TAG, "Sink unavailable after $MAX_RETRIES retries — message dropped")
                }
            }
        }
    }

    companion object {
        private const val TAG            = "SmsReceiver"
        private const val MAX_RETRIES    = 5
        private const val RETRY_DELAY_MS = 1_000L
    }
}

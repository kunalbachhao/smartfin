package com.example.smartfin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel

/**
 * SmsForegroundService
 *
 * Hosts a headless [FlutterEngine] so the Dart isolate stays alive when the
 * app is backgrounded or killed, ensuring every incoming SMS reaches the
 * classifier and — if bank-related — local storage.
 *
 * Privacy contract
 * ────────────────
 * - No SMS content is logged in this class.
 * - No network calls are initiated here.
 * - The headless engine runs the same main() entrypoint as the UI engine,
 *   which calls SmsPipeline.start() — all processing stays on-device.
 *
 * Lifecycle
 * ─────────
 * App foregrounded  → MainActivity engine owns the sink (set last).
 * App backgrounded  → MainActivity engine cached → sink intact.
 * App killed        → Service survives (START_STICKY) → headless engine
 *                     re-registers the sink → delivery resumes.
 */
class SmsForegroundService : Service() {

    private var headlessEngine: FlutterEngine? = null
    // Tracks the sink registered by this headless engine so we can apply
    // ownership checks in onCancel and onDestroy.
    private var headlessSink: EventChannel.EventSink? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundWithNotification()
        initHeadlessEngine()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        headlessEngine?.destroy()
        headlessEngine = null
        // Only clear the sink if it still belongs to this headless engine.
        // Do not drop a main-activity sink that is still active.
        if (SmsEventSink.sink === headlessSink) {
            SmsEventSink.sink = null
        }
        headlessSink = null
        Log.d(TAG, "Service destroyed")
    }

    // ── Foreground notification ────────────────────────────────────────────

    private fun startForegroundWithNotification() {
        val channelId = "sms_monitor_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "SMS Monitor",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Monitors incoming bank SMS messages" }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
                .setContentTitle("SmartFin")
                .setContentText("Monitoring bank SMS")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("SmartFin")
                .setContentText("Monitoring bank SMS")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .build()
        }

        startForeground(NOTIFICATION_ID, notification)
    }

    // ── Headless Flutter engine ────────────────────────────────────────────

    private fun initHeadlessEngine() {
        val engine = FlutterEngine(applicationContext)

        EventChannel(engine.dartExecutor.binaryMessenger, MainActivity.SMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    headlessSink = sink
                    // Only claim the sink if no other engine (e.g. MainActivity) has
                    // already registered one. UI engine always takes priority.
                    if (SmsEventSink.sink == null) {
                        SmsEventSink.sink = sink
                        Log.d(TAG, "Headless engine sink registered")
                    } else {
                        Log.d(TAG, "Headless engine sink skipped — UI sink already active")
                    }
                }
                override fun onCancel(arguments: Any?) {
                    // Only clear the global sink if it still belongs to this engine.
                    if (SmsEventSink.sink === headlessSink) {
                        SmsEventSink.sink = null
                        Log.d(TAG, "Headless engine sink cleared")
                    }
                    headlessSink = null
                }
            })

        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        headlessEngine = engine
        Log.d(TAG, "Headless Flutter engine started")
    }

    companion object {
        private const val TAG             = "SmsForegroundService"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val intent = Intent(context, SmsForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SmsForegroundService::class.java))
        }
    }
}

package com.example.smartfin

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val SMS_CHANNEL = "com.example.smartfin/sms"
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Start the foreground service so the headless engine is ready
        // before the first SMS arrives, even if the user backgrounds the app.
        SmsForegroundService.start(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The main-activity engine's sink takes priority over the headless
        // engine's sink while the app is in the foreground.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    // UI engine always takes priority — unconditionally overwrite any previously registered headless sink
                    SmsEventSink.sink = sink
                }
                override fun onCancel(arguments: Any?) {
                    // Don't null the sink here — the headless engine's sink
                    // will re-register itself and take over.
                }
            })
    }
}

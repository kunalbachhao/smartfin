package com.example.smartfin

import io.flutter.plugin.common.EventChannel

/**
 * Process-wide holder for the active EventChannel sink.
 *
 * SmsReceiver is instantiated by the Android system (not by us), so it has
 * no reference to the Flutter engine. This singleton bridges that gap:
 * MainActivity writes the sink here when Flutter starts listening, and
 * SmsReceiver reads it when an SMS arrives.
 *
 * Thread-safety: sink access is confined to the main thread.
 * EventChannel.EventSink.success() must be called on the main thread.
 */
object SmsEventSink {
    var sink: EventChannel.EventSink? = null
}

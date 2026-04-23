import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Represents a single incoming SMS message forwarded from Android.
class SmsMessage {
  final String sender;
  final String body;
  final DateTime timestamp;

  const SmsMessage({
    required this.sender,
    required this.body,
    required this.timestamp,
  });

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) {
    return SmsMessage(
      sender:    map['sender']    as String? ?? 'unknown',
      body:      map['body']      as String? ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? 0,
      ),
    );
  }

  /// Intentionally omits [body] to avoid accidentally logging sensitive content.
  @override
  String toString() =>
      'SmsMessage(sender: $sender, timestamp: $timestamp, bodyLength: ${body.length})';
}

/// Thin wrapper around the [EventChannel] that bridges Android SMS events
/// to Flutter.
///
/// Usage:
/// ```dart
/// final sub = SmsService.instance.messages.listen((sms) {
///   print(sms);
/// });
/// // later:
/// sub.cancel();
/// ```
class SmsService {
  SmsService._();
  static final SmsService instance = SmsService._();

  static const _channel = EventChannel('com.example.smartfin/sms');

  /// Cached broadcast stream — created once per app lifecycle.
  Stream<SmsMessage>? _messages;

  /// Broadcast stream of incoming SMS messages.
  ///
  /// Backed by [EventChannel.receiveBroadcastStream], so multiple listeners
  /// are supported and the native listener is active as long as at least one
  /// subscriber exists.
  ///
  /// The stream is cached so [receiveBroadcastStream] is called at most once,
  /// preventing duplicate native subscriptions on repeated getter access.
  Stream<SmsMessage> get messages => _messages ??= _channel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => SmsMessage.fromMap(event as Map<dynamic, dynamic>))
      .handleError((Object error) {
        debugPrint('[SmsService] channel error: $error');
      });
}

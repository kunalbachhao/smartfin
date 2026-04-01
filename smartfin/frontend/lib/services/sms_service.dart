import 'package:another_telephony/telephony.dart';
import 'dart:developer';
import 'sms_parser.dart';
typedef OnTransaction = void Function(Map<String, dynamic> data);
typedef OnStatus = void Function(String status);

class SmsService {
  SmsService._privateConstructor();
  static final SmsService instance = SmsService._privateConstructor();

  final Telephony _telephony = Telephony.instance;

  OnTransaction? _onTransaction;
  OnStatus? _onStatus;

  Future<void> init({
    required OnTransaction onTransaction,
    required OnStatus onStatus,
  }) async {
    _onTransaction = onTransaction;
    _onStatus = onStatus;

    bool? permissionsGranted =
        await _telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != true) {
      _onStatus?.call("❌ SMS Permission Denied");
      return;
    }

    _onStatus?.call("✅ Listening for Bank SMS...");

    _telephony.listenIncomingSms(
      onNewMessage: _handleMessage,
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  void _handleMessage(SmsMessage message) {
    final body = message.body ?? "";
    final sender = message.address ?? "Unknown";

    final tx = SmsParser.tryExtract(body, sender);

    if (tx != null) {
      _onTransaction?.call(tx);
    } else {
      log("No transaction matched");
    }
  }
}

// ✅ Background handler (top-level required)
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  log("Background SMS: ${message.body}");
}
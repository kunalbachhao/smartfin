import 'package:flutter/foundation.dart';
import 'sms_service.dart';
import 'sms_classifier.dart';
import 'sms_parser.dart';
import 'sms_database.dart';
import '../models/sms_transaction.dart';

/// Connects [SmsService] → [SmsClassifier] → [SmsParser] → [SmsDatabase].
///
/// After saving, calls [onTransaction] so the UI layer can update without
/// polling. Register the callback in main.dart after the provider is created:
///
/// ```dart
/// SmsPipeline.instance.onTransaction = financeProvider.prependSmsTransaction;
/// ```
///
/// Privacy contract
/// ────────────────
/// - Non-bank messages are dropped immediately after classification.
/// - Bank messages are stored locally only — no network calls.
/// - Debug logs never include message body, sender address, or counterparty.
class SmsPipeline {
  SmsPipeline._();
  static final SmsPipeline instance = SmsPipeline._();

  /// Called with each successfully parsed and stored [SmsTransaction].
  /// Typically wired to [FinanceProvider.prependSmsTransaction].
  void Function(SmsTransaction)? onTransaction;

  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    SmsService.instance.messages.listen(
      _process,
      onError: (Object e) => debugPrint('[SmsPipeline] stream error: $e'),
    );
  }

  Future<void> _process(SmsMessage sms) async {
    // 0. Reject promotional senders (TRAI DLT -P suffix) before classification.
    if (SmsClassifier.instance.isPromotionalSender(sms.sender)) {
      if (kDebugMode) {
        debugPrint(
          '[SmsPipeline] skipped promotional sender: ${sms.sender}',
        );
      }
      return;
    }

    // 1. Classify — drop non-bank messages immediately.
    if (!SmsClassifier.instance.isBankSms(sms)) return;

    // 2. Parse into a fully structured SmsTransaction.
    final tx = SmsParser.parse(sms);

    // 3. Persist to local SQLite storage.
    final saved = await SmsDatabase.instance.saveTransaction(tx);

    // 4. Notify the UI layer on the main isolate.
    // After an `await`, execution resumes on the main isolate, so calling
    // callback(tx) directly is safe. Using addPostFrameCallback was the bug:
    // when the scheduler is idle (no frame pending), the callback was queued
    // but never executed.
    final callback = onTransaction;
    if (callback != null) {
      callback(tx);
    }

    // 5. Debug log — metadata only, no sensitive content.
    if (kDebugMode) {
      debugPrint(
        '[SmsPipeline] saved id=${saved.id} '
        'type=${saved.type.name} '
        'bank=${saved.bankName} '
        'amount=${saved.amountDisplay} '
        'ts=${saved.timestamp}',
      );
    }
  }
}

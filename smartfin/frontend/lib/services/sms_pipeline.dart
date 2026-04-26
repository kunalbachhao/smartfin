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

  /// Called with each saved [SmsTransaction] that contains a valid account
  /// number, so the UI layer can auto-create the account if needed.
  /// Wired to [FinanceProvider.ensureAccountExists] in main.dart.
  void Function(SmsTransaction)? onAccountDetected;

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
    // Single classify() call covers all gates — promotional, telecom, bank.
    final classification = SmsClassifier.instance.classify(sms);

    // 0. Promotional sender (TRAI DLT -P).
    if (classification.matchedRule == 'promotional') {
      if (kDebugMode) {
        debugPrint(
          '[SmsPipeline] skip promotional  sender=${sms.sender}',
        );
      }
      return;
    }

    // 0b. Telecom service message (recharge, data pack, validity, SIM).
    if (classification.matchedRule == 'telecom') {
      if (kDebugMode) {
        debugPrint(
          '[SmsPipeline] skip telecom-svc  sender=${sms.sender}',
        );
      }
      return;
    }

    // 1. Not a bank/financial message — drop immediately.
    if (!classification.isBankSms) return;

    // 2. Parse into a fully structured SmsTransaction.
    final tx = SmsParser.parse(sms);

    // 3. Persist to local SQLite storage.
    final saved = await SmsDatabase.instance.saveTransaction(tx);

    // 4. Notify the UI layer on the main isolate.
    final callback = onTransaction;
    if (callback != null) {
      callback(tx);
    }

    // 4b. Trigger account auto-creation if a valid account number was parsed.
    if (tx.accountNumber != SmsTransaction.unknown) {
      onAccountDetected?.call(tx);
    }

    // 5. Debug log — metadata only, no sensitive content.
    if (kDebugMode) {
      debugPrint(
        '[SmsPipeline] saved id=${saved.id} '
        'type=${saved.type.name} '
        'bank=${saved.bankName} '
        'amount=${saved.amountDisplay} '
        'rule=${classification.matchedRule} '
        'ts=${saved.timestamp}',
      );
    }
  }
}

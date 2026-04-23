import 'package:flutter/foundation.dart';
import 'sms_service.dart';

/// Result of classifying an SMS message.
class SmsClassification {
  /// Whether this message is bank/transaction-related.
  final bool isBankSms;

  /// Which rule matched first (useful for debugging / logging).
  final String? matchedRule;

  const SmsClassification({required this.isBankSms, this.matchedRule});

  @override
  String toString() => 'SmsClassification(isBankSms: $isBankSms, rule: $matchedRule)';
}

/// Classifies incoming SMS messages as bank/transaction-related or not.
///
/// Classification pipeline (in order):
///
/// 0. **Promotional filter** — Indian TRAI DLT sender IDs ending in `-P`
///    (e.g. `AD-60022-P`, `VK-12345-P`) are rejected immediately before any
///    further checks. Transactional (`-T`) and Service (`-S`) senders pass.
///
/// 1. **Sender pattern** — Indian banks use 6-character alphanumeric sender
///    IDs (e.g. HDFCBK, SBIINB, ICICIB). Matching the sender alone is a
///    strong signal with very low false-positive rate.
///
/// 2. **Body keywords** — catches messages from senders not in the list
///    (e.g. new banks, payment apps) as long as the body contains
///    transaction vocabulary.
///
/// Both checks are case-insensitive.
class SmsClassifier {
  SmsClassifier._();
  static final SmsClassifier instance = SmsClassifier._();

  // ── Promotional sender pattern (TRAI DLT format) ───────────────────────────
  //
  // Indian TRAI DLT sender IDs follow the format:
  //   <2-letter-header>-<entity-id>-<category>
  //
  // Category suffixes:
  //   P  → Promotional  — MUST be rejected (ads, offers, marketing)
  //   T  → Transactional — MUST be allowed (bank alerts, OTPs)
  //   S  → Service       — MUST be allowed (service notifications)
  //
  // The regex matches any sender that ends with a hyphen followed by a
  // single uppercase or lowercase 'P' (with no further characters).
  // This is intentionally strict to avoid false positives.
  //
  // Examples rejected:  AD-60022-P  VK-12345-P  JD-ABCDE-P  BZ-99999-P
  // Examples allowed:   AD-HDFCBK-T  VM-SBIINB-T  AD-60022-S  HDFCBK
  static final RegExp _promotionalSenderPattern = RegExp(
    r'^[A-Z]{2}-[A-Z0-9]+-P$',
    caseSensitive: false,
  );

  // ── Sender patterns ────────────────────────────────────────────────────────
  // Indian bank / payment sender IDs. The regex matches the full sender string
  // or any substring, so "VM-HDFCBK" and "HDFCBK" both match "HDFC".
  static final RegExp _senderPattern = RegExp(
    r'HDFC|SBIN|SBINB|ICICI|AXISBK|KOTAKB|PNBSMS|BOIIND|CANBNK|'
    r'UNIONB|INDUSB|YESBNK|IDBIBK|FEDERAL|RBLBNK|SCBNK|CITIBNK|'
    r'PAYTM|PHONEPE|GPAY|AMAZONPAY|MOBIKWIK|FREECHARGE|BHARATPE|'
    r'NETSMS|ALERTS|INFOSMS|BANKSMS',
    caseSensitive: false,
  );

  // ── Body keyword pattern ───────────────────────────────────────────────────
  // Matches common transaction vocabulary found in Indian bank SMS templates.
  // Uses word-boundary-style anchoring where needed to avoid false positives
  // (e.g. "credit" in a marketing email vs "credited" in a bank alert).
  static final RegExp _bodyPattern = RegExp(
    r'\b(credited|debited|debit|credit)\b|'
    r'\b(txn|transaction|transfer)\b|'
    r'\bupi\b|'
    r'\b(a/c|acct|account)\b|'
    r'\b(inr|rs\.?|₹)\s*[\d,]+|'   // currency amount: INR 5,000 / Rs.500 / ₹200
    r'\b(imps|neft|rtgs|upi)\b|'
    r'\b(balance|bal)\b|'
    r'\b(otp)\b|'                    // OTP messages are bank-originated
    r'\b(atm|pos|emi)\b|'
    r'\b(avl bal|available balance)\b|'
    r'\b(payment|paid)\b|'           // payment confirmations
    r'\b(purchase|purchased)\b|'     // card purchase alerts
    r'\bspent\b',                    // "you spent ₹X"
    caseSensitive: false,
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns `true` if [sender] is a TRAI DLT promotional sender ID.
  ///
  /// Promotional senders end with `-P` (e.g. `AD-60022-P`).
  /// This check is exposed so [SmsSyncService] can log the skip reason.
  bool isPromotionalSender(String sender) =>
      _promotionalSenderPattern.hasMatch(sender.trim());

  /// Returns [SmsClassification] for the given [message].
  SmsClassification classify(SmsMessage message) {
    // ── Gate 0: reject promotional senders immediately ─────────────────────
    // This runs before any other check so that promotional messages are never
    // processed even if their body accidentally contains financial keywords.
    if (isPromotionalSender(message.sender)) {
      if (kDebugMode) {
        debugPrint(
          '[SmsClassifier] skipped promotional sender: ${message.sender}',
        );
      }
      return const SmsClassification(
        isBankSms: false,
        matchedRule: 'promotional',
      );
    }

    // ── Gate 1: sender pattern match ───────────────────────────────────────
    // Check sender first — cheapest and most reliable signal.
    if (_senderPattern.hasMatch(message.sender)) {
      return const SmsClassification(isBankSms: true, matchedRule: 'sender');
    }

    // ── Gate 2: body keyword scan ──────────────────────────────────────────
    // Fall back to body keyword scan.
    final match = _bodyPattern.firstMatch(message.body);
    if (match != null) {
      return SmsClassification(
        isBankSms: true,
        matchedRule: 'body:${match.group(0)}',
      );
    }

    return const SmsClassification(isBankSms: false);
  }

  /// Convenience wrapper — returns `true` if the message is bank-related.
  bool isBankSms(SmsMessage message) => classify(message).isBankSms;
}

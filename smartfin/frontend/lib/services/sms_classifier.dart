import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sms_service.dart';

/// Result of classifying an SMS message.
class SmsClassification {
  /// Whether this message is bank/transaction-related.
  final bool isBankSms;

  /// Which rule matched first (useful for debugging / logging).
  final String? matchedRule;

  const SmsClassification({required this.isBankSms, this.matchedRule});

  @override
  String toString() =>
      'SmsClassification(isBankSms: $isBankSms, rule: $matchedRule)';
}

/// Classifies incoming SMS messages as bank/transaction-related or not.
///
/// Classification pipeline (in order):
///
/// 0. **Promotional filter** — TRAI DLT sender IDs ending in `-P` are
///    rejected immediately (e.g. `AD-60022-P`, `VK-12345-P`).
///
/// 1. **Telecom keyword filter** — Message body is checked against the
///    keyword list in `assets/telecom_keywords.txt`. If any keyword is
///    found AND the body does NOT contain a financial transaction keyword,
///    the message is rejected.
///    Safety rule: financial keywords always override the telecom filter.
///
/// 2. **Bank sender pattern** — Known Indian bank / payment sender IDs.
///
/// 3. **Body keyword scan** — Catches messages from unlisted senders that
///    contain transaction vocabulary.
class SmsClassifier {
  SmsClassifier._();
  static final SmsClassifier instance = SmsClassifier._();

  // ── Telecom keyword list (loaded from asset) ───────────────────────────────

  /// Lowercased keyword strings loaded from `assets/telecom_keywords.txt`.
  /// Populated once by [_loadTelecomKeywords]; empty until then.
  static List<String> _telecomKeywords = [];
  static bool _keywordsLoaded = false;

  /// Loads the telecom keyword list from the bundled asset file.
  ///
  /// Call this once at app startup (e.g. in `main()` after
  /// `WidgetsFlutterBinding.ensureInitialized()`).
  /// Subsequent calls are no-ops.
  static Future<void> loadKeywords() async {
    if (_keywordsLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/telecom_keywords.txt');
      _telecomKeywords = raw
          .split('\n')
          .map((line) => line.trim().toLowerCase())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .toList();
      _keywordsLoaded = true;
      if (kDebugMode) {
        debugPrint(
          '[SmsClassifier] loaded ${_telecomKeywords.length} telecom keywords',
        );
      }
    } catch (e) {
      // Asset missing or unreadable — fall back to empty list (no telecom filtering).
      _telecomKeywords = [];
      _keywordsLoaded = true;
      if (kDebugMode) {
        debugPrint('[SmsClassifier] failed to load telecom keywords: $e');
      }
    }
  }

  // ── Gate 0: Promotional sender pattern (TRAI DLT) ─────────────────────────
  //
  // Format: <2-letter-prefix>-<entity-id>-<category>
  // Category P = Promotional → reject.
  // Category T = Transactional, S = Service → allow.
  //
  // Rejected:  AD-60022-P  VK-12345-P  JD-ABCDE-P
  // Allowed:   AD-HDFCBK-T  VM-SBIINB-T  AD-60022-S  HDFCBK
  static final RegExp _promotionalSenderPattern = RegExp(
    r'^[A-Z]{2}-[A-Z0-9]+-P$',
    caseSensitive: false,
  );

  // ── Gate 1c: Financial keyword safety guard ────────────────────────────────
  //
  // If the body contains ANY of these keywords the message is NEVER blocked
  // by the telecom filter, regardless of sender or keyword match.
  //
  // This protects:
  //   - Bank debit/credit alerts
  //   - UPI payment confirmations
  //   - OTP messages from banks
  //   - IMPS/NEFT/RTGS transfer alerts
  static final RegExp _financialSafetyKeywords = RegExp(
    r'\b(?:debited|credited)\b|'
    r'\bupi\b|'
    r'\b(?:imps|neft|rtgs)\b|'
    r'\ba/?c\b|'
    r'\b(?:inr|₹)\s*[\d,]+\s*(?:debited|credited|transferred|sent|received)|'
    r'\brs\.?\s*[\d,]+\s*(?:debited|credited|transferred|sent|received)|'
    r'\b(?:txn|transaction)\b|'
    r'\b(?:a/c|acct)\b|'
    r'\botp\b|'
    r'\b(?:avl\s+bal|available\s+balance)\b',
    caseSensitive: false,
  );

  // ── Gate 2: Bank / payment sender pattern ─────────────────────────────────
  //
  // Known Indian bank and payment app sender IDs.
  // Substring match — "VM-HDFCBK" and "HDFCBK" both match "HDFC".
  static final RegExp _senderPattern = RegExp(
    r'HDFC|SBIN|SBINB|ICICI|AXISBK|KOTAKB|PNBSMS|BOIIND|CANBNK|'
    r'UNIONB|INDUSB|YESBNK|IDBIBK|FEDERAL|RBLBNK|SCBNK|CITIBNK|'
    r'PAYTM|PHONEPE|GPAY|AMAZONPAY|MOBIKWIK|FREECHARGE|BHARATPE|'
    r'NETSMS|ALERTS|INFOSMS|BANKSMS',
    caseSensitive: false,
  );

  // ── Gate 3: Body keyword pattern ──────────────────────────────────────────
  //
  // Catches messages from unlisted senders that contain transaction vocabulary.
  static final RegExp _bodyPattern = RegExp(
    r'\b(credited|debited|debit|credit)\b|'
    r'\b(txn|transaction|transfer)\b|'
    r'\bupi\b|'
    r'\b(a/c|acct|account)\b|'
    r'\b(inr|rs\.?|₹)\s*[\d,]+|'
    r'\b(imps|neft|rtgs|upi)\b|'
    r'\b(balance|bal)\b|'
    r'\b(otp)\b|'
    r'\b(atm|pos|emi)\b|'
    r'\b(avl bal|available balance)\b|'
    r'\b(payment|paid)\b|'
    r'\b(purchase|purchased)\b|'
    r'\bspent\b',
    caseSensitive: false,
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns `true` if [sender] is a TRAI DLT promotional sender ID
  /// (ends with `-P`).
  bool isPromotionalSender(String sender) =>
      _promotionalSenderPattern.hasMatch(sender.trim());

  /// Returns `true` if [message] body matches any keyword from
  /// `assets/telecom_keywords.txt` AND does NOT contain a financial
  /// transaction keyword.
  ///
  /// The check is case-insensitive. Keyword matching uses plain substring
  /// search (no regex) so the keyword file stays simple and human-editable.
  bool isTelecomServiceSms(SmsMessage message) {
    // Safety guard: financial keywords always win — never block.
    if (_financialSafetyKeywords.hasMatch(message.body)) return false;

    // No keywords loaded yet — skip telecom filtering.
    if (_telecomKeywords.isEmpty) return false;

    final bodyLower = message.body.toLowerCase();
    for (final keyword in _telecomKeywords) {
      if (bodyLower.contains(keyword)) return true;
    }
    return false;
  }

  /// Returns the first telecom keyword found in [body], or `null`.
  /// Used only for debug logging.
  String? _matchedTelecomKeyword(String body) {
    final bodyLower = body.toLowerCase();
    for (final keyword in _telecomKeywords) {
      if (bodyLower.contains(keyword)) return keyword;
    }
    return null;
  }

  /// Returns [SmsClassification] for the given [message].
  SmsClassification classify(SmsMessage message) {
    // ── Gate 0: reject promotional senders ────────────────────────────────
    if (isPromotionalSender(message.sender)) {
      if (kDebugMode) {
        debugPrint(
          '[SmsClassifier] skip promotional  sender=${message.sender}',
        );
      }
      return const SmsClassification(
        isBankSms: false,
        matchedRule: 'promotional',
      );
    }

    // ── Gate 1: reject telecom service messages via keyword file ──────────
    if (isTelecomServiceSms(message)) {
      if (kDebugMode) {
        final kw = _matchedTelecomKeyword(message.body) ?? '?';
        debugPrint(
          '[SmsClassifier] skip telecom-svc  sender=${message.sender} '
          'keyword="$kw"',
        );
      }
      return const SmsClassification(
        isBankSms: false,
        matchedRule: 'telecom',
      );
    }

    // ── Gate 2: bank / payment sender match ───────────────────────────────
    if (_senderPattern.hasMatch(message.sender)) {
      return const SmsClassification(isBankSms: true, matchedRule: 'sender');
    }

    // ── Gate 3: body keyword scan ──────────────────────────────────────────
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

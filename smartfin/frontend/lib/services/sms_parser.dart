import '../models/sms_transaction.dart';
import 'sms_service.dart';

/// Parses a bank SMS [SmsMessage] into a structured [SmsTransaction].
///
/// Every extraction is independent — a failure in one field never affects
/// the others. Missing fields are set to [SmsTransaction.unknown].
///
/// Usage:
/// ```dart
/// final tx = SmsParser.parse(smsMessage);
/// ```
class SmsParser {
  SmsParser._();

  /// Parse [message] into an [SmsTransaction].
  /// Always returns a valid object — never throws.
  static SmsTransaction parse(SmsMessage message) {
    final body   = message.body;
    final sender = message.sender;

    final type          = _parseType(body);
    final amount        = _parseAmount(body);
    final amountDisplay = _formatAmount(amount);
    final bankName      = _parseBankName(sender);
    final accountNumber = _parseAccountNumber(body);
    final counterparty  = _parseCounterparty(body);

    return SmsTransaction(
      transactionType: type,
      amount:          amount,
      amountDisplay:   amountDisplay,
      bankName:        bankName,
      sender:          sender,
      accountNumber:   accountNumber,
      counterparty:    counterparty,
      timestamp:       message.timestamp,
      rawSms:          body,
    );
  }

  // ── Transaction type ───────────────────────────────────────────────────────

  static final _otpRe    = RegExp(r'\botp\b',              caseSensitive: false);
  static final _creditRe = RegExp(r'\b(credited|credit)\b', caseSensitive: false);
  static final _debitRe  = RegExp(r'\b(debited|debit)\b',  caseSensitive: false);

  static SmsTransactionType _parseType(String body) {
    if (_otpRe.hasMatch(body))    return SmsTransactionType.otp;
    if (_creditRe.hasMatch(body)) return SmsTransactionType.credit;
    if (_debitRe.hasMatch(body))  return SmsTransactionType.debit;
    return SmsTransactionType.unknown;
  }

  // ── Amount ─────────────────────────────────────────────────────────────────
  // Matches: INR 5,000.50 / Rs.500 / Rs 1,00,000 / ₹200.00 / INR5000
  static final _amountRe = RegExp(
    r'(?:inr|rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static double? _parseAmount(String body) {
    final match = _amountRe.firstMatch(body);
    if (match == null) return null;
    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw);
  }

  /// Format a numeric amount as an Indian-grouped ₹ string, or "Unknown".
  static String _formatAmount(double? amount) {
    if (amount == null) return SmsTransaction.unknown;
    final abs     = amount.abs();
    final parts   = abs.toStringAsFixed(2).split('.');
    final intStr  = parts[0];
    final dec     = parts[1];
    if (intStr.length <= 3) return '₹$intStr.$dec';
    final last3   = intStr.substring(intStr.length - 3);
    final rest    = intStr.substring(0, intStr.length - 3);
    final grouped = rest.replaceAllMapped(
      RegExp(r'\B(?=(\d{2})+(?!\d))'),
      (_) => ',',
    );
    return '₹$grouped,$last3.$dec';
  }

  // ── Bank name ──────────────────────────────────────────────────────────────
  // Maps known sender substrings to human-readable bank names.
  static const _bankMap = <String, String>{
    'HDFC':     'HDFC Bank',
    'SBIN':     'State Bank of India',
    'SBINB':    'State Bank of India',
    'ICICI':    'ICICI Bank',
    'AXISBK':   'Axis Bank',
    'AXIS':     'Axis Bank',
    'KOTAKB':   'Kotak Mahindra Bank',
    'KOTAK':    'Kotak Mahindra Bank',
    'PNBSMS':   'Punjab National Bank',
    'BOIIND':   'Bank of India',
    'CANBNK':   'Canara Bank',
    'UNIONB':   'Union Bank of India',
    'INDUSB':   'IndusInd Bank',
    'YESBNK':   'YES Bank',
    'IDBIBK':   'IDBI Bank',
    'FEDERAL':  'Federal Bank',
    'RBLBNK':   'RBL Bank',
    'SCBNK':    'Standard Chartered',
    'CITIBNK':  'Citibank',
    'PAYTM':    'Paytm',
    'PHONEPE':  'PhonePe',
    'GPAY':     'Google Pay',
    'AMAZONPAY':'Amazon Pay',
    'MOBIKWIK': 'MobiKwik',
    'FREECHARGE':'FreeCharge',
    'BHARATPE': 'BharatPe',
  };

  static String _parseBankName(String sender) {
    final upper = sender.toUpperCase();
    // Longest-match: try longer keys first to avoid "AXIS" matching "AXISBK".
    final sorted = _bankMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sorted) {
      if (upper.contains(key)) return _bankMap[key]!;
    }
    // Fall back to the raw sender (strip common prefixes like "VM-", "AD-").
    final stripped = sender.replaceFirst(RegExp(r'^[A-Z]{2}-', caseSensitive: false), '');
    return stripped.isNotEmpty ? stripped : SmsTransaction.unknown;
  }

  // ── Account number ─────────────────────────────────────────────────────────
  //
  // Matches all common Indian bank SMS account-masking formats.
  // Returns 'XX<digits>' (e.g. 'XX8045') or SmsTransaction.unknown.
  //
  // Pattern priority (first match wins):
  //   P1 — explicit label + optional mask + 4–6 digits
  //        e.g. "A/C XX8045", "Ac XXXXXXXX5666", "Account Number XXXXXX6377",
  //             "a/c no. ****8045", "Acct XX1234", "account no 1234"
  //   P2 — "ending [with/in]" + 4–6 digits
  //        e.g. "card ending 8045", "Ac ending 8045", "ending with 8045"
  //   P3 — mask-only: 2+ X/* immediately before 4–6 digits (no label needed)
  //        e.g. "XXXXXX8045", "****8045", "##8045"
  //   P4 — debit/credit context + optional mask + 4–6 digits
  //        e.g. "debited from a/c 8045", "credited to account 8045"
  //        e.g. "XX8045 debited"
  //
  // Safety: digits must NOT be preceded by a currency symbol/word (amount),
  // OTP, Ref, Txn, IFSC, or followed by a date separator (/).
  // All patterns require 4–6 digits — never bare 4-digit numbers.

  // P1: explicit account label + optional mask + 4–6 digits
  static final _accountP1 = RegExp(
    r'(?:a/?c(?:\s*(?:no\.?|number))?\s*|acct\s*|account\s*(?:no\.?\s*|number\s*)?)'
    r'(?:[xX*#\-]{1,10})?'
    r'(\d{4,6})\b',
    caseSensitive: false,
  );

  // P2: "ending [with/in]" + 4–6 digits
  static final _accountP2 = RegExp(
    r'\bending\s+(?:with\s+|in\s+)?(\d{4,6})\b',
    caseSensitive: false,
  );

  // P3: mask-only (2+ X/* immediately before 4–6 digits)
  static final _accountP3 = RegExp(
    r'\b[xX*#]{2,10}(\d{4,6})\b',
    caseSensitive: false,
  );

  // P4a: debit/credit verb + optional "from/to a/c" + optional mask + 4–6 digits
  static final _accountP4a = RegExp(
    r'(?:debited|credited)\s+(?:from|to)\s+(?:a/?c\s*)?(?:[xX*]{0,6})(\d{4,6})\b',
    caseSensitive: false,
  );

  // P4b: mask + 4–6 digits + debit/credit verb (reverse order)
  static final _accountP4b = RegExp(
    r'\b(?:[xX*]{1,6})(\d{4,6})\s+(?:debited|credited)\b',
    caseSensitive: false,
  );

  // Negative guard: digits that are actually amounts, OTPs, refs, or dates.
  // Used to reject a match when the captured digits are preceded by these.
  static final _accountNegGuard = RegExp(
    r'(?:rs\.?|inr|₹|otp|ref(?:erence)?|txn|ifsc)\s{0,3}$',
    caseSensitive: false,
  );

  static String _parseAccountNumber(String body) {
    // Try each pattern in priority order.
    for (final pattern in [
      _accountP1,
      _accountP2,
      _accountP3,
      _accountP4a,
      _accountP4b,
    ]) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;

      final digits = match.group(1)!;

      // Safety: reject if the text immediately before the match looks like
      // a currency/OTP/ref context (false positive guard).
      final before = body.substring(0, match.start);
      if (_accountNegGuard.hasMatch(before)) continue;

      // Safety: reject if digits are followed by a date separator.
      final afterStart = match.start + match.group(0)!.length;
      if (afterStart < body.length) {
        final nextChar = body[afterStart];
        if (nextChar == '/' || nextChar == '-') continue;
      }

      return 'XX$digits';
    }

    return SmsTransaction.unknown;
  }

  // ── Counterparty (source / destination) ───────────────────────────────────
  // Covers UPI IDs, "to <name>", "from <name>", "by <name>" patterns.
  static final _upiRe = RegExp(
    r'(?:to|from|by|at)\s+([a-zA-Z0-9._@\-]{3,50})',
    caseSensitive: false,
  );

  // UPI VPA pattern: something@something
  static final _vpaRe = RegExp(
    r'\b[\w.\-]+@[\w.\-]+\b',
    caseSensitive: false,
  );

  // Merchant / payee name after "to " or "at " (stops at punctuation)
  static final _merchantRe = RegExp(
    r'(?:paid\s+to|transferred\s+to|sent\s+to|received\s+from)\s+([A-Za-z0-9 &.\-]{2,40}?)(?:\s+on|\s+via|\s+ref|\.|\,|$)',
    caseSensitive: false,
  );

  static String _parseCounterparty(String body) {
    // 1. Prefer explicit UPI VPA (most precise)
    final vpa = _vpaRe.firstMatch(body);
    if (vpa != null) return vpa.group(0)!.trim();

    // 2. "paid to / received from" pattern
    final merchant = _merchantRe.firstMatch(body);
    if (merchant != null) {
      final name = merchant.group(1)?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }

    // 3. Generic "to/from/by/at <token>" pattern
    final generic = _upiRe.firstMatch(body);
    if (generic != null) {
      final name = generic.group(1)?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }

    return SmsTransaction.unknown;
  }
}

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
  // Matches: XX1234 / x-1234 / ending 1234 / a/c 1234 / ac no 1234
  static final _accountRe = RegExp(
    r'(?:a/?c\s*(?:no\.?\s*)?|account\s*(?:no\.?\s*)?|ending\s*|x+[-\s]?)(\d{4,6})',
    caseSensitive: false,
  );

  static String _parseAccountNumber(String body) {
    final match = _accountRe.firstMatch(body);
    if (match == null) return SmsTransaction.unknown;
    return 'XX${match.group(1)}';
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

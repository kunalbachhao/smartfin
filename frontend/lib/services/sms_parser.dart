/// Enhanced SMS Parser for Bank Transaction Detection
/// Supports multiple Indian banks and UPI transaction formats
class SmsParser {
  /// List of known bank sender patterns
  static final Map<String, List<String>> _bankPatterns = {
    'SBI': ['SBI', 'SBIBNK', 'SBIINB', 'SBI CARD'],
    'HDFC': ['HDFC', 'HDFCBK', 'HDFCBANK', 'HDFC-C'],
    'ICICI': ['ICICI', 'ICICBK', 'ICICIB', 'ICICICC'],
    'Axis': ['AXIS', 'AXISBK', 'AXIS BANK'],
    'Kotak': ['KOTAK', 'KOTAKB', 'KOTAKBK'],
    'PNB': ['PNB', 'PNBSMS', 'PNB BANK'],
    'BOB': ['BOB', 'BOIBNK', 'BANKBARODA'],
    'Canara': ['CANARA', 'CNRB', 'CANBNK'],
    'Union': ['UNION', 'UBIN', 'UNIONBK'],
    'IDBI': ['IDBI', 'IDBIBK'],
    'IndusInd': ['INDUS', 'INDUSIND'],
    'Yes Bank': ['YESBNK', 'YESBANK'],
    'Federal': ['FEDERAL', 'FEDBNK'],
    'Indian': ['INDIAN', 'INDBNK'],
    'UPI': ['UPI', 'PAYTM', 'GOOGLEPE', 'PHONEPE', 'AMAZONPE', 'BHIM'],
  };

  /// Transaction keywords for detection
  static final List<String> _debitKeywords = [
    'debited', 'debit', 'dr', 'spent', 'withdrawn', 'withdrawal',
    'paid', 'payment', 'deducted', 'charged', 'transferred from',
    'sent to', 'purchase', ' txn ', 'transaction',
  ];

  static final List<String> _creditKeywords = [
    'credited', 'credit', 'cr', 'received', 'deposited', 'added',
    'refunded', 'cashback', 'transferred to', 'received from',
    'salary', 'income',
  ];

  /// Main extraction method - returns null if not a valid transaction SMS
  static Map<String, dynamic>? tryExtract(String body, String sender) {
    // Check if it's a bank/UPI sender
    final bankName = _detectBank(sender);
    
    // Try to extract transaction details
    final amount = _extractAmount(body);
    final type = _extractType(body);

    if (amount == null || type == null) return null;

    final account = _extractAccount(body);
    final dateTime = _extractDateTime(body) ?? DateTime.now();
    final transactionId = _extractTransactionId(body);

    return {
      "type": type,
      "amount": amount,
      "sender": sender,
      "bankName": bankName,
      "account": account,
      "dateTime": dateTime.toIso8601String(),
      "transactionId": transactionId,
      "rawBody": body,
    };
  }

  /// Detect bank name from sender ID
  static String _detectBank(String sender) {
    final upperSender = sender.toUpperCase();
    
    for (final entry in _bankPatterns.entries) {
      for (final pattern in entry.value) {
        if (upperSender.contains(pattern)) {
          return entry.key;
        }
      }
    }
    
    // Check if it's a number (could be UPI)
    if (RegExp(r'^[+]?[0-9]+$').hasMatch(sender)) {
      return 'Unknown Bank';
    }
    
    return sender;
  }

  /// Extract amount with support for multiple formats
  static double? _extractAmount(String body) {
    // Pattern 1: Standard INR formats (Rs. 1,234.56, INR 1000, ₹500)
    final patterns = [
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      r'(?:Rs\.?|INR|₹)\s*([\d,]+)',
      r'\b(INR|Rs\.?|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      r'amount\s+(?:of\s+)?(?:Rs\.?|INR|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(body);
      if (match != null) {
        final amountStr = match.group(1) ?? match.group(2);
        if (amountStr != null) {
          final cleaned = amountStr.replaceAll(',', '');
          final amount = double.tryParse(cleaned);
          if (amount != null && amount > 0) return amount;
        }
      }
    }
    return null;
  }

  /// Extract transaction type (debit/credit)
  static String? _extractType(String body) {
    final lower = body.toLowerCase();
    
    // Check debit keywords
    for (final keyword in _debitKeywords) {
      if (lower.contains(keyword)) return 'debited';
    }
    
    // Check credit keywords
    for (final keyword in _creditKeywords) {
      if (lower.contains(keyword)) return 'credited';
    }
    
    return null;
  }

  /// Extract account number (last 4 digits)
  static String _extractAccount(String body) {
    // Pattern 1: A/c, Acct, Account followed by digits
    final match1 = RegExp(
      r'(?:A/c|Acct|Account|A/C)[^\d]*(\d{4,})',
      caseSensitive: false,
    ).firstMatch(body);
    
    if (match1 != null) {
      final digits = match1.group(1)!;
      return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
    }

    // Pattern 2: Masked format (****1234, XX1234, **1234)
    final match2 = RegExp(r'[\*Xx]{2,}(\d{4})').firstMatch(body);
    if (match2 != null) return match2.group(1)!;

    // Pattern 3: UPI reference
    final upiMatch = RegExp(r'UPI[\s-]?(\d+)').firstMatch(body);
    if (upiMatch != null) return 'UPI-${upiMatch.group(1)}';

    return '****';
  }

  /// Extract date/time from SMS body if available
  static DateTime? _extractDateTime(String body) {
    // Pattern 1: DD-MM-YYYY or DD/MM/YYYY
    final datePattern1 = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})');
    final match1 = datePattern1.firstMatch(body);
    if (match1 != null) {
      try {
        final day = int.parse(match1.group(1)!);
        final month = int.parse(match1.group(2)!);
        var year = int.parse(match1.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // Pattern 2: Time format HH:MM or HH:MM:SS
    final timePattern = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?');
    final match2 = timePattern.firstMatch(body);
    if (match2 != null) {
      try {
        final now = DateTime.now();
        final hour = int.parse(match2.group(1)!);
        final minute = int.parse(match2.group(2)!);
        return DateTime(now.year, now.month, now.day, hour, minute);
      } catch (_) {}
    }

    return null;
  }

  /// Extract transaction/reference ID
  static String? _extractTransactionId(String body) {
    final patterns = [
      r'(?:Ref|Reference|Txn|Transaction|UPI)[\s#:]*(\d{10,})',
      r'(?:Ref|Reference|Txn|Transaction)[\s#:]*([A-Z0-9]{8,})',
      r'UPI[\s-]?(\d{8,})',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(body);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Check if two transactions are duplicates
  static bool isDuplicate(
    Map<String, dynamic> newTx,
    List<Map<String, dynamic>> existingTxs,
  ) {
    final newAmount = newTx['amount'] as double;
    final newType = newTx['type'] as String;
    final newBank = newTx['bankName'] as String;
    final newAccount = newTx['account'] as String;
    final newId = newTx['transactionId'] as String?;

    for (final existing in existingTxs) {
      // If transaction IDs match, it's a duplicate
      if (newId != null &&
          existing['transactionId'] != null &&
          newId == existing['transactionId']) {
        return true;
      }

      // Check for similar transactions within 5 minutes
      final existingAmount = existing['amount'] as double?;
      final existingType = existing['type'] as String?;
      final existingBank = existing['bankName'] as String?;
      final existingAccount = existing['account'] as String?;

      if (existingAmount == newAmount &&
          existingType == newType &&
          existingBank == newBank &&
          existingAccount == newAccount) {
        // Check time proximity (within 5 minutes)
        final newTime = DateTime.parse(newTx['dateTime'] as String);
        final existingTime = DateTime.parse(existing['dateTime'] as String);
        final diff = newTime.difference(existingTime).abs();
        
        if (diff.inMinutes < 5) return true;
      }
    }
    return false;
  }

  /// Validate if sender is a bank/UPI service
  static bool isBankSender(String sender) {
    final upperSender = sender.toUpperCase();
    
    // Check against known bank patterns
    for (final patterns in _bankPatterns.values) {
      for (final pattern in patterns) {
        if (upperSender.contains(pattern)) return true;
      }
    }
    
    // Check for number-only senders (often UPI)
    if (RegExp(r'^[+]?[0-9]+$').hasMatch(sender)) return true;
    
    // Check for transaction-related keywords in sender
    final txKeywords = ['TXN', 'TRAN', 'PAYMENT', 'BANK', 'UPI'];
    for (final keyword in txKeywords) {
      if (upperSender.contains(keyword)) return true;
    }
    
    return false;
  }
}

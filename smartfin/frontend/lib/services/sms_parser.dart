class SmsParser {
  static Map<String, dynamic>? tryExtract(String body, String sender) {
    final amount = extractAmount(body);
    final type = extractType(body);

    if (amount == null || type == null) return null;

    return {
      "type": type,
      "amount": amount,
      "sender": sender,
      "account": extractAccount(body),
      "time": DateTime.now().toIso8601String(),
    };
  }

  static double? extractAmount(String body) {
    final match = RegExp(
      r'(?:Rs\.?|INR|₹)\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(body);

    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  static String? extractType(String body) {
    final lower = body.toLowerCase();

    if (RegExp(r'\b(debit|debited|dr|spent|withdrawn)\b')
        .hasMatch(lower)) {
      return "debited";
    }

    if (RegExp(r'\b(credit|credited|cr|received|deposited)\b')
        .hasMatch(lower)) {
      return "credited";
    }

    return null;
  }

  static String extractAccount(String body) {
    final match = RegExp(
      r'(?:A/c|Acct|Account)[^\d]*(\d{4})',
      caseSensitive: false,
    ).firstMatch(body);

    if (match != null) return match.group(1)!;

    final fallback = RegExp(r'[\*Xx]{2,}(\d{4})').firstMatch(body);
    if (fallback != null) return fallback.group(1)!;

    if (body.toLowerCase().contains("upi")) return "UPI";

    return "****";
  }
}
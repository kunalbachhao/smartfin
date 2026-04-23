/// Transaction type parsed from an SMS body.
enum SmsTransactionType {
  credit,   // money received / account credited
  debit,    // money sent / account debited
  otp,      // one-time password — not a financial transaction
  unknown,  // could not be determined
}

/// A structured transaction extracted from a bank SMS message.
///
/// Every field that cannot be parsed from the raw SMS is set to [unknown]
/// (the string `"Unknown"`) rather than null, so consumers never need to
/// null-check display fields.
///
/// This model is intentionally decoupled from storage ([BankSmsRecord]) and
/// from the UI layer — it is a pure data class.
class SmsTransaction {
  /// Sentinel value used for any field that could not be extracted.
  static const unknown = 'Unknown';

  /// Credit or Debit (or OTP / Unknown).
  final SmsTransactionType transactionType;

  /// Parsed numeric amount, e.g. `5000.0`.
  /// `null` only when the body contains no recognisable currency figure.
  /// Use [amountDisplay] for a safe display string.
  final double? amount;

  /// Human-readable amount string, e.g. `"₹5,000.00"` or `"Unknown"`.
  final String amountDisplay;

  /// Bank name inferred from the sender ID, e.g. `"HDFC Bank"`.
  /// Falls back to the raw sender string, then [unknown].
  final String bankName;

  /// Raw sender ID as received from Android, e.g. `"VM-HDFCBK"`.
  final String sender;

  /// Last 4 digits of the account number, e.g. `"XX1234"`.
  /// [unknown] if not present in the SMS body.
  final String accountNumber;

  /// Counterparty name or UPI ID — who sent or received the money.
  /// [unknown] if not mentioned in the SMS body.
  final String counterparty;

  /// When the SMS was received (from the PDU timestamp).
  final DateTime timestamp;

  /// The original unmodified SMS body — always preserved for auditability.
  final String rawSms;

  /// SQLite row ID of the corresponding [BankSmsRecord], if this transaction
  /// was sourced from the local SMS database.
  ///
  /// `null` for API-sourced transactions.
  /// Used by [FinanceProvider.removeTransaction] to delete the local record.
  final int? localDbId;

  const SmsTransaction({
    required this.transactionType,
    this.amount,
    required this.amountDisplay,
    required this.bankName,
    required this.sender,
    required this.accountNumber,
    required this.counterparty,
    required this.timestamp,
    required this.rawSms,
    this.localDbId,
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isCredit  => transactionType == SmsTransactionType.credit;
  bool get isDebit   => transactionType == SmsTransactionType.debit;
  bool get isOtp     => transactionType == SmsTransactionType.otp;
  bool get isUnknown => transactionType == SmsTransactionType.unknown;

  // ── Equality & hashing ─────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsTransaction &&
          runtimeType == other.runtimeType &&
          sender == other.sender &&
          timestamp == other.timestamp &&
          rawSms == other.rawSms;

  @override
  int get hashCode => Object.hash(sender, timestamp, rawSms);

  /// Safe for debug logging — never includes rawSms or counterparty.
  @override
  String toString() => 'SmsTransaction('
      'type: ${transactionType.name}, '
      'bank: $bankName, '
      'amount: $amountDisplay, '
      'account: $accountNumber, '
      'ts: $timestamp)';
}

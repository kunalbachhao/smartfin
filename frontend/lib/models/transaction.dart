/// Transaction model for storing and parsing transaction data
class Transaction {
  final String type; // 'credited' or 'debited'
  final double amount;
  final String sender;
  final String accountDigits;
  final DateTime dateTime;
  final String category;
  final String? bankName;
  final String? transactionId;

  Transaction({
    required this.type,
    required this.amount,
    required this.sender,
    required this.accountDigits,
    required this.dateTime,
    required this.category,
    this.bankName,
    this.transactionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'sender': sender,
      'accountDigits': accountDigits,
      'dateTime': dateTime.toIso8601String(),
      'category': category,
      'bankName': bankName,
      'transactionId': transactionId,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      sender: json['sender'] as String,
      accountDigits: json['accountDigits'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      category: json['category'] as String,
      bankName: json['bankName'] as String?,
      transactionId: json['transactionId'] as String?,
    );
  }

  String get formattedAmount {
    return '₹${amount.toStringAsFixed(2)}';
  }

  bool get isCredit => type == 'credited';

  /// Create a unique hash for duplicate detection
  String get uniqueHash {
    return '${amount}_${type}_${accountDigits}_${transactionId ?? ''}';
  }

  /// Check if this transaction is a duplicate of another
  bool isDuplicate(Transaction other) {
    // If transaction IDs match, it's definitely a duplicate
    if (transactionId != null &&
        other.transactionId != null &&
        transactionId == other.transactionId) {
      return true;
    }

    // Check amount, type, account match and time proximity (within 5 minutes)
    if (amount == other.amount &&
        type == other.type &&
        accountDigits == other.accountDigits) {
      final diff = dateTime.difference(other.dateTime).abs();
      if (diff.inMinutes < 5) return true;
    }

    return false;
  }
}

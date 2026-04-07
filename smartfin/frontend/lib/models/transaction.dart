/// Transaction model for storing and parsing transaction data
class Transaction {
  final String type; // 'credited' or 'debited'
  final double amount;
  final String sender;
  final String accountDigits;
  final DateTime dateTime;
  final String category;

  Transaction({
    required this.type,
    required this.amount,
    required this.sender,
    required this.accountDigits,
    required this.dateTime,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'sender': sender,
      'accountDigits': accountDigits,
      'dateTime': dateTime.toIso8601String(),
      'category': category,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      type: json['type'] as String,
      amount: json['amount'] as double,
      sender: json['sender'] as String,
      accountDigits: json['accountDigits'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      category: json['category'] as String,
    );
  }

  String get formattedAmount {
    return '₹${amount.toStringAsFixed(2)}';
  }
}

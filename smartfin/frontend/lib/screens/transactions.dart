class Transaction {
  final String type;
  final double amount;
  final String sender;
  final String accountDigits;
  final DateTime dateTime;
  final String category; // <-- add this field

  Transaction({
    required this.type,
    required this.amount,
    required this.sender,
    required this.accountDigits,
    required this.dateTime,
    required this.category, // <-- add here too
  });

  bool get isCredit => type.toLowerCase() == "credited";

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount': amount,
        'sender': sender,
        'accountDigits': accountDigits,
        'dateTime': dateTime.toIso8601String(),
        'category': category, // <-- add to JSON
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        type: json['type'],
        amount: (json['amount'] as num).toDouble(),
        sender: json['sender'],
        accountDigits: json['accountDigits'],
        dateTime: DateTime.parse(json['dateTime']),
        category: json['category'], // <-- parse from JSON
      );
}
import 'sms_transaction.dart';

/// Storage model for a parsed bank SMS transaction.
///
/// Maps 1-to-1 with the `bank_sms` SQLite table.
/// Use [BankSmsRecord.fromTransaction] to create from a parsed [SmsTransaction],
/// and [BankSmsRecord.toTransaction] to reconstruct it on read.
class BankSmsRecord {
  final int?               id;           // null before first INSERT
  final String             sender;
  final String             bankName;
  final String             accountNumber;
  final String             counterparty;
  final String             body;         // raw SMS — always preserved
  final DateTime           timestamp;
  final SmsTransactionType type;
  final double?            amount;
  final String             amountDisplay;
  final String             currency;

  const BankSmsRecord({
    this.id,
    required this.sender,
    required this.bankName,
    required this.accountNumber,
    required this.counterparty,
    required this.body,
    required this.timestamp,
    required this.type,
    this.amount,
    required this.amountDisplay,
    this.currency = 'INR',
  });

  // ── Column names ───────────────────────────────────────────────────────────

  static const table             = 'bank_sms';
  static const colId             = 'id';
  static const colSender         = 'sender';
  static const colBankName       = 'bank_name';
  static const colAccountNumber  = 'account_number';
  static const colCounterparty   = 'counterparty';
  static const colBody           = 'body';
  static const colTimestamp      = 'timestamp';
  static const colType           = 'type';
  static const colAmount         = 'amount';
  static const colAmountDisplay  = 'amount_display';
  static const colCurrency       = 'currency';

  static const createTableSql = '''
    CREATE TABLE IF NOT EXISTS $table (
      $colId            INTEGER PRIMARY KEY AUTOINCREMENT,
      $colSender        TEXT    NOT NULL,
      $colBankName      TEXT    NOT NULL,
      $colAccountNumber TEXT    NOT NULL,
      $colCounterparty  TEXT    NOT NULL,
      $colBody          TEXT    NOT NULL,
      $colTimestamp     TEXT    NOT NULL,
      $colType          TEXT    NOT NULL DEFAULT 'unknown',
      $colAmount        REAL,
      $colAmountDisplay TEXT    NOT NULL DEFAULT 'Unknown',
      $colCurrency      TEXT    NOT NULL DEFAULT 'INR'
    )
  ''';

  // ── Conversion ─────────────────────────────────────────────────────────────

  /// Build a [BankSmsRecord] from a fully-parsed [SmsTransaction].
  factory BankSmsRecord.fromTransaction(SmsTransaction tx) => BankSmsRecord(
    sender:        tx.sender,
    bankName:      tx.bankName,
    accountNumber: tx.accountNumber,
    counterparty:  tx.counterparty,
    body:          tx.rawSms,
    timestamp:     tx.timestamp,
    type:          tx.transactionType,
    amount:        tx.amount,
    amountDisplay: tx.amountDisplay,
    currency:      'INR',
  );

  /// Reconstruct an [SmsTransaction] from a stored record.
  SmsTransaction toTransaction() => SmsTransaction(
    transactionType: type,
    amount:          amount,
    amountDisplay:   amountDisplay,
    bankName:        bankName,
    sender:          sender,
    accountNumber:   accountNumber,
    counterparty:    counterparty,
    timestamp:       timestamp,
    rawSms:          body,
    localDbId:       id,   // carry the SQLite row ID for deletion
  );

  // ── SQLite serialisation ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    colSender:        sender,
    colBankName:      bankName,
    colAccountNumber: accountNumber,
    colCounterparty:  counterparty,
    colBody:          body,
    colTimestamp:     timestamp.toIso8601String(),
    colType:          type.name,
    colAmount:        amount,
    colAmountDisplay: amountDisplay,
    colCurrency:      currency,
  };

  factory BankSmsRecord.fromMap(Map<String, dynamic> map) => BankSmsRecord(
    id:            map[colId]            as int?,
    sender:        map[colSender]        as String,
    bankName:      map[colBankName]      as String,
    accountNumber: map[colAccountNumber] as String,
    counterparty:  map[colCounterparty]  as String,
    body:          map[colBody]          as String,
    timestamp:     DateTime.parse(map[colTimestamp] as String),
    type:          SmsTransactionType.values.firstWhere(
                     (e) => e.name == map[colType],
                     orElse: () => SmsTransactionType.unknown,
                   ),
    amount:        (map[colAmount] as num?)?.toDouble(),
    amountDisplay: map[colAmountDisplay] as String,
    currency:      map[colCurrency]      as String? ?? 'INR',
  );

  BankSmsRecord copyWith({int? id}) => BankSmsRecord(
    id:            id ?? this.id,
    sender:        sender,
    bankName:      bankName,
    accountNumber: accountNumber,
    counterparty:  counterparty,
    body:          body,
    timestamp:     timestamp,
    type:          type,
    amount:        amount,
    amountDisplay: amountDisplay,
    currency:      currency,
  );

  @override
  String toString() => 'BankSmsRecord(id: $id, bank: $bankName, '
      'type: ${type.name}, amount: $amountDisplay, ts: $timestamp)';
}

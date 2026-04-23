import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/bank_sms_record.dart';
import '../models/sms_transaction.dart';

/// SQLite-backed store for parsed bank SMS transactions.
///
/// Primary API: [saveTransaction] / [getAllTransactions].
/// Raw record API: [save] / [getAll] — used internally and in tests.
///
/// The database is opened lazily on first access.
/// All public methods are safe to call from any isolate.
class SmsDatabase {
  SmsDatabase._();
  static final SmsDatabase instance = SmsDatabase._();

  static const _dbName    = 'bank_sms.db';
  static const _dbVersion = 2;           // bumped for new columns

  Database? _db;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate:  (db, _)       => db.execute(BankSmsRecord.createTableSql),
      onUpgrade: (db, old, __) => _migrate(db, old),
    );
  }

  /// Migrate v1 → v2: add new columns with safe defaults.
  Future<void> _migrate(Database db, int oldVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE ${BankSmsRecord.table} '
        'ADD COLUMN ${BankSmsRecord.colBankName} TEXT NOT NULL DEFAULT "Unknown"',
      );
      await db.execute(
        'ALTER TABLE ${BankSmsRecord.table} '
        'ADD COLUMN ${BankSmsRecord.colAccountNumber} TEXT NOT NULL DEFAULT "Unknown"',
      );
      await db.execute(
        'ALTER TABLE ${BankSmsRecord.table} '
        'ADD COLUMN ${BankSmsRecord.colCounterparty} TEXT NOT NULL DEFAULT "Unknown"',
      );
      await db.execute(
        'ALTER TABLE ${BankSmsRecord.table} '
        'ADD COLUMN ${BankSmsRecord.colAmountDisplay} TEXT NOT NULL DEFAULT "Unknown"',
      );
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── SmsTransaction API (primary) ───────────────────────────────────────────

  /// Persist a parsed [SmsTransaction] and return the stored record with its
  /// auto-assigned database id.
  ///
  /// Only call this after the classifier has confirmed the message is
  /// bank-related — this method does NOT re-check classification.
  Future<BankSmsRecord> saveTransaction(SmsTransaction tx) =>
      save(BankSmsRecord.fromTransaction(tx));

  /// All stored transactions as [SmsTransaction] objects, newest first.
  Future<List<SmsTransaction>> getAllTransactions() async {
    final records = await getAll();
    return records.map((r) => r.toTransaction()).toList();
  }

  /// Transactions of a specific [type], newest first.
  Future<List<SmsTransaction>> getTransactionsByType(
    SmsTransactionType type,
  ) async {
    final records = await getByType(type);
    return records.map((r) => r.toTransaction()).toList();
  }

  /// Transactions within a date range, newest first.
  Future<List<SmsTransaction>> getTransactionsByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final records = await getByDateRange(from, to);
    return records.map((r) => r.toTransaction()).toList();
  }

  // ── Raw record API (internal / tests) ─────────────────────────────────────

  Future<BankSmsRecord> save(BankSmsRecord record) async {
    final db = await _database;
    final id = await db.insert(
      BankSmsRecord.table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return record.copyWith(id: id);
  }

  Future<List<BankSmsRecord>> getAll() async {
    final db   = await _database;
    final rows = await db.query(
      BankSmsRecord.table,
      orderBy: '${BankSmsRecord.colTimestamp} DESC',
    );
    return rows.map(BankSmsRecord.fromMap).toList();
  }

  Future<List<BankSmsRecord>> getByType(SmsTransactionType type) async {
    final db   = await _database;
    final rows = await db.query(
      BankSmsRecord.table,
      where:     '${BankSmsRecord.colType} = ?',
      whereArgs: [type.name],
      orderBy:   '${BankSmsRecord.colTimestamp} DESC',
    );
    return rows.map(BankSmsRecord.fromMap).toList();
  }

  Future<List<BankSmsRecord>> getByDateRange(
    DateTime from,
    DateTime to,
  ) async {
    final db   = await _database;
    final rows = await db.query(
      BankSmsRecord.table,
      where:     '${BankSmsRecord.colTimestamp} BETWEEN ? AND ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy:   '${BankSmsRecord.colTimestamp} DESC',
    );
    return rows.map(BankSmsRecord.fromMap).toList();
  }

  Future<BankSmsRecord?> getById(int id) async {
    final db   = await _database;
    final rows = await db.query(
      BankSmsRecord.table,
      where:     '${BankSmsRecord.colId} = ?',
      whereArgs: [id],
      limit:     1,
    );
    return rows.isEmpty ? null : BankSmsRecord.fromMap(rows.first);
  }

  Future<int> deleteById(int id) async {
    final db = await _database;
    return db.delete(
      BankSmsRecord.table,
      where:     '${BankSmsRecord.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    final db = await _database;
    await db.delete(BankSmsRecord.table);
  }
}

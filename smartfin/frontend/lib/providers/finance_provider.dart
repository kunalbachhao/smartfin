import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../models/sms_transaction.dart';
import '../data/dummy_data.dart';
import '../services/finance_service.dart';
import '../services/api_exception.dart';
import '../services/sms_database.dart';
import '../services/sms_storage_helper.dart';

// ── SmsTransaction → TransactionModel mapping ─────────────────────────────────

extension SmsTransactionToModel on SmsTransaction {
  /// Convert a parsed [SmsTransaction] into a [TransactionModel] that the
  /// existing UI renders without any changes.
  ///
  /// Core field mapping (list + detail screens):
  ///   title         → bankName            e.g. "HDFC Bank"
  // ignore: unintended_html_in_doc_comment
  ///   subtitle      → '<Type> · <acct>'   e.g. "Debit · XX1234"
  ///   amount        → signed amountDisplay e.g. "-₹850.00"
  ///   amountValue   → raw double (0.0 if unparseable)
  ///   isIncome      → true for credit
  ///   sectionLabel  → "DD MMM YYYY"
  ///   category      → "Bank SMS"
  ///
  /// SMS breakdown fields (detail screen — all guaranteed non-null):
  ///   smsBankName      → bankName
  ///   smsAccountNumber → masked account, e.g. "XX1234" or "Unknown"
  ///   smsCounterparty  → UPI ID / merchant / "Unknown"
  ///   smsRawBody       → full original SMS text
  ///   smsTimestamp     → "11 Apr 2026, 14:30"
  TransactionModel toTransactionModel() {
    const u        = SmsTransaction.unknown;
    final isIncome = transactionType == SmsTransactionType.credit;
    final sign     = isIncome ? '+' : '-';
    final display  = amountDisplay == u ? u : '$sign$amountDisplay';

    final typeLabel = switch (transactionType) {
      SmsTransactionType.credit  => 'Credit',
      SmsTransactionType.debit   => 'Debit',
      SmsTransactionType.otp     => 'OTP',
      SmsTransactionType.unknown => 'Unknown',
    };
    final subtitle = '$typeLabel · ${accountNumber != u ? accountNumber : u}';

    return TransactionModel(
      id:              '',
      title:           bankName,
      subtitle:        subtitle,
      amount:          display,
      amountValue:     amount ?? 0.0,
      isIncome:        isIncome,
      icon:            Icons.sms_outlined,
      color:           isIncome ? Colors.green : Colors.red,
      sectionLabel:    _sectionLabel(timestamp),
      category:        'Bank SMS',
      smsBankName:      bankName,
      smsAccountNumber: accountNumber,
      smsCounterparty:  counterparty,
      smsRawBody:       rawSms,
      smsTimestamp:     _detailTimestamp(timestamp),
      localDbId:        localDbId,
    );
  }

  static String _sectionLabel(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
  }

  static String _detailTimestamp(DateTime dt) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour.toString().padLeft(2,'0');
    final min = dt.minute.toString().padLeft(2,'0');
    return '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}, $h:$min';
  }
}

// ── FinanceProvider ────────────────────────────────────────────────────────────

/// Loading state for each data domain.
enum LoadState { idle, loading, loaded, error }

class FinanceProvider extends ChangeNotifier {
  final FinanceService _service;

  FinanceProvider({FinanceService? service})
      : _service = service ?? FinanceService();

  // ── Tab navigation callback ────────────────────────────────────────────────
  VoidCallback? switchToTransactionsTab;

  // ── Live financial data ────────────────────────────────────────────────────

  List<AccountModel>     _accounts     = [];
  List<TransactionModel> _transactions = [];
  AnalyticsData?         _analyticsData;

  // ── Load state ─────────────────────────────────────────────────────────────

  LoadState _accountsState     = LoadState.idle;
  LoadState _transactionsState = LoadState.idle;
  LoadState _analyticsState    = LoadState.idle;

  String? _accountsError;
  String? _transactionsError;
  String? _analyticsError;

  // ── Getters: data ──────────────────────────────────────────────────────────

  List<AccountModel>     get accounts      => _accounts;
  List<TransactionModel> get transactions  => _transactions;
  AnalyticsData?         get analyticsData => _analyticsData;

  // ── Getters: load state ────────────────────────────────────────────────────

  bool get isLoadingAccounts     => _accountsState     == LoadState.loading;
  bool get isLoadingTransactions => _transactionsState == LoadState.loading;
  bool get isLoadingAnalytics    => _analyticsState    == LoadState.loading;
  bool get isLoading => isLoadingAccounts || isLoadingTransactions || isLoadingAnalytics;

  String? get accountsError     => _accountsError;
  String? get transactionsError => _transactionsError;
  String? get analyticsError    => _analyticsError;

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  Future<void> loadAll() {
    // Set all three loading states in one batch before firing the async calls.
    // This produces a single notifyListeners() instead of three, cutting the
    // number of rebuilds triggered at startup from 6 to 4.
    _accountsState     = LoadState.loading;
    _transactionsState = LoadState.loading;
    _analyticsState    = LoadState.loading;
    _accountsError     = null;
    _transactionsError = null;
    _analyticsError    = null;
    notifyListeners();

    // Fire all three independently — failures in one do not block the others.
    _loadAccountsInternal();
    _loadTransactionsInternal();
    _loadAnalyticsInternal();
    return Future.value();
  }

  void clear() {
    _accounts      = [];
    _transactions  = [];
    _analyticsData = null;
    _accountsState     = LoadState.idle;
    _transactionsState = LoadState.idle;
    _analyticsState    = LoadState.idle;
    _accountsError     = null;
    _transactionsError = null;
    _analyticsError    = null;
    notifyListeners();
  }

  // ── Accounts ───────────────────────────────────────────────────────────────

  Future<void> loadAccounts() async {
    _accountsState = LoadState.loading;
    _accountsError = null;
    notifyListeners();
    await _loadAccountsInternal();
  }

  Future<void> _loadAccountsInternal() async {
    try {
      _accounts      = await _service.getAccounts();
      _accountsState = LoadState.loaded;
    } on ApiException catch (e) {
      _accountsError = e.message;
      _accountsState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  void setAccounts(List<AccountModel> accounts) {
    _accounts      = List.of(accounts);
    _accountsState = LoadState.loaded;
    notifyListeners();
  }

  // ── Transactions ───────────────────────────────────────────────────────────

  Future<void> loadTransactions() async {
    _transactionsState = LoadState.loading;
    _transactionsError = null;
    notifyListeners();
    await _loadTransactionsInternal();
  }

  Future<void> _loadTransactionsInternal() async {
    try {
      // Fetch API transactions and local SMS transactions in parallel.
      final results = await Future.wait([
        _service.getTransactions(),
        SmsDatabase.instance.getAllTransactions(),
      ]);

      final apiTxns = results[0] as List<TransactionModel>;
      final smsTxns = (results[1] as List<SmsTransaction>)
          .map((tx) => tx.toTransactionModel())
          .toList();

      // Merge: API transactions first, then SMS transactions.
      // Deduplicate by (title + amount + sectionLabel) to prevent double-
      // counting if the same transaction appears in both sources.
      final seen = <String>{};
      final merged = <TransactionModel>[];
      for (final tx in [...apiTxns, ...smsTxns]) {
        final key = '${tx.title}|${tx.amount}|${tx.sectionLabel}';
        if (seen.add(key)) merged.add(tx);
      }

      _transactions      = merged;
      _transactionsState = LoadState.loaded;
    } on ApiException catch (e) {
      // API failed — fall back to local SMS transactions only.
      try {
        final smsTxns = await SmsDatabase.instance.getAllTransactions();
        _transactions = smsTxns.map((tx) => tx.toTransactionModel()).toList();
        _transactionsState = LoadState.loaded;
      } catch (_) {
        _transactions = [];
      }
      _transactionsError = e.message;
      _transactionsState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeTransaction(TransactionModel tx) async {
    // Optimistically remove from the in-memory list so the UI updates instantly.
    _transactions = _transactions.where((t) => t != tx).toList();
    notifyListeners();

    if (tx.isSmsTransaction) {
      // ── SMS transaction: delete from local SQLite ────────────────────────
      final dbId = tx.localDbId;
      if (dbId != null) {
        try {
          final deleted = await SmsDatabase.instance.deleteById(dbId);
          if (kDebugMode) {
            debugPrint(
              '[FinanceProvider] local SMS delete: '
              'dbId=$dbId rows=$deleted',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FinanceProvider] local SMS delete error: $e');
          }
        }
      }

      // Add a tombstone to the processed-IDs set so the sync engine never
      // re-inserts this message. The tombstone key is the same composite ID
      // that SmsSyncService._computeId() would produce for this record:
      //   "<sender>_<timestampMs>"  (platform ID is not available here)
      // We also add a body-hash variant as a belt-and-suspenders guard.
      if (tx.smsRawBody != null && tx.smsTimestamp != null) {
        final sender = tx.smsBankName ?? 'unknown';
        final tsMs   = tx.sectionLabel; // best available without raw timestamp
        final tombstone = '${sender}_deleted_$tsMs';
        try {
          await SmsStorageHelper.addProcessedIds({tombstone});
          if (kDebugMode) {
            debugPrint(
              '[FinanceProvider] tombstone added: $tombstone',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[FinanceProvider] tombstone write error: $e');
          }
        }
      }

      // Recalculate analytics from local data (no API call needed).
      if (hasListeners) unawaited(_loadAnalyticsInternal());
      return;
    }

    // ── API transaction: delete from backend ─────────────────────────────
    if (tx.id.isEmpty) return;
    try {
      await _service.deleteTransaction(tx.id);
      if (kDebugMode) {
        debugPrint('[FinanceProvider] API delete: id=${tx.id}');
      }
      if (hasListeners) unawaited(loadAnalytics());
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[FinanceProvider] API delete error: ${e.message}');
      }
      // Restore the transaction on failure so the UI is consistent.
      await loadTransactions();
    }
  }

  Future<void> addTransaction({
    required String title,
    required double amount,
    required bool isIncome,
    required String category,
    DateTime? date,
  }) async {
    final created = await _service.createTransaction(
      title:    title,
      amount:   amount,
      type:     isIncome ? 'income' : 'expense',
      category: category,
      date:     date,
    );
    _transactions = [created, ..._transactions];
    notifyListeners();
    if (hasListeners) unawaited(loadAnalytics());
  }

  void setTransactions(List<TransactionModel> txs) {
    _transactions      = List.of(txs);
    _transactionsState = LoadState.loaded;
    notifyListeners();
  }

  /// Prepend an SMS-sourced transaction to the live list and notify listeners.
  /// Called by [SmsPipeline] after a bank SMS is parsed and stored locally.
  void prependSmsTransaction(SmsTransaction tx) {
    _transactions = [tx.toTransactionModel(), ..._transactions];
    notifyListeners();
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  Future<void> loadAnalytics({DateTime? from, DateTime? to}) async {
    _analyticsState = LoadState.loading;
    _analyticsError = null;
    notifyListeners();
    await _loadAnalyticsInternal(from: from, to: to);
  }

  Future<void> _loadAnalyticsInternal({DateTime? from, DateTime? to}) async {
    try {
      _analyticsData  = await _service.getAnalytics(from: from, to: to);
      _analyticsState = LoadState.loaded;
    } on ApiException catch (e) {
      _analyticsError = e.message;
      _analyticsState = LoadState.error;
    } finally {
      notifyListeners();
    }
  }

  // ── Computed: dashboard ────────────────────────────────────────────────────

  List<TransactionModel> get recentTransactions => _transactions.take(4).toList();

  double get totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amountValue);

  double get totalExpenses =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amountValue);

  double get netBalance => totalIncome - totalExpenses;

  String get netWorthFormatted      => _formatCurrency(netBalance);
  String get totalExpensesFormatted => _formatCurrency(totalExpenses);
  String get totalBalanceFormatted  => _formatCurrency(totalIncome);

  String get growthPercent {
    if (totalExpenses == 0) return '↗ 0.0%';
    final pct = (totalIncome - totalExpenses) / totalExpenses * 100;
    return '${pct >= 0 ? '↗' : '↘'} ${pct.abs().toStringAsFixed(1)}%';
  }

  // ── Computed: analytics fallback ──────────────────────────────────────────

  String get netPerformanceFormatted {
    if (_analyticsData != null) return _analyticsData!.netPerformance;
    if (totalIncome == 0) return '+0.0%';
    final pct = (totalIncome - totalExpenses) / totalIncome * 100;
    return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
  }

  double get monthlyUsageRatio {
    if (_analyticsData != null) return _analyticsData!.monthlyUsageRatio;
    return totalIncome == 0 ? 0.0 : (totalExpenses / totalIncome).clamp(0.0, 1.0);
  }

  List<LegendEntry> get legendEntries {
    if (_analyticsData != null) return _analyticsData!.legendEntries;
    return [
      LegendEntry(title: 'Fixed Costs', amount: _formatCurrency(totalExpenses), color: Colors.blue),
      LegendEntry(title: 'Lifestyle',   amount: _formatCurrency(totalIncome),   color: Colors.teal),
    ];
  }

  List<SpendingCategory> get spendingCategories {
    if (_analyticsData != null) return _analyticsData!.categories;
    final Map<String, double> totals = {};
    for (final t in _transactions.where((t) => !t.isIncome)) {
      totals[t.category] = (totals[t.category] ?? 0) + t.amountValue;
    }
    if (totals.isEmpty) return [];
    final maxAmount = totals.values.reduce(max);
    int colorIdx = 0;
    return totals.entries
        .map((e) => SpendingCategory(
              title:    e.key,
              amount:   _formatCurrency(e.value),
              progress: maxAmount > 0 ? (e.value / maxAmount).clamp(0.0, 1.0) : 0,
              color:    _categoryColors[colorIdx++ % _categoryColors.length],
            ))
        .toList()
      ..sort((a, b) => (totals[b.title] ?? 0).compareTo(totals[a.title] ?? 0));
  }

  // ── Static UI content ─────────────────────────────────────────────────────

  WelcomeContent   _welcomeContent = dummyWelcomeContent;
  OtpScreenContent _otpContent     = dummyOtpContent;
  LoginContent     _loginContent   = dummyLoginContent;
  SignupContent    _signupContent  = dummySignupContent;

  WelcomeContent   get welcomeContent => _welcomeContent;
  OtpScreenContent get otpContent     => _otpContent;
  LoginContent     get loginContent   => _loginContent;
  SignupContent    get signupContent  => _signupContent;

  void updateWelcomeContent(WelcomeContent c)  { _welcomeContent = c; notifyListeners(); }
  void updateOtpContent(OtpScreenContent c)    { _otpContent     = c; notifyListeners(); }
  void updateLoginContent(LoginContent c)      { _loginContent   = c; notifyListeners(); }
  void updateSignupContent(SignupContent c)    { _signupContent  = c; notifyListeners(); }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatCurrency(double value) {
    final abs     = value.abs();
    final sign    = value < 0 ? '-' : '';
    final parts   = abs.toStringAsFixed(2).split('.');
    final grouped = _indianGroup(parts[0]);
    return '$sign₹$grouped.${parts[1]}';
  }

  static String _indianGroup(String s) {
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest  = s.substring(0, s.length - 3);
    final buf   = StringBuffer();
    for (int i = 0; i < rest.length; i++) {
      if (i > 0 && (rest.length - i) % 2 == 0) buf.write(',');
      buf.write(rest[i]);
    }
    return '${buf.toString()},$last3';
  }

  static const List<Color> _categoryColors = [
    Colors.blue, Colors.teal, Colors.orange, Colors.brown,
    Colors.grey, Colors.purple, Colors.red, Colors.green,
  ];
}

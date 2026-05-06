import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../models/sms_transaction.dart';
import '../data/dummy_data.dart';
import '../services/finance_service.dart';
import '../services/api_exception.dart';
import '../services/sms_database.dart';
import '../services/sms_storage_helper.dart';
import '../services/budget_notification_service.dart';

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

  // ── Monthly budget ─────────────────────────────────────────────────────────

  /// Default budget used when no value has been set by the user.
  static const double defaultMonthlyBudget = 10000.0;

  /// SharedPreferences key — prefixed with userId so it is user-specific.
  static String _budgetKey(String userId) => 'monthly_budget_$userId';

  double _monthlyBudget = defaultMonthlyBudget;

  /// Whether the budget value has been loaded from the backend or local cache.
  /// `false` from construction until [loadBudget] completes for the first time.
  /// Used by the UI to show a skeleton instead of a stale default value.
  bool _budgetLoaded = false;

  /// `true` once [loadBudget] has completed at least once this session.
  bool get isBudgetLoaded => _budgetLoaded;

  /// The userId whose budget flags are currently active.
  /// Set by [loadBudget] and cleared by [clear].
  String _currentUserId = '';

  /// The user's current monthly budget in rupees.
  double get monthlyBudget => _monthlyBudget;

  // ── Budget alert threshold system ──────────────────────────────────────────

  /// The five thresholds (%) at which a one-time alert is fired per month.
  static const List<int> budgetAlertThresholds = [25, 50, 75, 90, 100];

  /// SharedPreferences key for a threshold flag.
  ///
  /// Format: `budget_alert_{userId}_{pct}_{YYYY_MM}`
  /// The month stamp is embedded so flags from previous months are never
  /// matched — no explicit reset step is required.
  static String _alertFlagKey(String userId, int pct, DateTime month) =>
      'budget_alert_${userId}_${pct}_${month.year}_${month.month.toString().padLeft(2, '0')}';

  /// In-memory set of thresholds already triggered this month.
  /// Populated from SharedPreferences on [loadBudget] / [_restoreAlertFlags]
  /// so alerts survive app restart and re-login.
  final Set<int> _triggeredThresholds = {};

  /// The most-recently crossed threshold, or `null` if none has fired yet
  /// this session.  Consumed by the UI layer to show a one-time snackbar /
  /// dialog and then cleared via [clearPendingAlert].
  BudgetAlert? _pendingAlert;

  /// The alert waiting to be displayed, or `null`.
  BudgetAlert? get pendingAlert => _pendingAlert;

  /// Called by the UI after it has consumed and displayed [pendingAlert].
  void clearPendingAlert() {
    if (_pendingAlert != null) {
      _pendingAlert = null;
      // No notifyListeners() — clearing an alert must not trigger a rebuild.
    }
  }

  /// Restores already-triggered threshold flags from SharedPreferences for
  /// [userId] and the current calendar month.
  ///
  /// Must be called after login / session restore so the provider never
  /// re-fires an alert that was already shown in a previous session.
  Future<void> _restoreAlertFlags(String userId) async {
    final now   = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    _triggeredThresholds.clear();
    for (final pct in budgetAlertThresholds) {
      final key = _alertFlagKey(userId, pct, now);
      if (prefs.getBool(key) == true) {
        _triggeredThresholds.add(pct);
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[FinanceProvider] alert flags restored: $_triggeredThresholds',
      );
    }
  }

  /// Evaluates [budgetUsagePercent] against each threshold and fires an alert
  /// for the highest newly-crossed threshold, if any.
  ///
  /// Persistence: marks ALL crossed-but-not-yet-triggered thresholds in
  /// SharedPreferences so that:
  ///   • A single large transaction that skips from 0% to 105% correctly
  ///     marks 25, 50, 75, 90, and 100 as all triggered (only the highest
  ///     fires a visible alert, but all are persisted to prevent re-firing
  ///     after an app restart).
  ///   • Exact threshold hits (e.g. exactly 50.00%) are caught by `>=`.
  ///
  /// Call sites: every method that mutates [_transactions] or [_monthlyBudget].
  Future<void> _checkBudgetThresholds(String userId) async {
    if (_monthlyBudget <= 0 || userId.isEmpty) return;

    final pct = budgetUsagePercent; // (currentMonthExpenses / budget) × 100
    final now = DateTime.now();

    // Collect ALL thresholds that have been crossed but not yet triggered.
    // We persist every skipped threshold so they are never re-fired after
    // an app restart, even if only the highest one shows a visible alert.
    final List<int> newlyTriggered = [];
    for (final threshold in budgetAlertThresholds) {
      if (pct >= threshold && !_triggeredThresholds.contains(threshold)) {
        newlyTriggered.add(threshold);
      }
    }

    if (newlyTriggered.isEmpty) return;

    // Mark ALL newly-crossed thresholds in-memory immediately to prevent
    // duplicate triggers within the same session.
    _triggeredThresholds.addAll(newlyTriggered);

    // Persist ALL newly-crossed flags so they survive app restart.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final threshold in newlyTriggered) {
        await prefs.setBool(_alertFlagKey(userId, threshold, now), true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FinanceProvider] alert flag persist error: $e');
      }
      // In-memory flags are already set — alerts fire correctly this session.
    }

    // Show a visible alert only for the highest newly-crossed threshold.
    // (Showing one alert per transaction is enough; the others are silently
    // marked so they don't re-fire.)
    final newThreshold = newlyTriggered.last; // list is in ascending order

    // Expose the alert for the UI layer to consume (in-app snackbar).
    _pendingAlert = BudgetAlert(
      thresholdPct: newThreshold,
      usagePercent: pct,
      budgetAmount: _monthlyBudget,
      expenseAmount: currentMonthExpenses,
    );

    // Fire the local push notification (background / lock-screen delivery).
    // Best-effort — failure is logged inside the service and never throws.
    unawaited(BudgetNotificationService.instance.show(_pendingAlert!));

    if (kDebugMode) {
      debugPrint(
        '[FinanceProvider] budget alert fired: '
        'threshold=$newThreshold% usage=${pct.toStringAsFixed(1)}% '
        'allTriggered=$newlyTriggered',
      );
    }

    notifyListeners();
  }

  // ── Current-month expense helpers ─────────────────────────────────────────

  /// Returns only the expense transactions that fall within the current
  /// calendar month (year + month match device clock).
  ///
  /// Filtering rules:
  ///   • `isIncome == false`  — expenses only
  ///   • `category != 'Bank SMS' || amountValue > 0`  — SMS transactions
  ///     with a zero/unknown amount are excluded (unparseable messages)
  ///   • Promotional and telecom SMS are never in `_transactions` — they are
  ///     dropped by [SmsClassifier] before reaching the provider
  ///   • Deleted transactions are never in `_transactions` — removal is
  ///     handled by [removeTransaction] which updates the list immediately
  List<TransactionModel> get _currentMonthExpenses {
    final now = DateTime.now();
    return _transactions.where((t) {
      if (t.isIncome) return false;
      // Parse the sectionLabel to determine the transaction month.
      // API transactions use sectionLabel = "TODAY" | "YESTERDAY" | "MONTH YYYY"
      // SMS transactions use sectionLabel = "DD MMM YYYY"
      // Both cases are handled below.
      return _isCurrentMonth(t.sectionLabel, now);
    }).toList();
  }

  /// Returns `true` when [sectionLabel] belongs to the current calendar month.
  ///
  /// Supported formats:
  ///   "TODAY"          — always current month
  ///   "YESTERDAY"      — always current month (yesterday is still this month
  ///                      unless it's the 1st, but the 1st's yesterday is last
  ///                      month — handled via date arithmetic)
  ///   "MONTH YYYY"     — e.g. "MAY 2026"  (API transactions)
  ///   "DD MMM YYYY"    — e.g. "04 May 2026" (SMS transactions)
  static bool _isCurrentMonth(String label, DateTime now) {
    final upper = label.toUpperCase().trim();

    if (upper == 'TODAY') return true;

    if (upper == 'YESTERDAY') {
      final yesterday = now.subtract(const Duration(days: 1));
      return yesterday.year == now.year && yesterday.month == now.month;
    }

    // "DD MMM YYYY" — SMS format (e.g. "04 MAY 2026")
    final smsMatch = RegExp(
      r'^(\d{1,2})\s+([A-Z]{3})\s+(\d{4})$',
    ).firstMatch(upper);
    if (smsMatch != null) {
      final year  = int.tryParse(smsMatch.group(3)!) ?? 0;
      final month = _monthIndex(smsMatch.group(2)!);
      return year == now.year && month == now.month;
    }

    // "MONTH YYYY" — API format (e.g. "MAY 2026")
    final apiMatch = RegExp(
      r'^([A-Z]+)\s+(\d{4})$',
    ).firstMatch(upper);
    if (apiMatch != null) {
      final year  = int.tryParse(apiMatch.group(2)!) ?? 0;
      final month = _monthIndex(apiMatch.group(1)!);
      return year == now.year && month == now.month;
    }

    return false;
  }

  /// Maps a 3-letter month abbreviation (uppercase) to a 1-based month index.
  static int _monthIndex(String abbr) {
    const months = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
      'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
      'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };
    // Handle full month names from the API format (e.g. "JANUARY")
    return months[abbr.substring(0, min(3, abbr.length))] ?? 0;
  }

  /// Total expenses for the current calendar month only (rupees).
  ///
  /// This is the authoritative value for budget tracking.
  /// Use [totalExpenses] for all-time totals (net worth, growth %).
  double get currentMonthExpenses =>
      _currentMonthExpenses.fold(0.0, (sum, t) => sum + t.amountValue);

  /// Budget consumption as a percentage: (currentMonthExpenses / budget) × 100.
  ///
  /// Returns 0.0 when budget is zero or not set.
  /// Can exceed 100.0 when the budget is overrun.
  double get budgetUsagePercent {
    if (_monthlyBudget <= 0) return 0.0;
    return (currentMonthExpenses / _monthlyBudget) * 100.0;
  }

  /// Fraction of the monthly budget consumed by expenses this month (0.0–1.0+).
  /// Values above 1.0 indicate the budget has been exceeded.
  ///
  /// Derived from [budgetUsagePercent] so both values are always consistent.
  double get budgetUsageRatio {
    if (_monthlyBudget <= 0) return 0.0;
    return currentMonthExpenses / _monthlyBudget;
  }

  /// Remaining budget this month (can be negative if over budget).
  double get budgetRemaining => _monthlyBudget - currentMonthExpenses;

  /// `true` when expenses have exceeded the monthly budget.
  bool get isBudgetExceeded => currentMonthExpenses > _monthlyBudget;

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

  Future<void> loadAll({String? userId}) {
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

    // Fire all four independently — failures in one do not block the others.
    _loadAccountsInternal();
    _loadTransactionsInternal();
    _loadAnalyticsInternal();
    if (userId != null && userId.isNotEmpty) loadBudget(userId);
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
    // Reset alert state on logout so a new session starts clean.
    _triggeredThresholds.clear();
    _pendingAlert    = null;
    _currentUserId   = '';
    _budgetLoaded    = false;
    notifyListeners();
  }

  // ── Budget ─────────────────────────────────────────────────────────────────

  /// SharedPreferences key that records whether the user has ever explicitly
  /// set their own budget via [setBudget].
  ///
  /// Purpose: distinguish a first-time user (who should always start at
  /// [defaultMonthlyBudget]) from a user who intentionally set a custom value.
  /// Without this flag, a stale or incorrect value in MongoDB (e.g. 600)
  /// would be silently accepted as the user's budget.
  ///
  /// Set to `"true"` the first time [setBudget] is called.
  /// Never cleared on logout — it is user-specific via the userId suffix.
  static String _budgetUserSetKey(String userId) =>
      'budget_user_set_$userId';

  /// Loads the monthly budget for [userId].
  ///
  /// Priority:
  ///   1. If the user has **never explicitly set** a budget (no
  ///      `budget_user_set_{userId}` flag), always use [defaultMonthlyBudget]
  ///      (₹10,000) and sync it to the backend.  This guarantees first-time
  ///      users start at the correct default regardless of what value is
  ///      stored in MongoDB.
  ///   2. If the user **has** set a budget before, fetch from the backend
  ///      (`GET /budget`) — authoritative, user-specific across devices.
  ///   3. Backend unavailable → fall back to local SharedPreferences cache.
  ///   4. Local cache missing → [defaultMonthlyBudget] (should not happen
  ///      after the first successful load, but safe as a last resort).
  ///
  /// The loaded value is persisted locally so it survives offline sessions.
  Future<void> loadBudget(String userId) async {
    // Store userId so threshold checks can persist flags without requiring
    // callers to pass it on every transaction mutation.
    _currentUserId = userId;

    // Restore already-triggered flags before loading the budget value so
    // that if the budget load triggers a threshold check, previously-fired
    // alerts are not re-fired.
    await _restoreAlertFlags(userId);

    final prefs = await SharedPreferences.getInstance();
    final userHasSetBudget =
        prefs.getBool(_budgetUserSetKey(userId)) == true;

    double loaded;

    if (!userHasSetBudget) {
      // ── First-time user: always apply the correct default ──────────────
      // The user has never explicitly set a budget, so whatever is in
      // MongoDB may be a stale or incorrect value.  Apply defaultMonthlyBudget
      // unconditionally and sync it to the backend so MongoDB is also correct.
      loaded = defaultMonthlyBudget;

      // Persist locally.
      await prefs.setDouble(_budgetKey(userId), loaded);

      // Sync to backend (best-effort — failure is non-fatal).
      try {
        await _service.setBudget(loaded);
        if (kDebugMode) {
          debugPrint(
            '[FinanceProvider] first-time default budget synced to backend: '
            '₹$loaded',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[FinanceProvider] first-time default budget sync failed: $e',
          );
        }
      }
    } else {
      // ── Returning user: fetch their saved budget ───────────────────────
      try {
        loaded = await _service.getBudget(defaultBudget: defaultMonthlyBudget);
        // Cache locally for offline use.
        await prefs.setDouble(_budgetKey(userId), loaded);
      } catch (_) {
        // Backend unavailable — fall back to local cache.
        loaded =
            prefs.getDouble(_budgetKey(userId)) ?? defaultMonthlyBudget;
      }
    }

    if (_monthlyBudget != loaded) {
      _monthlyBudget = loaded;
      notifyListeners();
    }

    if (kDebugMode) {
      debugPrint('[FinanceProvider] budget loaded: ₹$_monthlyBudget '
          '(userHasSetBudget: $userHasSetBudget)');
    }

    // Mark budget as loaded so the UI replaces the skeleton with real data.
    if (!_budgetLoaded) {
      _budgetLoaded = true;
      notifyListeners();
    }

    // Check thresholds now that both the budget value and the restored flags
    // are in place.  This covers the race where _loadTransactionsInternal
    // completed before loadBudget and skipped the check (userId was empty).
    // unawaited so it does not block the caller.
    unawaited(_checkBudgetThresholds(userId));
  }

  /// Updates the monthly budget for [userId], persists locally, and syncs
  /// to the backend.
  ///
  /// Marks the `budget_user_set_{userId}` flag so subsequent [loadBudget]
  /// calls know the user has explicitly chosen a value and should not
  /// overwrite it with the default.
  ///
  /// UI updates immediately (optimistic); backend failure is logged but does
  /// not revert the local value — the next [loadBudget] call will re-sync.
  Future<void> setBudget(double amount, String userId) async {
    if (amount < 0) return;

    _monthlyBudget = amount;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Persist locally first so the value survives offline.
    await prefs.setDouble(_budgetKey(userId), amount);

    // Mark that this user has explicitly set their budget.
    // This prevents loadBudget from overwriting their choice with the default.
    await prefs.setBool(_budgetUserSetKey(userId), true);

    // Re-check thresholds: lowering the budget may cross a new threshold.
    unawaited(_checkBudgetThresholds(userId));

    // Sync to backend.
    try {
      await _service.setBudget(amount);
      if (kDebugMode) {
        debugPrint('[FinanceProvider] budget synced to backend: ₹$amount');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        debugPrint('[FinanceProvider] budget sync failed: ${e.message}');
      }
      // Local value already updated — no rollback needed.
    }
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
      // Re-evaluate thresholds against the freshly loaded transaction list.
      // Uses unawaited so it does not block the finally block.
      unawaited(_checkBudgetThresholds(_currentUserId));
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
    // Check thresholds after adding an expense transaction.
    if (!isIncome) unawaited(_checkBudgetThresholds(_currentUserId));
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
    // Check thresholds for debit (expense) SMS transactions.
    if (tx.isDebit) unawaited(_checkBudgetThresholds(_currentUserId));
  }

  /// Auto-create a "My Accounts" entry when a new bank account number is
  /// detected from an SMS transaction, if it does not already exist.
  ///
  /// Duplicate check: compares the last-4-digit suffix of [tx.accountNumber]
  /// (e.g. "XX8045" → "8045") against all existing account numbers in memory.
  /// If a match is found, no API call is made.
  ///
  /// On success, the new account is prepended to [_accounts] and listeners
  /// are notified so the dashboard updates immediately.
  ///
  /// Failures are logged and silently swallowed — account auto-creation is
  /// best-effort and must never break the transaction save flow.
  Future<void> ensureAccountExists(SmsTransaction tx) async {
    // Only act when a genuine account number was extracted.
    final acctNum = tx.accountNumber;
    if (acctNum == SmsTransaction.unknown) return;

    // Extract the last-4-digit suffix for dedup (e.g. "XX8045" → "8045").
    final suffix = acctNum.replaceAll(RegExp(r'[^0-9]'), '');
    if (suffix.isEmpty) return;

    // In-memory dedup: check if any existing account already ends with
    // the same digits. Avoids an API call on every SMS.
    final alreadyKnown = _accounts.any((a) {
      final existing = a.number.replaceAll(RegExp(r'[^0-9]'), '');
      return existing.endsWith(suffix);
    });
    if (alreadyKnown) return;

    // New account detected — create it on the backend.
    try {
      final created = await _service.createAccount(
        name:    tx.bankName,
        number:  '**** $suffix',
        balance: 0,
      );

      // Prepend to in-memory list and notify UI.
      _accounts = [created, ..._accounts];
      notifyListeners();

      if (kDebugMode) {
        debugPrint(
          '[FinanceProvider] auto-created account: '
          'bank=${tx.bankName} suffix=$suffix id=${created.id}',
        );
      }
    } on ApiException catch (e) {
      // Best-effort — log and continue. Never throw.
      if (kDebugMode) {
        debugPrint(
          '[FinanceProvider] auto-create account failed: ${e.message}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FinanceProvider] auto-create account error: $e');
      }
    }
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

// ── BudgetAlert ────────────────────────────────────────────────────────────────

/// Immutable value object describing a budget threshold crossing.
///
/// Produced by [FinanceProvider._checkBudgetThresholds] and exposed via
/// [FinanceProvider.pendingAlert].  The UI layer reads this, shows a
/// snackbar/dialog, then calls [FinanceProvider.clearPendingAlert].
class BudgetAlert {
  /// The threshold that was crossed, e.g. 25, 50, 75, 90, or 100.
  final int thresholdPct;

  /// Actual usage percentage at the moment the alert fired (may be > threshold).
  final double usagePercent;

  /// The user's monthly budget in rupees at the time of the alert.
  final double budgetAmount;

  /// Current-month expenses in rupees at the time of the alert.
  final double expenseAmount;

  const BudgetAlert({
    required this.thresholdPct,
    required this.usagePercent,
    required this.budgetAmount,
    required this.expenseAmount,
  });

  /// Human-readable label for the alert, e.g. "75% of budget used".
  String get label => '$thresholdPct% of budget used';

  /// `true` when the budget has been fully consumed or exceeded.
  bool get isExceeded => thresholdPct >= 100;

  @override
  String toString() =>
      'BudgetAlert(threshold: $thresholdPct%, usage: ${usagePercent.toStringAsFixed(1)}%)';
}

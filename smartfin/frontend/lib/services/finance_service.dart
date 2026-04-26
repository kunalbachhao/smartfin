import '../models/app_models.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Typed wrapper around the financial API endpoints.
///
/// All methods throw [ApiException] on failure.
/// Callers (FinanceProvider) catch and surface errors to the UI.
class FinanceService {
  final ApiClient _client;

  FinanceService({ApiClient? client}) : _client = client ?? ApiClient();

  // ── Transactions ───────────────────────────────────────────────────────────

  /// Fetches all transactions for the authenticated user.
  /// [page] and [limit] control pagination (default: page 1, 100 per page).
  Future<List<TransactionModel>> getTransactions({
    int page = 1,
    int limit = 100,
  }) async {
    final response = await _client.authGet(
      '/transactions?page=$page&limit=$limit',
    );
    final data = response['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new transaction and returns the created document.
  Future<TransactionModel> createTransaction({
    required String title,
    required double amount,
    required String type,     // "income" | "expense"
    required String category,
    DateTime? date,
  }) async {
    final response = await _client.authPost(
      '/transactions',
      body: {
        'title':    title,
        'amount':   amount,
        'type':     type,
        'category': category,
        if (date != null) 'date': date.toIso8601String(),
      },
    );
    return TransactionModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  /// Deletes a transaction by its backend id.
  Future<void> deleteTransaction(String id) async {
    await _client.authDelete('/transactions/$id');
  }

  /// Updates a transaction by its backend id (partial update).
  Future<TransactionModel> updateTransaction(
    String id, {
    String? title,
    double? amount,
    String? type,
    String? category,
    DateTime? date,
  }) async {
    final body = <String, dynamic>{
      if (title    != null) 'title':    title,
      if (amount   != null) 'amount':   amount,
      if (type     != null) 'type':     type,
      if (category != null) 'category': category,
      if (date     != null) 'date':     date.toIso8601String(),
    };
    final response = await _client.authPut('/transactions/$id', body: body);
    return TransactionModel.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  // ── Accounts ───────────────────────────────────────────────────────────────

  /// Fetches all accounts for the authenticated user.
  Future<List<AccountModel>> getAccounts() async {
    final response = await _client.authGet('/accounts');
    final data = response['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AccountModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new account and returns the created document.
  Future<AccountModel> createAccount({
    required String name,
    required String number,
    double balance = 0,
  }) async {
    final response = await _client.authPost(
      '/accounts',
      body: {'name': name, 'number': number, 'balance': balance},
    );
    return AccountModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  // ── Analytics ──────────────────────────────────────────────────────────────

  /// Fetches computed analytics for the given date range.
  /// Defaults to the current month if [from]/[to] are omitted.
  Future<AnalyticsData> getAnalytics({DateTime? from, DateTime? to}) async {
    final params = StringBuffer('/analytics');
    final queryParts = <String>[];
    if (from != null) queryParts.add('from=${Uri.encodeComponent(from.toIso8601String())}');
    if (to   != null) queryParts.add('to=${Uri.encodeComponent(to.toIso8601String())}');
    if (queryParts.isNotEmpty) params.write('?${queryParts.join('&')}');

    final response = await _client.authGet(params.toString());
    return AnalyticsData.fromJson(
      response['data'] as Map<String, dynamic>,
    );
  }

  // ── Budget ─────────────────────────────────────────────────────────────────

  /// Fetches the user's monthly budget from the backend.
  /// Returns the default [defaultBudget] if the request fails.
  Future<double> getBudget({double defaultBudget = 10000}) async {
    try {
      final response = await _client.authGet('/budget');
      final data = response['data'] as Map<String, dynamic>?;
      return (data?['monthlyBudget'] as num?)?.toDouble() ?? defaultBudget;
    } catch (_) {
      return defaultBudget;
    }
  }

  /// Persists the user's monthly budget to the backend.
  /// Throws [ApiException] on failure.
  Future<double> setBudget(double amount) async {
    final response = await _client.authPut(
      '/budget',
      body: {'monthlyBudget': amount},
    );
    final data = response['data'] as Map<String, dynamic>?;
    return (data?['monthlyBudget'] as num?)?.toDouble() ?? amount;
  }
}

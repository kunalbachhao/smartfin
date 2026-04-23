import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_exception.dart';
import 'token_storage.dart';

/// Low-level HTTP client.
///
/// Handles:
/// - Platform-aware base URL (emulator vs physical device vs release)
/// - 30-second timeout for auth calls, 15-second for data calls
/// - 1 automatic retry (with 1-second back-off) on timeout or 5xx
/// - Clean, user-friendly error messages — raw Dart exceptions never reach UI
/// - Structured debug logging in debug builds
class ApiClient {


  static String get baseUrl {
    return 'https://equation-anthem-delay.ngrok-free.dev';
  }

  // ── Timeouts ───────────────────────────────────────────────────────────────

  /// Auth endpoints (login, signup) — 30 s to accommodate bcrypt on the server.
  static const Duration _authTimeout = Duration(seconds: 30);

  /// Data endpoints (transactions, accounts, analytics) — 15 s.
  static const Duration _dataTimeout = Duration(seconds: 15);

  // ── Retry ──────────────────────────────────────────────────────────────────

  /// One automatic retry for transient 5xx server errors only.
  /// Timeouts are NOT retried automatically — the user sees the error
  /// immediately and can tap Retry themselves. This prevents the worst case
  /// of 30s + 1s + 30s = 61s wait before showing an error message.
  static const int _maxRetries = 1;

  /// B6 fix: 300ms back-off (was 1 second) — fast enough to be invisible
  /// on a transient 5xx but still gives the server a moment to recover.
  static const Duration _retryDelay = Duration(milliseconds: 300);

  // ── Headers ────────────────────────────────────────────────────────────────

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Singleton ──────────────────────────────────────────────────────────────

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _httpClient = http.Client();

  // ── Public HTTP methods ────────────────────────────────────────────────────

  /// Unauthenticated POST — login, signup, verify, resend.
  /// Uses [_authTimeout] (30 s) because bcrypt can be slow.
  Future<Map<String, dynamic>> post(
    String path, {
    required Map<String, dynamic> body,
  }) {
    _log('POST $path');
    return _withRetry(
      () => _httpClient
          .post(_uri(path), headers: _defaultHeaders, body: jsonEncode(body))
          .timeout(_authTimeout),
    );
  }

  /// Authenticated POST — attaches JWT from storage.
  Future<Map<String, dynamic>> authPost(
    String path, {
    required Map<String, dynamic> body,
  }) {
    _log('POST $path (auth)');
    return _withRetry(
      () async => _httpClient
          .post(
            _uri(path),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_dataTimeout),
    );
  }

  /// Authenticated GET.
  Future<Map<String, dynamic>> authGet(String path) {
    _log('GET $path (auth)');
    return _withRetry(
      () async => _httpClient
          .get(_uri(path), headers: await _authHeaders())
          .timeout(_dataTimeout),
    );
  }

  /// Authenticated PUT.
  Future<Map<String, dynamic>> authPut(
    String path, {
    required Map<String, dynamic> body,
  }) {
    _log('PUT $path (auth)');
    return _withRetry(
      () async => _httpClient
          .put(
            _uri(path),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_dataTimeout),
    );
  }

  /// Authenticated DELETE.
  Future<Map<String, dynamic>> authDelete(String path) {
    _log('DELETE $path (auth)');
    return _withRetry(
      () async => _httpClient
          .delete(_uri(path), headers: await _authHeaders())
          .timeout(_dataTimeout),
    );
  }

  // ── Retry wrapper ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _withRetry(
    Future<http.Response> Function() call,
  ) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await _execute(call);
      } on ApiException catch (e) {
        final isLast = attempt == _maxRetries;

        // B6 fix: never auto-retry timeouts — the user should see the error
        // immediately and decide whether to retry. Auto-retrying a 30s timeout
        // would make the user wait 61s before seeing any feedback.
        // Only retry transient 5xx server errors.
        final canRetry = !isLast &&
            !e.isTimeout &&
            (e.statusCode != null && e.statusCode! >= 500);

        if (!canRetry) rethrow;

        _log('Attempt ${attempt + 1} failed (${e.message}). '
            'Retrying in ${_retryDelay.inMilliseconds}ms…');
        await Future.delayed(_retryDelay);
      }
    }
    // Unreachable — loop always rethrows or returns.
    throw const ApiException(message: 'Request failed. Please try again.');
  }

  // ── Core execute ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _execute(
    Future<http.Response> Function() call,
  ) async {
    try {
      final response = await call();
      _log('← ${response.statusCode}');
      return _parse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException catch (e) {
      _log('TimeoutException: $e');
      throw const ApiException(
        message: 'The server is taking too long to respond. Please try again.',
        isTimeout: true,
      );
    } on SocketException catch (e) {
      _log('SocketException: $e');
      // SocketException means the host is unreachable — most commonly the
      // emulator/device cannot reach the backend at the configured baseUrl.
      throw ApiException(
        message: 'Cannot reach the server at $baseUrl. '
            'Make sure the backend is running and the device can reach it.',
      );
    } on HttpException catch (e) {
      _log('HttpException: $e');
      throw const ApiException(message: 'Network error. Please try again.');
    } on FormatException catch (e) {
      _log('FormatException: $e');
      throw const ApiException(
          message: 'Unexpected server response. Please try again.');
    } catch (e) {
      _log('Unexpected error: $e');
      throw const ApiException(
          message: 'Something went wrong. Please try again.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, String>> _authHeaders() async {
    final token = await TokenStorage.getToken();
    return {
      ..._defaultHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parse(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Invalid JSON from server (status ${response.statusCode}).',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final msg = body['message'] as String? ??
        'Request failed (${response.statusCode})';
    throw ApiException(statusCode: response.statusCode, message: msg);
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[ApiClient] $message');
  }
}

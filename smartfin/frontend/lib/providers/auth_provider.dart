import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/api_exception.dart';
import '../services/token_storage.dart';

enum AuthStatus { idle, loading, success, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  // ── State ──────────────────────────────────────────────────────────────────

  AuthStatus _status        = AuthStatus.idle;
  String?    _errorMessage;
  String?    _token;
  String?    _userId;
  String?    _email;
  String?    _pendingEmail;
  bool       _isRestoring   = true;
  bool       _isTimeout     = false;

  // ── Getters ────────────────────────────────────────────────────────────────

  AuthStatus get status        => _status;
  String?    get errorMessage  => _errorMessage;
  String?    get token         => _token;
  String?    get userId        => _userId;
  String?    get email         => _email;
  String?    get pendingEmail  => _pendingEmail;
  bool       get isRestoring   => _isRestoring;
  bool       get isLoading     => _status == AuthStatus.loading;
  bool       get isTimeout     => _isTimeout;
  bool       get isAuthenticated => _token != null && _token!.isNotEmpty;

  // ── Session restore ────────────────────────────────────────────────────────

  /// B2 fix: reads token + user info in one parallel batch instead of two
  /// sequential calls, cutting cold-start Keychain latency roughly in half.
  Future<void> restoreSession() async {
    try {
      // _ensureLoaded() reads all 3 keys concurrently in a single pass.
      // Calling getToken() first populates the cache; getUser() is then free.
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        // getUser() returns from the cache populated by getToken() above.
        final user = await TokenStorage.getUser();
        _token  = token;
        _userId = user['userId'];
        _email  = user['email'];
      }
    } catch (e) {
      debugPrint('[AuthProvider] restoreSession error: $e');
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  // ── Auth actions ───────────────────────────────────────────────────────────

  Future<bool> signupInit({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      final result = await _authService.signupInit(email: email, password: password);
      _pendingEmail = result.email;
      _setSuccess();
      return true;
    } on ApiException catch (e) {
      _setError(e.message, isTimeout: e.isTimeout);
      return false;
    }
  }

  Future<bool> verifySignup({required String code}) async {
    if (_pendingEmail == null) {
      _setError('Session expired. Please sign up again.');
      return false;
    }
    _setLoading();
    try {
      final result = await _authService.verifySignup(
        email: _pendingEmail!,
        code: code,
      );
      await _persistSession(result);
      _pendingEmail = null;
      _setSuccess();
      return true;
    } on ApiException catch (e) {
      _setError(e.message, isTimeout: e.isTimeout);
      return false;
    }
  }

  Future<bool> resendOtp() async {
    if (_pendingEmail == null) {
      _setError('No pending signup. Please sign up again.');
      return false;
    }
    _setLoading();
    try {
      await _authService.resendOtp(email: _pendingEmail!);
      _setSuccess();
      return true;
    } on ApiException catch (e) {
      _setError(e.message, isTimeout: e.isTimeout);
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading();
    try {
      final result = await _authService.login(email: email, password: password);
      await _persistSession(result);
      _setSuccess();
      return true;
    } on ApiException catch (e) {
      _setError(e.message, isTimeout: e.isTimeout);
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await TokenStorage.clear();
    } catch (e) {
      debugPrint('[AuthProvider] logout storage error: $e');
    }
    _token        = null;
    _userId       = null;
    _email        = null;
    _pendingEmail = null;
    _status       = AuthStatus.idle;
    _errorMessage = null;
    _isTimeout    = false;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      _isTimeout    = false;
      notifyListeners();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// B4 fix: persist the session to secure storage AFTER notifying listeners.
  /// The UI transitions immediately when isAuthenticated flips; storage writes
  /// happen concurrently in the background and don't block navigation.
  Future<void> _persistSession(AuthResult result) async {
    // Update in-memory state first so isAuthenticated is true immediately.
    _token  = result.token;
    _userId = result.userId;
    _email  = result.email;
    // Write to secure storage concurrently — don't await before notifying.
    // If the app is killed before writes complete the user just has to log in
    // again, which is acceptable. The alternative (blocking navigation) is not.
    unawaited(Future.wait([
      TokenStorage.saveToken(result.token),
      TokenStorage.saveUser(userId: result.userId, email: result.email),
    ]));
  }

  void _setLoading() {
    _status       = AuthStatus.loading;
    _errorMessage = null;
    _isTimeout    = false;
    notifyListeners();
  }

  void _setSuccess() {
    _status       = AuthStatus.success;
    _errorMessage = null;
    _isTimeout    = false;
    notifyListeners();
  }

  void _setError(String message, {bool isTimeout = false}) {
    _status       = AuthStatus.error;
    _errorMessage = message;
    _isTimeout    = isTimeout;
    notifyListeners();
  }
}

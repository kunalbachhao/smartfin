import 'api_client.dart';
import 'api_exception.dart';

// ── Response models ────────────────────────────────────────────────────────

/// Returned by [AuthService.signupInit] on success.
class SignupInitResult {
  final String email;
  const SignupInitResult({required this.email});
}

/// Returned by [AuthService.verifySignup] and [AuthService.login] on success.
class AuthResult {
  final String token;
  final String userId;
  final String email;

  const AuthResult({
    required this.token,
    required this.userId,
    required this.email,
  });
}

// ── Service ────────────────────────────────────────────────────────────────

/// Typed wrapper around all authentication endpoints.
///
/// Every method either returns a typed result or throws [ApiException].
/// Callers (e.g. [AuthProvider]) catch [ApiException] and surface the
/// message to the UI.
class AuthService {
  final ApiClient _client;

  AuthService({ApiClient? client}) : _client = client ?? ApiClient();

  // ── POST /signup-init ──────────────────────────────────────────────────────

  /// Step 1 of registration: validates credentials and sends an OTP email.
  ///
  /// Throws [ApiException] on validation errors, duplicate email, or rate limit.
  Future<SignupInitResult> signupInit({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/signup-init',
      body: {'email': email.trim(), 'password': password},
    );
    return SignupInitResult(email: data['email'] as String? ?? email.trim());
  }

  // ── POST /verify-signup ────────────────────────────────────────────────────

  /// Step 2 of registration: verifies the OTP and creates the account.
  ///
  /// Returns [AuthResult] with the JWT on success.
  /// Throws [ApiException] with `attemptsLeft` info embedded in the message
  /// when the code is wrong.
  Future<AuthResult> verifySignup({
    required String email,
    required String code,
  }) async {
    final data = await _client.post(
      '/verify-signup',
      body: {'email': email.trim(), 'code': code.trim()},
    );
    return _parseAuthResult(data);
  }

  // ── POST /resend-otp ───────────────────────────────────────────────────────

  /// Regenerates and resends the OTP for a pending signup.
  ///
  /// Throws [ApiException] if no pending signup exists or rate limit is hit.
  Future<void> resendOtp({required String email}) async {
    await _client.post(
      '/resend-otp',
      body: {'email': email.trim()},
    );
  }

  // ── POST /login ────────────────────────────────────────────────────────────

  /// Authenticates an existing user.
  ///
  /// Returns [AuthResult] with the JWT on success.
  /// Throws [ApiException] with status 401 on bad credentials.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(
      '/login',
      body: {'email': email.trim(), 'password': password},
    );
    return _parseAuthResult(data);
  }

  // ── GET /health ────────────────────────────────────────────────────────────

  /// Checks whether the backend is reachable and healthy.
  /// Returns the raw JSON map so callers can inspect service statuses.
  Future<Map<String, dynamic>> health() async {
    return _client.authGet('/health');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AuthResult _parseAuthResult(Map<String, dynamic> data) {
    final token = data['token'] as String?;
    final user = data['user'] as Map<String, dynamic>?;

    if (token == null || user == null) {
      throw const ApiException(message: 'Unexpected response from server.');
    }

    return AuthResult(
      token: token,
      userId: user['id']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
    );
  }
}

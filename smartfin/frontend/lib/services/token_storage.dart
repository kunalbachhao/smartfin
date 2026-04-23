import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists and retrieves the JWT token using the OS secure enclave
/// (Android Keystore / iOS Keychain) via [FlutterSecureStorage].
///
/// Performance notes:
/// - [_cache] holds an in-memory copy of all three values after the first read
///   so subsequent calls (e.g. _authHeaders() on every request) never hit the
///   Keychain/Keystore again.
/// - [saveToken] / [saveUser] write to storage AND update the cache atomically.
/// - [clear] wipes both storage and cache.
class TokenStorage {
  static const _tokenKey  = 'auth_token';
  static const _emailKey  = 'auth_email';
  static const _userIdKey = 'auth_user_id';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
  );

  // ── In-memory cache ────────────────────────────────────────────────────────
  // Populated on first read; invalidated on clear().
  // This eliminates repeated Keychain/Keystore round-trips for every
  // authenticated HTTP request.

  static String? _cachedToken;
  static String? _cachedEmail;
  static String? _cachedUserId;
  static bool    _cacheLoaded = false;

  /// Loads all three values from storage in a single pass.
  /// Subsequent calls return immediately from the in-memory cache.
  static Future<void> _ensureLoaded() async {
    if (_cacheLoaded) return;
    // Read all three in parallel — one round-trip per key but concurrent.
    final results = await Future.wait([
      _storage.read(key: _tokenKey),
      _storage.read(key: _emailKey),
      _storage.read(key: _userIdKey),
    ]);
    _cachedToken  = results[0];
    _cachedEmail  = results[1];
    _cachedUserId = results[2];
    _cacheLoaded  = true;
  }

  // ── Token ──────────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    await _ensureLoaded();
    return _cachedToken;
  }

  static Future<void> deleteToken() async {
    _cachedToken = null;
    await _storage.delete(key: _tokenKey);
  }

  // ── User info ──────────────────────────────────────────────────────────────

  /// Writes userId and email to storage concurrently.
  static Future<void> saveUser({
    required String userId,
    required String email,
  }) async {
    _cachedUserId = userId;
    _cachedEmail  = email;
    // Write both keys in parallel — halves the Keychain round-trips.
    await Future.wait([
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _emailKey,  value: email),
    ]);
  }

  static Future<Map<String, String?>> getUser() async {
    await _ensureLoaded();
    return {'userId': _cachedUserId, 'email': _cachedEmail};
  }

  // ── Clear all ──────────────────────────────────────────────────────────────

  static Future<void> clear() async {
    // Wipe cache first so any concurrent reads see null immediately.
    _cachedToken  = null;
    _cachedEmail  = null;
    _cachedUserId = null;
    _cacheLoaded  = true; // cache is valid — it's just empty now

    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _emailKey),
      _storage.delete(key: _userIdKey),
    ]);
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

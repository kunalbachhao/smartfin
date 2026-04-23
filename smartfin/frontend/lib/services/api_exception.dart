/// Structured exception thrown by [ApiClient] for all non-2xx responses
/// and network-level failures. Never exposes raw Dart exception strings.
class ApiException implements Exception {
  final int?   statusCode;
  final String message;
  final bool   isTimeout;

  const ApiException({
    this.statusCode,
    required this.message,
    this.isTimeout = false,
  });

  bool get isNetworkError  => statusCode == null && !isTimeout;
  bool get isRateLimited   => statusCode == 429;
  bool get isUnauthorized  => statusCode == 401;
  bool get isConflict      => statusCode == 409;
  bool get isServerError   => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown by any service client when a request fails — network error,
/// non-2xx response, auth failure, or unparseable body. UI layers catch
/// this type generically and show [message] rather than raw exceptions.
class ArrException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const ArrException(this.message, {this.statusCode, this.cause});

  factory ArrException.unauthorized() =>
      const ArrException('Invalid or missing API key', statusCode: 401);

  factory ArrException.notFound() =>
      const ArrException('Resource not found', statusCode: 404);

  factory ArrException.network(Object cause) =>
      ArrException('Could not reach the server', cause: cause);

  factory ArrException.unexpectedStatus(int statusCode, String body) =>
      ArrException(
        'Unexpected response ($statusCode)',
        statusCode: statusCode,
        cause: body,
      );

  @override
  String toString() => 'ArrException: $message'
      '${statusCode != null ? ' (status $statusCode)' : ''}';
}

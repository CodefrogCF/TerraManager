class SharedApiException implements Exception {
  const SharedApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

class SharedConnectionException implements Exception {
  const SharedConnectionException();

  @override
  String toString() => 'The shared server is unreachable.';
}

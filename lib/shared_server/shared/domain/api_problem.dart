class ApiProblem implements Exception {
  final int status;
  final String code;
  final String message;

  const ApiProblem(this.status, this.code, this.message);
}

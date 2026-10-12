class ApiException implements Exception {
  final int statusCode;
  final String mensaje;

  const ApiException(this.statusCode, this.mensaje);

  @override
  String toString() => 'ApiException($statusCode): $mensaje';
}
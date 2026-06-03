class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;

  factory ApiException.fromStatusCode(int statusCode, [String? message]) {
    return switch (statusCode) {
      400 => ApiException(message: message ?? 'Solicitud inválida.', statusCode: statusCode, code: 'BAD_REQUEST'),
      401 => const ApiException(message: 'Sesión expirada. Por favor inicia sesión nuevamente.', statusCode: 401, code: 'UNAUTHORIZED'),
      403 => const ApiException(message: 'No tienes permisos para realizar esta acción.', statusCode: 403, code: 'FORBIDDEN'),
      404 => const ApiException(message: 'El recurso solicitado no fue encontrado.', statusCode: 404, code: 'NOT_FOUND'),
      422 => ApiException(message: message ?? 'Los datos enviados no son válidos.', statusCode: statusCode, code: 'UNPROCESSABLE'),
      429 => const ApiException(message: 'Demasiadas solicitudes. Intenta más tarde.', statusCode: 429, code: 'RATE_LIMIT'),
      >= 500 => const ApiException(message: 'Error del servidor. Intenta más tarde.', statusCode: 500, code: 'SERVER_ERROR'),
      _ => ApiException(message: message ?? 'Ocurrió un error inesperado.', statusCode: statusCode),
    };
  }

  factory ApiException.network() => const ApiException(
        message: 'Sin conexión a internet. Verifica tu conexión e intenta nuevamente.',
        code: 'NETWORK_ERROR',
      );

  factory ApiException.timeout() => const ApiException(
        message: 'La solicitud tardó demasiado. Intenta nuevamente.',
        code: 'TIMEOUT',
      );

  factory ApiException.unknown([String? detail]) => ApiException(
        message: 'Ocurrió un error inesperado. Intenta nuevamente.',
        code: 'UNKNOWN',
      );

  @override
  String toString() => 'ApiException($code): $message';
}

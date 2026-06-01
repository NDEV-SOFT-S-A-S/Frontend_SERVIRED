import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

class NetworkInterceptor extends Interceptor {
  const NetworkInterceptor({required this.secureStorage});

  final SecureStorage secureStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await secureStorage.getAuthToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['Content-Type'] = 'application/json';
    options.headers['Accept'] = 'application/json';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        ApiException.timeout(),
      DioExceptionType.connectionError => ApiException.network(),
      DioExceptionType.badResponse => ApiException.fromStatusCode(
          err.response?.statusCode ?? 0,
          _extractMessage(err.response),
        ),
      _ => ApiException.unknown(),
    };

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: exception,
        message: exception.message,
        type: err.type,
        response: err.response,
      ),
    );
  }

  String? _extractMessage(Response? response) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? data['error'] as String?;
      }
    } catch (_) {}
    return null;
  }
}

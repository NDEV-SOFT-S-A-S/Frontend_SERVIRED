import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'network_interceptor.dart';

class DioClient {
  DioClient._();

  static Dio create({required SecureStorage secureStorage}) {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? '';

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(NetworkInterceptor(secureStorage: secureStorage));

    return dio;
  }
}

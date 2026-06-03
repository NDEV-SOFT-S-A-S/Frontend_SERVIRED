import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_exception.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponse> login(LoginRequest request);
  Future<void> requestPasswordRecovery(String identifier);
  Future<void> verifyOtp({required String identifier, required String otp, required String flow});
  Future<void> resetPassword({required String token, required String newPassword});
  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  @override
  Future<LoginResponse> login(LoginRequest request) async {
    // TODO(backend): remove when /auth/login endpoint is deployed.
    const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
    if (kDebugMode || useMock) {
      await Future.delayed(const Duration(milliseconds: 800));
      return LoginResponse(
        token: 'mock-token-dev',
        refreshToken: 'mock-refresh-token-dev',
        user: UserModel(
          id: '1',
          documentType: request.documentType,
          documentNumber: request.documentNumber,
          fullName: 'Usuario Demo',
          email: 'demo@servired.com',
          phone: '3001234567',
          birthDate: '1990-01-01',
        ),
      );
    }
    try {
      final response = await dio.post('/auth/login', data: request.toJson());
      return LoginResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException.unknown();
    }
  }

  @override
  Future<void> requestPasswordRecovery(String identifier) async {
    // TODO(backend): remove when /auth/recover-password endpoint is deployed.
    const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
    if (kDebugMode || useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return;
    }
    try {
      await dio.post('/auth/recover-password', data: {'identifier': identifier});
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException.unknown();
    }
  }

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String otp,
    required String flow,
  }) async {
    try {
      await dio.post('/auth/verify-otp', data: {
        'identifier': identifier,
        'otp': otp,
        'flow': flow,
      });
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException.unknown();
    }
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await dio.post('/auth/reset-password', data: {
        'token': token,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException.unknown();
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post('/auth/logout');
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error as ApiException : ApiException.unknown();
    }
  }
}

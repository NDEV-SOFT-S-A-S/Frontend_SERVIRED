import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/login_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.secureStorage,
  });

  final AuthRemoteDataSource remoteDataSource;
  final SecureStorage secureStorage;

  @override
  Future<({String token, String refreshToken, UserEntity user})> login({
    required String documentType,
    required String documentNumber,
    required String password,
  }) async {
    final response = await remoteDataSource.login(
      LoginRequest(
        documentType: documentType,
        documentNumber: documentNumber,
        password: password,
      ),
    );

    await secureStorage.saveAuthToken(response.token);
    await secureStorage.saveRefreshToken(response.refreshToken);
    await secureStorage.saveUserId(response.user.id);

    return (
      token: response.token,
      refreshToken: response.refreshToken,
      user: response.user.toEntity(),
    );
  }

  @override
  Future<void> requestPasswordRecovery({required String identifier}) =>
      remoteDataSource.requestPasswordRecovery(identifier);

  @override
  Future<void> verifyOtp({
    required String identifier,
    required String otp,
    required String flow,
  }) =>
      remoteDataSource.verifyOtp(identifier: identifier, otp: otp, flow: flow);

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) =>
      remoteDataSource.resetPassword(token: token, newPassword: newPassword);

  @override
  Future<void> logout() async {
    try {
      await remoteDataSource.logout();
    } on ApiException {
      // Ignorar errores de red al cerrar sesión - igual se limpia el storage
    } finally {
      await secureStorage.clearAll();
    }
  }
}

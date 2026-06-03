import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<({String token, String refreshToken, UserEntity user})> login({
    required String documentType,
    required String documentNumber,
    required String password,
  });

  Future<void> requestPasswordRecovery({required String identifier});

  Future<void> verifyOtp({
    required String identifier,
    required String otp,
    required String flow,
  });

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> logout();
}

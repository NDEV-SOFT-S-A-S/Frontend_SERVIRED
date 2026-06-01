import '../repositories/auth_repository.dart';

class RequestPasswordRecoveryUseCase {
  const RequestPasswordRecoveryUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String identifier}) =>
      _repository.requestPasswordRecovery(identifier: identifier);
}

class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String identifier,
    required String otp,
    required String flow,
  }) =>
      _repository.verifyOtp(identifier: identifier, otp: otp, flow: flow);
}

class ResetPasswordUseCase {
  const ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({
    required String token,
    required String newPassword,
  }) =>
      _repository.resetPassword(token: token, newPassword: newPassword);
}

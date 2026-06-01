import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<({String token, String refreshToken, UserEntity user})> call({
    required String documentType,
    required String documentNumber,
    required String password,
  }) {
    return _repository.login(
      documentType: documentType,
      documentNumber: documentNumber,
      password: password,
    );
  }
}

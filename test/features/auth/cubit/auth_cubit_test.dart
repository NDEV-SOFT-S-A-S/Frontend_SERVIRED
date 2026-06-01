import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/auth/domain/entities/user_entity.dart';
import 'package:servired_app/features/auth/domain/usecases/login_usecase.dart';
import 'package:servired_app/features/auth/domain/usecases/recover_password_usecase.dart';
import 'package:servired_app/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:servired_app/features/auth/presentation/cubit/auth_state.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}
class MockRequestPasswordRecoveryUseCase extends Mock implements RequestPasswordRecoveryUseCase {}
class MockVerifyOtpUseCase extends Mock implements VerifyOtpUseCase {}
class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

// DateTime no es const — se declara como variable final de nivel superior
final _testUser = UserEntity(
  id: '123',
  documentType: 'CC',
  documentNumber: '1234567890',
  fullName: 'Usuario Test',
  email: 'test@servired.com',
  phone: '3001234567',
  birthDate: DateTime(1990, 1, 1),
);

void main() {
  late MockLoginUseCase loginUseCase;
  late MockRequestPasswordRecoveryUseCase requestPasswordRecovery;
  late MockVerifyOtpUseCase verifyOtp;
  late MockResetPasswordUseCase resetPassword;

  setUp(() {
    loginUseCase = MockLoginUseCase();
    requestPasswordRecovery = MockRequestPasswordRecoveryUseCase();
    verifyOtp = MockVerifyOtpUseCase();
    resetPassword = MockResetPasswordUseCase();
  });

  AuthCubit buildCubit() => AuthCubit(
        loginUseCase: loginUseCase,
        requestPasswordRecoveryUseCase: requestPasswordRecovery,
        verifyOtpUseCase: verifyOtp,
        resetPasswordUseCase: resetPassword,
      );

  group('AuthCubit - login', () {
    blocTest<AuthCubit, AuthState>(
      'emite [loading, success] cuando el login es exitoso',
      build: buildCubit,
      act: (cubit) {
        when(() => loginUseCase(
              documentType: any(named: 'documentType'),
              documentNumber: any(named: 'documentNumber'),
              password: any(named: 'password'),
            )).thenAnswer(
          (_) async => (token: 'tok', refreshToken: 'ref', user: _testUser),
        );
        cubit.login(
          documentType: 'CC',
          documentNumber: '1234567890',
          password: 'pass1234',
        );
      },
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        AuthState(status: AuthStatus.success, user: _testUser),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'emite [loading, error] cuando el login falla con ApiException',
      build: buildCubit,
      act: (cubit) {
        when(() => loginUseCase(
              documentType: any(named: 'documentType'),
              documentNumber: any(named: 'documentNumber'),
              password: any(named: 'password'),
            )).thenThrow(
          const ApiException(message: 'Credenciales inválidas.', statusCode: 401),
        );
        cubit.login(
          documentType: 'CC',
          documentNumber: '1234567890',
          password: 'wrongpass',
        );
      },
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.error, errorMessage: 'Credenciales inválidas.'),
      ],
    );
  });
}

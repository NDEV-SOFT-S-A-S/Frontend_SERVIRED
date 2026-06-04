import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/recover_password_usecase.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LoginUseCase loginUseCase,
    required RequestPasswordRecoveryUseCase requestPasswordRecoveryUseCase,
    required VerifyOtpUseCase verifyOtpUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
  })  : _loginUseCase = loginUseCase,
        _requestPasswordRecoveryUseCase = requestPasswordRecoveryUseCase,
        _verifyOtpUseCase = verifyOtpUseCase,
        _resetPasswordUseCase = resetPasswordUseCase,
        super(const AuthState());

  final LoginUseCase _loginUseCase;
  final RequestPasswordRecoveryUseCase _requestPasswordRecoveryUseCase;
  final VerifyOtpUseCase _verifyOtpUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;

  Future<void> login({
    required String documentType,
    required String documentNumber,
    required String password,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final result = await _loginUseCase(
        documentType: documentType,
        documentNumber: documentNumber,
        password: password,
      );
      emit(state.copyWith(status: AuthStatus.success, user: result.user));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Ocurrió un error inesperado. Intenta nuevamente.',
      ));
    }
  }

  Future<void> requestPasswordRecovery({required String identifier}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _requestPasswordRecoveryUseCase(identifier: identifier);
      emit(state.copyWith(status: AuthStatus.otpSent, otpDestination: identifier));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No pudimos enviar el código. Intenta nuevamente.',
      ));
    }
  }

  Future<void> verifyOtp({
    required String identifier,
    required String otp,
    required String flow,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _verifyOtpUseCase(identifier: identifier, otp: otp, flow: flow);
      emit(state.copyWith(status: AuthStatus.success));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Código inválido o expirado. Intenta nuevamente.',
      ));
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _resetPasswordUseCase(token: token, newPassword: newPassword);
      emit(state.copyWith(status: AuthStatus.passwordReset));
    } on ApiException catch (e) {
      emit(state.copyWith(status: AuthStatus.error, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'No pudimos cambiar tu contraseña. Intenta nuevamente.',
      ));
    }
  }

  void clearError() {
    if (state.status == AuthStatus.error) {
      emit(state.copyWith(status: AuthStatus.initial));
    }
  }

  /// Evita que un modal de login reaccione de nuevo a un login ya completado.
  void clearAuthStatus() {
    if (state.status == AuthStatus.success ||
        state.status == AuthStatus.otpSent) {
      emit(state.copyWith(status: AuthStatus.initial));
    }
  }

  // Solo para builds con USE_MOCK=true — simula sesión activa sin I/O.
  void emitMockSuccess() {
    emit(state.copyWith(status: AuthStatus.success));
  }

  /// Emitido al confirmar el código OTP del registro.
  /// Diferencia el éxito de registro del éxito de login para que la
  /// HomeScreen pueda mostrar el toast de bienvenida.
  void emitRegistrationSuccess() {
    emit(state.copyWith(status: AuthStatus.registrationSuccess));
  }
}

import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

enum AuthStatus { initial, loading, success, error, otpSent, passwordReset, registrationSuccess }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.otpDestination,
    this.resetToken,
  });

  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final String? otpDestination;
  final String? resetToken;

  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    String? otpDestination,
    String? resetToken,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      otpDestination: otpDestination ?? this.otpDestination,
      resetToken: resetToken ?? this.resetToken,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, otpDestination, resetToken];
}

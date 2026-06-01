import 'user_model.dart';

class LoginResponse {
  const LoginResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  final String token;
  final String refreshToken;
  final UserModel user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        token: json['token'] as String,
        refreshToken: json['refresh_token'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}

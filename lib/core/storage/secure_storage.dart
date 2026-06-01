import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  const SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveAuthToken(String token) =>
      _storage.write(key: AppConstants.kAuthToken, value: token);

  Future<String?> getAuthToken() =>
      _storage.read(key: AppConstants.kAuthToken);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: AppConstants.kRefreshToken, value: token);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.kRefreshToken);

  Future<void> saveUserId(String userId) =>
      _storage.write(key: AppConstants.kUserId, value: userId);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.kUserId);

  Future<void> clearAll() => _storage.deleteAll();
}

import 'package:get_it/get_it.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/recover_password_usecase.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

final GetIt sl = GetIt.instance;

void setupDependencies() {
  // Core
  sl.registerLazySingleton<SecureStorage>(() => const SecureStorage());
  sl.registerLazySingleton(() => DioClient.create(secureStorage: sl<SecureStorage>()));

  // Auth - Data
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl()),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      secureStorage: sl(),
    ),
  );

  // Auth - Domain
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RequestPasswordRecoveryUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));

  // Auth - Presentation
  sl.registerFactory(
    () => AuthCubit(
      loginUseCase: sl(),
      requestPasswordRecoveryUseCase: sl(),
      verifyOtpUseCase: sl(),
      resetPasswordUseCase: sl(),
    ),
  );
}

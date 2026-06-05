import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/recover_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/juegos/presentation/screens/juegos_screen.dart';
import '../../features/juegos/presentation/screens/chance_millonario_screen.dart';
import '../../features/juegos/presentation/screens/chance_tradicional_screen.dart';
import '../../features/juegos/presentation/screens/dominguero_screen.dart';
import '../../features/juegos/presentation/screens/paga_todo_screen.dart';
import '../../features/juegos/presentation/screens/superwin_screen.dart';
import '../../features/juegos/presentation/screens/pata_millonaria_screen.dart';
import '../../features/juegos/presentation/screens/baloto_revancha_screen.dart';
import '../../features/resultados/presentation/screens/resultados_screen.dart';
import '../../features/carrito/presentation/screens/carrito_screen.dart';
import '../../shared/screens/placeholder_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String recoverPassword = '/recover-password';
  static const String otpVerification = '/otp-verification';
  static const String home = '/home';
  static const String juegos = '/juegos';
  static const String dominguero        = '/juegos/dominguero';
  static const String superwin          = '/juegos/superwin';
  static const String chanceMillonario  = '/juegos/chance-millonario';
  static const String chanceTradicional = '/juegos/chance-tradicional';
  static const String pagaTodo          = '/juegos/paga-todo';
  static const String pataMillonaria    = '/juegos/pata-millonaria';
  static const String balotoRevancha    = '/juegos/baloto-revancha';
  static const String carrito           = '/carrito';
  static const String pagos = '/pagos';
  static const String wallet = '/wallet';
  static const String resultados = '/resultados';
}

class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.recoverPassword,
        name: 'recover-password',
        builder: (context, state) => const RecoverPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        name: 'otp-verification',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            destination: extra?['destination'] as String? ?? '',
            flow: extra?['flow'] as OtpFlow? ?? OtpFlow.login,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.juegos,
        name: 'juegos',
        builder: (context, state) => const JuegosScreen(),
      ),
      GoRoute(
        path: AppRoutes.dominguero,
        name: 'dominguero',
        builder: (context, state) => const DomingueroScreen(),
      ),
      GoRoute(
        path: AppRoutes.superwin,
        name: 'superwin',
        builder: (context, state) => const SuperwinScreen(),
      ),
      GoRoute(
        path: AppRoutes.chanceMillonario,
        name: 'chance-millonario',
        builder: (context, state) => const ChanceMillonarioScreen(),
      ),
      GoRoute(
        path: AppRoutes.chanceTradicional,
        name: 'chance-tradicional',
        builder: (context, state) => const ChanceTradicionalScreen(),
      ),
      GoRoute(
        path: AppRoutes.pagaTodo,
        name: 'paga-todo',
        builder: (context, state) => const PagaTodoScreen(),
      ),
      GoRoute(
        path: AppRoutes.pataMillonaria,
        name: 'pata-millonaria',
        builder: (context, state) => const PataMillonariaScreen(),
      ),
      GoRoute(
        path: AppRoutes.balotoRevancha,
        name: 'baloto-revancha',
        builder: (context, state) => const BalotoRevanchaScreen(),
      ),
      GoRoute(
        path: AppRoutes.resultados,
        name: 'resultados',
        builder: (context, state) => const ResultadosScreen(),
      ),
      GoRoute(
        path: AppRoutes.carrito,
        name: 'carrito',
        builder: (context, state) {
          final items = state.extra as List<CarritoItem>? ?? [];
          return CarritoScreen(items: items);
        },
      ),
      GoRoute(
        path: AppRoutes.pagos,
        name: 'pagos',
        builder: (context, state) => const PlaceholderScreen(title: 'Pagos'),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        builder: (context, state) => const PlaceholderScreen(title: 'Wallet'),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Página no encontrada: ${state.uri}'),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../../shared/utils/auth_modal.dart';
import '../widgets/acumulados_section_widget.dart';
import '../widgets/banner_carousel_widget.dart';
import '../widgets/footer_widget.dart';
import '../widgets/juegos_section_widget.dart';
import '../widgets/navbar_widget.dart';
import '../widgets/resultados_carousel_widget.dart';
import '../widgets/section_header_widget.dart';

// Figma node 561:8092 — Landing page (sin logueo)
// Figma node 561:10658 — Landing sesión ya iniciada (logueado)
//
// La pantalla es la misma en ambos casos. Solo cambia el header:
//   · Sin logueo (561:8147): h-104, botones "Inicia sesión" + "Regístrate"
//   · Logueado (561:10713): h-120, controles Saldo + Wallet + Carrito + Avatar
//
// El estado de sesión se lee desde AuthCubit (proveído en root por MultiBlocProvider).
// Al login exitoso, AuthState.user se popula → BlocBuilder reconstruye el navbar.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const bool _useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: false);

  bool _showWelcomeToast = false;

  @override
  void initState() {
    super.initState();
    // USE_MOCK: emite AuthStatus.success para previsualizar el navbar logueado.
    if (_useMock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AuthCubit>().emitMockSuccess();
      });
    }
  }

  // Altura del header: 44px en móvil (<720px) · Figma node 561:12013 h=44
  static double _navbarHeight(double screenW, bool loggedIn) {
    if (screenW < 720) return 44.0;
    return loggedIn ? 120.0 : 104.0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      // Solo escucha cambios de estado relevantes para el toast.
      listenWhen: (prev, curr) =>
          prev.status != AuthStatus.registrationSuccess &&
          curr.status == AuthStatus.registrationSuccess,
      listener: (context, state) {
        setState(() => _showWelcomeToast = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showWelcomeToast = false);
        });
      },
      // Solo reconstruye cuando cambia el estado de sesión (logged in/out).
      buildWhen: (prev, curr) =>
          (prev.user == null) != (curr.user == null) ||
          (prev.status == AuthStatus.success) !=
              (curr.status == AuthStatus.success) ||
          prev.status != curr.status,
      builder: (context, authState) {
        final bool isLoggedIn =
            authState.user != null ||
            authState.status == AuthStatus.success ||
            authState.status == AuthStatus.registrationSuccess;

        final double navbarHeight = _navbarHeight(
          MediaQuery.of(context).size.width,
          isLoggedIn,
        );

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              // ── Contenido scrollable ─────────────────────────────────────
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Espacio reservado para el navbar fijo (h varía por estado)
                    SizedBox(height: navbarHeight),

                    // ── Contenido principal — max-width 1728, centrado ─────
                    // Figma 561:8094: flex-col gap-[16px] px-[20px] py-[32px]
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Banner carousel ──────────────────────────────
                            const SizedBox(height: 16),
                            // Móvil: sin padding → banner edge-to-edge
                            // Desktop: left:20 para el efecto peek del carrusel
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Padding(
                                  padding: constraints.maxWidth < 720
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.only(left: 20),
                                  child: const BannerCarouselWidget(),
                                );
                              },
                            ),

                            // ── Acumulados ───────────────────────────────────
                            const SizedBox(height: 16),
                            // Móvil: sin padding → el widget maneja su propio px-16
                            // Desktop: px-20 para alineación con el resto
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isMobile =
                                    constraints.maxWidth < 720;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 0 : 20,
                                  ),
                                  child: const AcumuladosSectionWidget(),
                                );
                              },
                            ),

                            // ── Resultados loterías y sorteos ────────────────
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isMobile =
                                    constraints.maxWidth < 720;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 16 : 20,
                                  ),
                                  child: SectionHeaderWidget(
                                    icon: SvgPicture.asset(
                                      AppAssets.iconResultados,
                                      width: 28,
                                      height: 28,
                                    ),
                                    title: 'Resultados loterías y sorteos',
                                    showVerMas: true,
                                    onVerMas: () =>
                                        context.go(AppRoutes.resultados),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Móvil: sin padding → scroll táctil desde el borde
                            // Desktop: left:20 alineado al resto de secciones
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Padding(
                                  padding: constraints.maxWidth < 720
                                      ? EdgeInsets.zero
                                      : const EdgeInsets.only(left: 20),
                                  child: const ResultadosCarouselWidget(),
                                );
                              },
                            ),

                            // ── Juegos ───────────────────────────────────────
                            const SizedBox(height: 16),
                            // Móvil: sin padding → el widget maneja su propio px-16
                            // Desktop: px-20
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isMobile =
                                    constraints.maxWidth < 720;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 0 : 20,
                                  ),
                                  child: const JuegosSectionWidget(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Gap entre tarjetas y footer ──────────────────────────
                    const SizedBox(height: 16),

                    // ── Footer — full-width ──────────────────────────────────
                    const FooterWidget(),
                  ],
                ),
              ),

              // ── Toast de bienvenida post-registro ────────────────────────
              if (_showWelcomeToast)
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _WelcomeToast(
                      onDismiss: () =>
                          setState(() => _showWelcomeToast = false),
                    ),
                  ),
                ),

              // ── Navbar fija/sticky — overlay sobre el scroll ──────────────
              // Cambia de variante según isLoggedIn, sin reconstruir el resto.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NavbarWidget(
                  isLoggedIn: isLoggedIn,
                  activeNavItem: 'Inicio',
                  onJuegosTap: () => context.go(AppRoutes.juegos),
                  onResultadosTap: () => context.go(AppRoutes.resultados),
                  // Sin logueo: callbacks de apertura de modales
                  onLoginTap: isLoggedIn
                      ? null
                      : () => _showLoginModal(context),
                  onRegisterTap: isLoggedIn
                      ? null
                      : () => _showRegisterModal(context),
                  // Logueado: callbacks de acciones del usuario (por implementar)
                  onWalletTap: isLoggedIn ? () {} : null,
                  onCartTap:   isLoggedIn ? () {} : null,
                  onAvatarTap: isLoggedIn ? () {} : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Toast de bienvenida post-registro ─────────────────────────────────────────
// Diseño Figma: fondo verde claro · texto verde · icono check · 4 segundos
// AppColors: successLight #E8F5E9 · success #2E7D32

class _WelcomeToast extends StatefulWidget {
  const _WelcomeToast({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_WelcomeToast> createState() => _WelcomeToastState();
}

class _WelcomeToastState extends State<_WelcomeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.successLight, // #E8F5E9
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success, // #2E7D32
              size: 24,
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Bienvenido a Gane ¡ya puedes empezar a jugar!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onDismiss,
              child: const Icon(
                Icons.close_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

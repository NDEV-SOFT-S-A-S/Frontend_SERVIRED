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

        final double screenW   = MediaQuery.sizeOf(context).width;
        final bool   isMobile  = screenW < 720;
        // Vista mobile autenticada: layout y orden de secciones diferente al desktop.
        final bool   isMobAuth = isMobile && isLoggedIn;
        final String firstName = _extractFirstName(authState.user);

        final double navbarHeight = _navbarHeight(screenW, isLoggedIn);

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
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Saludo (solo mobile autenticado) ────────────
                            if (isMobAuth) ...[
                              const SizedBox(height: 16),
                              _MobileGreeting(firstName: firstName),
                            ],

                            // ── Banner carousel ──────────────────────────────
                            const SizedBox(height: 16),
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

                            // ── Acumulados (desktop: antes de resultados) ────
                            if (!isMobAuth) ...[
                              const SizedBox(height: 16),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          constraints.maxWidth < 720 ? 0 : 20,
                                    ),
                                    child: const AcumuladosSectionWidget(),
                                  );
                                },
                              ),
                            ],

                            // ── Resultados loterías y sorteos ────────────────
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bool mob = constraints.maxWidth < 720;
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: mob ? 16 : 20,
                                  ),
                                  child: SectionHeaderWidget(
                                    icon: SvgPicture.asset(
                                      AppAssets.iconResultados,
                                      width: mob ? 24 : 28,
                                      height: mob ? 24 : 28,
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

                            // ── Acumulados (mobile auth: después de resultados)
                            if (isMobAuth) ...[
                              const SizedBox(height: 16),
                              const AcumuladosSectionWidget(),
                            ],

                            // ── Juegos ───────────────────────────────────────
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal:
                                        constraints.maxWidth < 720 ? 0 : 20,
                                  ),
                                  child: const JuegosSectionWidget(),
                                );
                              },
                            ),

                            // Padding inferior para que el bottom nav no tape contenido
                            if (isMobAuth) const SizedBox(height: 96),
                          ],
                        ),
                      ),
                    ),

                    // ── Gap + Footer — oculto en mobile autenticado ──────────
                    if (!isMobAuth) ...[
                      const SizedBox(height: 16),
                      const FooterWidget(),
                    ],
                  ],
                ),
              ),

              // ── Toast de bienvenida post-registro ────────────────────────
              if (_showWelcomeToast)
                Positioned(
                  bottom: isMobAuth ? 100 : 32,
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NavbarWidget(
                  isLoggedIn: isLoggedIn,
                  activeNavItem: 'Inicio',
                  onJuegosTap: () => context.go(AppRoutes.juegos),
                  onResultadosTap: () => context.go(AppRoutes.resultados),
                  onLoginTap: isLoggedIn
                      ? null
                      : () => showLoginRequired(context),
                  onRegisterTap: isLoggedIn
                      ? null
                      : () => showLoginRequired(context),
                  onWalletTap: isLoggedIn ? () {} : null,
                  onCartTap:   isLoggedIn ? () {} : null,
                  onAvatarTap: isLoggedIn ? () {} : null,
                  onSaldoTap:  isLoggedIn ? () {} : null,
                ),
              ),

              // ── Bottom navigation mobile autenticado ──────────────────────
              // Solo visible en mobile (<720px) con sesión iniciada.
              // No interfiere con desktop/web.
              if (isMobAuth)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _MobileBottomNav(
                    activeItem: 'Inicio',
                    onInicioTap: () {},
                    onResultadosTap: () => context.go(AppRoutes.resultados),
                    onJuegosTap: () => context.go(AppRoutes.juegos),
                    onPerfilTap: () {},
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Extrae el primer nombre del fullName del usuario.
/// Fallback: 'amigo' si el usuario no tiene nombre.
String _extractFirstName(UserEntity? user) {
  if (user == null) return 'amigo';
  final trimmed = user.fullName.trim();
  if (trimmed.isEmpty) return 'amigo';
  return trimmed.split(' ').first;
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

// ── Saludo mobile autenticado ─────────────────────────────────────────────────
// Figma mobile authenticated: "Hola {nombre} ¡Buena suerte hoy!"
// Inter Bold 22px · blanco · left-aligned · px-20

class _MobileGreeting extends StatelessWidget {
  const _MobileGreeting({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Hola $firstName ¡Buena suerte hoy!',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.neutralWhite,
          height: 1.3,
        ),
      ),
    );
  }
}

// ── Bottom navigation mobile autenticado ──────────────────────────────────────
// Figma: flotante · bordes redondeados · fijo abajo · 4 ítems
// Activo "Inicio": fondo amarillo navActiveYellow (#feca0c) · texto/ícono oscuro
// Inactivo: texto/ícono blanco

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.activeItem,
    this.onInicioTap,
    this.onResultadosTap,
    this.onJuegosTap,
    this.onPerfilTap,
  });

  final String activeItem;
  final VoidCallback? onInicioTap;
  final VoidCallback? onResultadosTap;
  final VoidCallback? onJuegosTap;
  final VoidCallback? onPerfilTap;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, safeBottom + 12),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: const Color(0xFF1A2750),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomNavItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              isActive: activeItem == 'Inicio',
              onTap: onInicioTap,
            ),
            _BottomNavItem(
              icon: Icons.emoji_events_rounded,
              label: 'Resultados',
              isActive: activeItem == 'Resultados',
              onTap: onResultadosTap,
            ),
            _BottomNavItem(
              icon: Icons.sports_esports_rounded,
              label: 'Juegos',
              isActive: activeItem == 'Juegos',
              onTap: onJuegosTap,
            ),
            _BottomNavItem(
              icon: Icons.person_outline_rounded,
              label: 'Perfil',
              isActive: activeItem == 'Perfil',
              onTap: onPerfilTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const Color activeColor   = Color(0xFF111827); // texto/ícono sobre amarillo
    final Color inactiveColor = Colors.white.withValues(alpha: 0.75);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.navActiveYellow,
                borderRadius: BorderRadius.circular(14),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

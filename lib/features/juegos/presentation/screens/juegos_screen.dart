import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../home/presentation/widgets/juego_card_widget.dart';
import '../../../home/presentation/widgets/juegos_section_widget.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';

// Figma node 1127:10116 — Listado completo de Juegos
// Banner morado superior + grid responsive de tarjetas de juego

class JuegosScreen extends StatelessWidget {
  const JuegosScreen({super.key});

  static double _navbarHeight(double screenW, bool loggedIn) {
    if (screenW < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) =>
          (prev.user == null) != (curr.user == null) ||
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
              // ── Contenido scrollable ───────────────────────────────────────
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: navbarHeight),

                    // ── Banner morado superior ─────────────────────────────
                    const _JuegosBanner(),

                    // ── Grid de tarjetas ───────────────────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          child: _JuegosGrid(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),

              // ── Navbar fija — "Juegos" activo ──────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NavbarWidget(
                  isLoggedIn: isLoggedIn,
                  activeNavItem: 'Juegos',
                  onInicioTap: () => context.go(AppRoutes.home),
                  onResultadosTap: () => context.go(AppRoutes.resultados),
                  onWalletTap: isLoggedIn ? () {} : null,
                  onCartTap: isLoggedIn ? () {} : null,
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

// ── Banner superior morado ─────────────────────────────────────────────────────
// Figma 1127:10116: fondo indigo-navy con sparkles y texto centrado en blanco

class _JuegosBanner extends StatelessWidget {
  const _JuegosBanner();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 720;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF181966),
            Color(0xFF2E318E),
            Color(0xFF181966),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Sparkles esquina izquierda ─────────────────────────────────
          Positioned(
            left: isMobile ? 10 : 48,
            top: 14,
            child: const _SparkleIcon(size: 30),
          ),
          Positioned(
            left: isMobile ? 26 : 96,
            bottom: 10,
            child: const _SparkleIcon(size: 13, opacity: 0.5),
          ),

          // ── Sparkles esquina derecha ───────────────────────────────────
          Positioned(
            right: isMobile ? 10 : 48,
            top: 10,
            child: const _SparkleIcon(size: 42),
          ),
          Positioned(
            right: isMobile ? 26 : 96,
            bottom: 8,
            child: const _SparkleIcon(size: 17, opacity: 0.5),
          ),

          // ── Texto principal ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 64 : 160,
              vertical: isMobile ? 28 : 44,
            ),
            child: Text(
              'Descubre los juegos de chance que pueden cambiar tu suerte',
              style: GoogleFonts.inter(
                fontSize: isMobile ? 20 : 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SparkleIcon extends StatelessWidget {
  const _SparkleIcon({required this.size, this.opacity = 1.0});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size),
    );
  }
}

// ── Grid responsive de tarjetas de juego ──────────────────────────────────────
// Desktop ≥1400px: 5 col · 900–1399px: 4 col · 600–899px: 3 col · <600px: 2 col
// Las tarjetas escalan proporcionalmente manteniendo el aspect ratio 288:360 de Figma

class _JuegosGrid extends StatelessWidget {
  const _JuegosGrid();

  static int _columns(double width) {
    if (width >= 1400) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final cols = _columns(constraints.maxWidth);
        final cardW =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final cardH = cardW * (360 / 288); // aspect ratio Figma

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (int idx = 0; idx < kJuegos.length; idx++)
              SizedBox(
                width: cardW,
                height: cardH,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 288,
                    height: 360,
                    child: JuegoCardWidget(
                      data: kJuegos[idx],
                      // Solo El Dominguero Millonario (índice 1) navega a su pantalla
                      onTap: idx == 1
                          ? () => context.go(AppRoutes.dominguero)
                          : idx == 6
                              ? () => context.go(AppRoutes.chanceTradicional)
                              : idx == 8
                                  ? () => context.go(AppRoutes.chanceMillonario)
                                  : idx == 9
                                      ? () => context.go(AppRoutes.superwin)
                                      : null,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

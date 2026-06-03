import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';
import '../../../home/presentation/widgets/resultado_card_widget.dart';
import '../../../home/presentation/widgets/section_header_widget.dart';

// Figma node 1133:12213 — Pantalla Resultados
// Banner amarillo + buscador + filtro fecha + Juegos Destacados + listado Resultados

// ── Modelos de datos mock ─────────────────────────────────────────────────────

class _BallData {
  const _BallData(this.number, this.color, {this.textColor = Colors.white});
  final int number;
  final Color color;
  final Color textColor;
}

class _JuegoDestacado {
  const _JuegoDestacado({
    required this.logoUrl,
    required this.nombre,
    required this.balls,
    required this.fecha,
  });
  final String logoUrl;
  final String nombre;
  final List<_BallData> balls;
  final String fecha;
}

const _kJuegosDestacados = [
  _JuegoDestacado(
    logoUrl: AppAssets.logoMiLoto,
    nombre: 'MiLoto',
    balls: [
      _BallData(3,  Color(0xFF1372AE)),
      _BallData(7,  Color(0xFF1372AE)),
      _BallData(8,  Color(0xFF1372AE)),
      _BallData(35, Color(0xFF1372AE)),
      _BallData(38, Color(0xFF1372AE)),
    ],
    fecha: '11 Mayo 2026, Lunes',
  ),
  _JuegoDestacado(
    logoUrl: AppAssets.logoBalotoRevancha,
    nombre: 'Baloto Revancha',
    balls: [
      _BallData(1,  Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(12, Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(13, Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(34, Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(35, Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(15, Color(0xFFDA1414)),
    ],
    fecha: '11 Mayo 2026, Lunes',
  ),
  _JuegoDestacado(
    logoUrl: AppAssets.logoIColorLoto,
    nombre: 'Color Loto',
    balls: [
      _BallData(5, Color(0xFF2C2E6F)),
      _BallData(4, Color(0xFFFDC700), textColor: Color(0xFF09101D)),
      _BallData(4, Color(0xFFDA1414)),
      _BallData(5, Color(0xFFDA1414)),
      _BallData(5, Colors.white, textColor: Color(0xFF09101D)),
      _BallData(1, Colors.black),
    ],
    fecha: '11 Mayo 2026, Lunes',
  ),
];

final _kResultados = [
  for (int i = 0; i < 16; i++)
    ResultadoData(
      logoUrl: i.isEven ? AppAssets.logoRisaralda : AppAssets.logoValle,
      nombre: i.isEven ? 'Lotería del Risaralda' : 'Lotería del Valle',
      fecha: '11 de Mayo 2026',
      numeros: [5, 4, 7, 1],
    ),
];

// ── Pantalla ──────────────────────────────────────────────────────────────────

class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({super.key});

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  /// 0 = Hoy · 1 = Ayer
  int _selectedDay = 0;
  final _searchCtrl = TextEditingController();

  static double _navbarHeight(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) =>
          (p.user == null) != (c.user == null) || p.status != c.status,
      builder: (context, authState) {
        final bool isLoggedIn =
            authState.user != null ||
            authState.status == AuthStatus.success ||
            authState.status == AuthStatus.registrationSuccess;

        final double navH = _navbarHeight(
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
                    SizedBox(height: navH),

                    // ── Banner amarillo ──────────────────────────────────
                    const _ResultadosBanner(),

                    // ── Cuerpo centrado ──────────────────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Buscador ────────────────────────────────
                              _Buscador(controller: _searchCtrl),
                              const SizedBox(height: 24),

                              // ── Filtro Hoy / Ayer / Fecha ────────────────
                              _FiltroFecha(
                                selected: _selectedDay,
                                onChanged: (v) =>
                                    setState(() => _selectedDay = v),
                              ),
                              const SizedBox(height: 32),

                              // ── Juegos Destacados ────────────────────────
                              SectionHeaderWidget(
                                icon: const Icon(
                                  Icons.star_rounded,
                                  size: 28,
                                  color: AppColors.neutralWhite,
                                ),
                                title: 'Juegos Destacados',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Resultados del 11 de mayo de 2026',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: AppColors.neutralWhite
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _JuegosDestacadosGrid(),

                              const SizedBox(height: 32),

                              // ── Resultados ────────────────────────────────
                              SectionHeaderWidget(
                                icon: const Icon(
                                  Icons.star_rounded,
                                  size: 28,
                                  color: AppColors.neutralWhite,
                                ),
                                title: 'Resultados',
                              ),
                              const SizedBox(height: 16),
                              _ResultadosGrid(resultados: _kResultados),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Navbar fija — "Resultados" activo ───────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NavbarWidget(
                  isLoggedIn: isLoggedIn,
                  activeNavItem: 'Resultados',
                  onInicioTap: () => context.go(AppRoutes.home),
                  onJuegosTap: () => context.go(AppRoutes.juegos),
                  onLoginTap: isLoggedIn ? null : () {},
                  onRegisterTap: isLoggedIn ? null : () {},
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

// ── Banner amarillo ───────────────────────────────────────────────────────────
// Figma 1345:3626 — fondo dorado con trofeos a los lados y texto azul centrado

class _ResultadosBanner extends StatelessWidget {
  const _ResultadosBanner();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 720;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isMobile ? 120 : 178),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD700), Color(0xFFFDC700)],
        ),
        // Efecto de profundidad con sombra inferior sutil
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Fondo de bolas (textura decorativa) ─────────────────────────
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: CustomPaint(painter: _BallsTexturePainter()),
            ),
          ),

          // ── Trofeo izquierdo ─────────────────────────────────────────────
          Positioned(
            left: isMobile ? 12 : 64,
            child: _TrophyIcon(size: isMobile ? 56 : 110),
          ),

          // ── Trofeo derecho ───────────────────────────────────────────────
          Positioned(
            right: isMobile ? 12 : 64,
            child: _TrophyIcon(size: isMobile ? 56 : 110),
          ),

          // ── Texto centrado ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 84 : 220,
              vertical: isMobile ? 28 : 44,
            ),
            child: Text(
              'Descubre si tu apuesta fue la ganadora',
              style: GoogleFonts.inter(
                fontSize: isMobile ? 18 : 36,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF093048),
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Trofeo outline en azul marino (ícono de copa)
class _TrophyIcon extends StatelessWidget {
  const _TrophyIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.emoji_events_outlined,
      size: size,
      color: const Color(0xFF093048),
    );
  }
}

// Pintor de bolas decorativas en el fondo del banner
class _BallsTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF093048)
      ..style = PaintingStyle.fill;
    final positions = [
      Offset(size.width * 0.15, size.height * 0.3),
      Offset(size.width * 0.25, size.height * 0.7),
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.85, size.height * 0.65),
      Offset(size.width * 0.5, size.height * 0.8),
      Offset(size.width * 0.4, size.height * 0.15),
      Offset(size.width * 0.6, size.height * 0.5),
    ];
    for (final pos in positions) {
      canvas.drawCircle(pos, size.height * 0.22, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Buscador ──────────────────────────────────────────────────────────────────
// Figma 1347:3613 — pill blanca centrada ~489px, icono lupa + placeholder

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 489),
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(31),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.neutral5,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Buscar número o lotería...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.neutral5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filtro Hoy / Ayer / Fecha ─────────────────────────────────────────────────
// Figma 1250:26604 — segmented control centrado ~489px

class _FiltroFecha extends StatelessWidget {
  const _FiltroFecha({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DayTab(
              label: 'Hoy',
              isActive: selected == 0,
              onTap: () => onChanged(0),
            ),
            const SizedBox(width: 4),
            _DayTab(
              label: 'Ayer',
              isActive: selected == 1,
              onTap: () => onChanged(1),
            ),
            const SizedBox(width: 8),
            // ── Selector de fecha ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '11 De Mayo De 2026',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF09101D) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Grid de Juegos Destacados (3 cards horizontales) ─────────────────────────
// Figma 1184:10691 — 3 cards de 504px con bolas de colores grandes

class _JuegosDestacadosGrid extends StatelessWidget {
  const _JuegosDestacadosGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 720;
        if (isMobile) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _kJuegosDestacados.length; i++) ...[
                  SizedBox(
                    width: 320,
                    child: _JuegoDestacadoCard(data: _kJuegosDestacados[i]),
                  ),
                  if (i < _kJuegosDestacados.length - 1)
                    const SizedBox(width: 16),
                ],
              ],
            ),
          );
        }
        // Desktop: 3 columnas equidistantes
        final gap = 24.0;
        final cardW = (constraints.maxWidth - gap * 2) / 3;
        return Row(
          children: [
            for (int i = 0; i < _kJuegosDestacados.length; i++) ...[
              SizedBox(
                width: cardW,
                child: _JuegoDestacadoCard(data: _kJuegosDestacados[i]),
              ),
              if (i < _kJuegosDestacados.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

// ── Tarjeta de Juego Destacado ────────────────────────────────────────────────
// Figma 1133:15032 "Resultados Especiales" — card blanca con logo + bolas + fecha

class _JuegoDestacadoCard extends StatelessWidget {
  const _JuegoDestacadoCard({required this.data});
  final _JuegoDestacado data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.sombra200,
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Logo ──────────────────────────────────────────────────────────
          SizedBox(
            height: 52,
            child: Image.asset(
              data.logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.casino,
                color: AppColors.neutral5,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Bolas de números ──────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final ball in data.balls)
                _LotteryBall(ball: ball),
            ],
          ),
          const SizedBox(height: 16),

          // ── Fecha ─────────────────────────────────────────────────────────
          Text(
            data.fecha,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.neutral3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LotteryBall extends StatelessWidget {
  const _LotteryBall({required this.ball});
  final _BallData ball;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: ball.color,
        shape: BoxShape.circle,
        border: ball.color == Colors.white
            ? Border.all(color: AppColors.inputBorder, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        ball.number.toString(),
        style: GoogleFonts.inter(
          fontSize: ball.number >= 10 ? 16 : 20,
          fontWeight: FontWeight.w800,
          color: ball.textColor,
        ),
      ),
    );
  }
}

// ── Grid de Resultados ────────────────────────────────────────────────────────
// Figma 1184:10862 — 4 columnas desktop, responsive hacia abajo

class _ResultadosGrid extends StatelessWidget {
  const _ResultadosGrid({required this.resultados});
  final List<ResultadoData> resultados;

  static int _columns(double width) {
    if (width >= 1200) return 4;
    if (width >= 860) return 3;
    if (width >= 560) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final cols = _columns(constraints.maxWidth);
        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in resultados)
              SizedBox(
                width: cardW,
                child: _ResultadoGridCard(data: r),
              ),
          ],
        );
      },
    );
  }
}

// Variante del resultado card para grid (más alta que la del carrusel)
// Reutiliza el mismo diseño visual de ResultadoCardWidget pero en tamaño flexible
class _ResultadoGridCard extends StatelessWidget {
  const _ResultadoGridCard({required this.data});
  final ResultadoData data;

  @override
  Widget build(BuildContext context) {
    // La card del carrusel es 273×146 → mantenemos proporción 273:146 ≈ 1.87
    return AspectRatio(
      aspectRatio: 273 / 146,
      child: ResultadoCardWidget(data: data),
    );
  }
}

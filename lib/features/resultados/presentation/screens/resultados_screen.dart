import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

// Figma node 1133:12213 — Pantalla Resultados (desktop)
// Figma node 1386:35596 — Pantalla Resultados (mobile)

// ── Breakpoint mobile ─────────────────────────────────────────────────────────
const double _kMobileBreak = 720.0;

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
      numeros: [7, 24, 2, 34],
      subtitulo: 'Resultado Oficial',
      serie: 'Serie 1',
    ),
];

// ── Pantalla ──────────────────────────────────────────────────────────────────

class ResultadosScreen extends StatefulWidget {
  const ResultadosScreen({super.key});

  @override
  State<ResultadosScreen> createState() => _ResultadosScreenState();
}

class _ResultadosScreenState extends State<ResultadosScreen> {
  int _selectedDay = 0;
  final _searchCtrl = TextEditingController();
  DateTime _selectedDate = DateTime(2026, 5, 11);

  final _layerLink = LayerLink();
  OverlayEntry? _calendarOverlay;

  static double _navbarHeight(double w, bool loggedIn) {
    if (w < _kMobileBreak) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  @override
  void dispose() {
    _removeCalendar();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _removeCalendar() {
    _calendarOverlay?.remove();
    _calendarOverlay = null;
  }

  void _toggleCalendar() {
    if (_calendarOverlay != null) {
      _removeCalendar();
      return;
    }

    _calendarOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeCalendar,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: _CalendarioWidget(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() => _selectedDate = date);
                  _removeCalendar();
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_calendarOverlay!);
  }

  String _formatDate(DateTime d) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${d.day} De ${meses[d.month]} De ${d.year}';
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

        final double screenW = MediaQuery.of(context).size.width;
        final bool isMobile = screenW < _kMobileBreak;
        final double navH = _navbarHeight(screenW, isLoggedIn);

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              // ── Degradado inferior (Figma node 1386:35598 — solo mobile) ──
              if (isMobile)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 300,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x80000000)],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Contenido scrollable ─────────────────────────────────────
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: navH),
                    if (!isMobile) const SizedBox(height: 24),

                    // ── Banner amarillo ──────────────────────────────────
                    const _ResultadosBanner(),

                    // ── Cuerpo centrado ──────────────────────────────────
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1728),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 50,
                            vertical:   isMobile ? 10 : 32,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ── Buscador ────────────────────────────────
                              _Buscador(controller: _searchCtrl),
                              SizedBox(height: isMobile ? 8 : 24),

                              // ── Filtro Hoy / Ayer / Fecha ────────────────
                              CompositedTransformTarget(
                                link: _layerLink,
                                child: _FiltroFecha(
                                  selected: _selectedDay,
                                  onChanged: (v) =>
                                      setState(() => _selectedDay = v),
                                  dateLabel: _formatDate(_selectedDate),
                                  onDateTap: _toggleCalendar,
                                ),
                              ),
                              SizedBox(height: isMobile ? 14 : 32),

                              // ── Juegos Destacados ────────────────────────
                              SectionHeaderWidget(
                                icon: SvgPicture.asset(
                                  AppAssets.starResultados,
                                  width:  isMobile ? 16 : 28,
                                  height: isMobile ? 16 : 28,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.neutralWhite,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                title: 'Juegos Destacados',
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: isMobile ? 24 : 36,
                                ),
                                child: Text(
                                  'Resultados del 11 de mayo de 2026',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 11 : 13,
                                    fontWeight: isMobile
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: AppColors.neutralWhite
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              SizedBox(height: isMobile ? 8 : 12),
                              _JuegosDestacadosGrid(isMobile: isMobile),

                              SizedBox(height: isMobile ? 14 : 32),

                              // ── Resultados ────────────────────────────────
                              SectionHeaderWidget(
                                icon: SvgPicture.asset(
                                  AppAssets.starResultados,
                                  width:  isMobile ? 16 : 28,
                                  height: isMobile ? 16 : 28,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.neutralWhite,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                title: 'Resultados',
                              ),
                              SizedBox(height: isMobile ? 10 : 16),
                              _ResultadosGrid(
                                resultados: _kResultados,
                                isMobile: isMobile,
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Navbar fija ───────────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
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
// Desktop: Figma 1345:3626 — copa 96px, texto 36px, py 40px
// Mobile:  Figma 1386:36948 — 68px alto, copa 25px, texto 16px Inter Bold #1372ae

class _ResultadosBanner extends StatelessWidget {
  const _ResultadosBanner();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < _kMobileBreak;

    // Mobile: copa 25px, texto 16px, padding v:20 h:10
    // Desktop: copa 96px, texto 36px, padding v:40 h:48
    final copaSize  = isMobile ? 25.0 : 96.0;
    final fontSize  = isMobile ? 16.0 : 36.0;
    final hPad      = isMobile ? 10.0 : 48.0;
    final vPad      = isMobile ? 20.0 : 40.0;
    final gap       = isMobile ? 10.0 : 32.0;
    final radius    = isMobile ? 10.0 :  0.0;

    return Container(
      width: double.infinity,
      margin: isMobile
          ? const EdgeInsets.symmetric(horizontal: 0)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: const Color(0xFFFFE100),
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                AppAssets.frameResultados,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _CopaSvg(size: copaSize),
                SizedBox(width: gap),
                Flexible(
                  child: Text(
                    'Descubre si tu apuesta fue la ganadora',
                    style: GoogleFonts.inter(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1372AE),
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: gap),
                _CopaSvg(size: copaSize),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopaSvg extends StatelessWidget {
  const _CopaSvg({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.iconCopa,
      width: size,
      height: size,
    );
  }
}

// ── Constante compartida buscador + filtros (desktop) ────────────────────────
const double _kSearchMaxWidth = 480;

// ── Buscador ──────────────────────────────────────────────────────────────────
// Desktop: h=56, maxWidth=480, icon=22
// Mobile:  h=36, full width, pl=25 pr=16, icon=15 (Figma 1386:36965)

class _Buscador extends StatelessWidget {
  const _Buscador({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < _kMobileBreak;

    final double h        = isMobile ? 36 : 56;
    final double iconSize = isMobile ? 15 : 22;
    final double textSize = 16;

    Widget field = Container(
      height: h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 80 : 28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left:  isMobile ? 14 : 16,
        right: isMobile ? 14 : 16,
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: AppColors.neutral5,
            size: iconSize,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Buscar número o lotería...',
                hintStyle: GoogleFonts.inter(
                  fontSize: textSize,
                  color: AppColors.neutral5,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                fontSize: textSize,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) return field;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSearchMaxWidth),
        child: field,
      ),
    );
  }
}

// ── Filtro Hoy / Ayer / Fecha ─────────────────────────────────────────────────
// Desktop: h=62, maxWidth=480
// Mobile: Figma 1386:36967 — h=44, full width, rounded=40
//   Hoy: 75×33 bg#064679 rounded30  |  Ayer: 75×33 bg#f0f0f0 rounded30
//   separator | fecha: cal icon 23px + text Poppins SemiBold 14px #071647

class _FiltroFecha extends StatelessWidget {
  const _FiltroFecha({
    required this.selected,
    required this.onChanged,
    required this.dateLabel,
    required this.onDateTap,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final String dateLabel;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < _kMobileBreak;

    Widget content = Container(
      height: isMobile ? 44 : 62,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 40 : 99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 5 : 4),
      child: Row(
        children: [
          // ── Tab Hoy ─────────────────────────────────────────────────────
          if (isMobile)
            _DayTab(
              label: 'Hoy',
              isActive: selected == 0,
              onTap: () => onChanged(0),
              isMobile: true,
            )
          else
            Expanded(
              child: _DayTab(
                label: 'Hoy',
                isActive: selected == 0,
                onTap: () => onChanged(0),
                isMobile: false,
              ),
            ),
          const SizedBox(width: 4),
          // ── Tab Ayer ────────────────────────────────────────────────────
          if (isMobile)
            _DayTab(
              label: 'Ayer',
              isActive: selected == 1,
              onTap: () => onChanged(1),
              isMobile: true,
            )
          else
            Expanded(
              child: _DayTab(
                label: 'Ayer',
                isActive: selected == 1,
                onTap: () => onChanged(1),
                isMobile: false,
              ),
            ),
          // ── Separador vertical ──────────────────────────────────────────
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(vertical: 4),
            color: const Color(0xFFD1D5DB),
          ),
          // ── Fecha con ícono ─────────────────────────────────────────────
          Expanded(
            child: GestureDetector(
              onTap: onDateTap,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      AppAssets.iconCalendario,
                      width:  isMobile ? 18 : 18,
                      height: isMobile ? 18 : 18,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF071647),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        dateLabel,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF071647),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isMobile) return content;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kSearchMaxWidth),
        child: content,
      ),
    );
  }
}

class _DayTab extends StatelessWidget {
  const _DayTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isMobile = false,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    // Mobile: fixed 75×33px  |  Desktop: Expanded fill
    final Widget inner = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width:  isMobile ? 75 : double.infinity,
      height: isMobile ? 33 : double.infinity,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF064679)
            : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(isMobile ? 30 : 99),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: isMobile ? 12 : 15,
          fontWeight: FontWeight.w700,
          color: isActive ? Colors.white : const Color(0xFF071647),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: inner,
    );
  }
}

// ── Grid de Juegos Destacados ─────────────────────────────────────────────────
// Desktop: 3 cards con ancho dinámico, gap 42px
// Mobile: Figma 1386:36975 — cards 125×70px, gap 4px, scroll horizontal

class _JuegosDestacadosGrid extends StatelessWidget {
  const _JuegosDestacadosGrid({required this.isMobile});
  final bool isMobile;

  static double _ballSize(double cardWidth, int count) {
    const hPad = 7.0 * 2;
    const minGap = 3.0;
    final available = cardWidth - hPad - minGap * (count - 1);
    return isMobileBalls(cardWidth)
        ? 16.0
        : (available / count).clamp(44.0, 68.0);
  }

  static bool isMobileBalls(double cardWidth) => cardWidth <= 130;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile) {
          // Mobile: cards 125×70px, gap 4px, scroll horizontal
          const double cardW   = 125.0;
          const double mGap    = 4.0;
          const double ballSz  = 16.0;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < _kJuegosDestacados.length; i++) ...[
                  SizedBox(
                    width: cardW,
                    child: _JuegoDestacadoCard(
                      data: _kJuegosDestacados[i],
                      ballSize: ballSz,
                      cardWidth: cardW,
                      isMobile: true,
                    ),
                  ),
                  if (i < _kJuegosDestacados.length - 1)
                    const SizedBox(width: mGap),
                ],
              ],
            ),
          );
        }

        // Desktop: 3 columnas, gap 42px
        const double gap = 42.0;
        final cardW = (constraints.maxWidth - gap * 2) / 3;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _kJuegosDestacados.length; i++) ...[
              SizedBox(
                width: cardW,
                child: _JuegoDestacadoCard(
                  data: _kJuegosDestacados[i],
                  ballSize: _ballSize(cardW, _kJuegosDestacados[i].balls.length),
                  cardWidth: cardW,
                  isMobile: false,
                ),
              ),
              if (i < _kJuegosDestacados.length - 1)
                const SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

// ── Tarjeta de Juego Destacado ────────────────────────────────────────────────
// Desktop: padding v:16 h:16, logo h:52, balls ~44-68px, date 14px
// Mobile:  Figma 1386:36975 — 125×70px, padding v:4 h:7, logo h:23, balls 16px, date 10px

class _JuegoDestacadoCard extends StatelessWidget {
  const _JuegoDestacadoCard({
    required this.data,
    required this.ballSize,
    required this.cardWidth,
    required this.isMobile,
  });
  final _JuegoDestacado data;
  final double ballSize;
  final double cardWidth;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final n = data.balls.length;
    final hPad = isMobile ? 7.0 * 2 : 16.0 * 2;
    final rowW = cardWidth - hPad;
    final ballGap = n > 1
        ? ((rowW - ballSize * n) / (n - 1)).clamp(2.0, isMobile ? 3.0 : 10.0)
        : 0.0;

    return Container(
      height: isMobile ? 70 : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        boxShadow: AppColors.sombra200,
      ),
      padding: EdgeInsets.symmetric(
        vertical:   isMobile ? 4 : 16,
        horizontal: isMobile ? 7 : 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: isMobile
            ? MainAxisAlignment.spaceEvenly
            : MainAxisAlignment.start,
        children: [
          // ── Logo ──────────────────────────────────────────────────────────
          SizedBox(
            height: isMobile ? 22 : 52,
            child: Image.asset(
              data.logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.casino,
                color: AppColors.neutral5,
                size: isMobile ? 20 : 40,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 4 : 12),

          // ── Bolas en una sola fila ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < data.balls.length; i++) ...[
                _LotteryBall(ball: data.balls[i], size: ballSize),
                if (i < data.balls.length - 1)
                  SizedBox(width: ballGap),
              ],
            ],
          ),

          if (!isMobile) ...[
            const SizedBox(height: 10),
            // ── Fecha (solo desktop — no cabe en 70px mobile) ──────────────
            Text(
              data.fecha,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.neutral3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _LotteryBall extends StatelessWidget {
  const _LotteryBall({required this.ball, this.size = 40});
  final _BallData ball;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = size >= 56
        ? (ball.number >= 10 ? 26.0 : 32.0)
        : size >= 44
            ? (ball.number >= 10 ? 20.0 : 26.0)
            : size >= 20
                ? (ball.number >= 10 ? 11.0 : 13.0)
                : (ball.number >= 10 ? 9.0 : 11.0);
    return Container(
      width: size,
      height: size,
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
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: ball.textColor,
        ),
      ),
    );
  }
}

// ── Grid de Resultados ────────────────────────────────────────────────────────
// Desktop: 4 → 3 → 2 columnas
// Mobile: Figma 1386:36982 — siempre 2 columnas, gap 12px

class _ResultadosGrid extends StatelessWidget {
  const _ResultadosGrid({required this.resultados, required this.isMobile});
  final List<ResultadoData> resultados;
  final bool isMobile;

  static int _columns(double width) {
    if (width >= 1200) return 4;
    if (width >= 860) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap  = isMobile ? 10.0 : 16.0;
        final cols = isMobile ? 2 : _columns(constraints.maxWidth);
        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final r in resultados)
              SizedBox(
                width: cardW,
                child: isMobile
                    ? _ResultadoGridCardMobile(data: r)
                    : _ResultadoGridCard(data: r),
              ),
          ],
        );
      },
    );
  }
}

// ── Card Resultados DESKTOP ───────────────────────────────────────────────────

class _ResultadoGridCard extends StatelessWidget {
  const _ResultadoGridCard({required this.data});
  final ResultadoData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C3E8C), Color(0xFF3D55C5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: data.logoUrl != null
                    ? Image.asset(data.logoUrl!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.casino, color: Colors.grey))
                    : const Icon(Icons.casino, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.nombre,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (data.subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        data.subtitulo!,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF9099E0).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final n in data.numeros)
                      _GridNumeroChip(numero: n),
                  ],
                ),
              ),
              if (data.serie != null)
                Positioned(
                  bottom: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D2D8C),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      data.serie!,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.push(
              AppRoutes.historialResultados,
              extra: data,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 4),
                Text(
                  'Historial',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridNumeroChip extends StatelessWidget {
  const _GridNumeroChip({required this.numero});
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C2E6F),
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Card Resultados MOBILE ────────────────────────────────────────────────────
// Figma 1386:36982 / Resultadosss "MOvil 2" — 144×110px
// Logo: 38×38 rounded-8, título 8px SemiBold, subtitle 8px
// Balotas: h-29 bg #7d7ec9 rounded-8, balls 20×20 white text-12 #2c2e6f
// Serie: 39×11 bg #3e4095 rounded-16 text-6
// Historial: icon 8px + text 7px #bfc0c3

class _ResultadoGridCardMobile extends StatelessWidget {
  const _ResultadoGridCardMobile({required this.data});
  final ResultadoData data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x805458D5), // rgba(84,88,213,0.5)
              Color(0x803E4095), // rgba(62,64,149,0.5)
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ── Logo ────────────────────────────────────────────────────────
            Positioned(
              left: 9,
              top: 7,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 4,
                      offset: Offset(2, 1),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: data.logoUrl != null
                    ? Image.asset(data.logoUrl!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.casino,
                                color: Colors.grey, size: 20))
                    : const Icon(Icons.casino, color: Colors.grey, size: 20),
              ),
            ),

            // ── Título + Subtítulo ──────────────────────────────────────────
            Positioned(
              left: 56,
              top: 14,
              right: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.nombre,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data.subtitulo != null)
                    Text(
                      data.subtitulo!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.80),
                        height: 1.3,
                      ),
                    ),
                ],
              ),
            ),

            // ── Pill de balotas ─────────────────────────────────────────────
            Positioned(
              left: 9,
              top: 54,
              right: 9,
              height: 29,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF7D7EC9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final n in data.numeros)
                      _MobileBall(numero: n),
                  ],
                ),
              ),
            ),

            // ── Badge "Serie 1" ─────────────────────────────────────────────
            if (data.serie != null)
              Positioned(
                left: 56,
                top: 82,
                child: Container(
                  height: 11,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E4095),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    data.serie!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 6,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // ── Historial ───────────────────────────────────────────────────
            Positioned(
              left: 7,
              top: 96,
              child: GestureDetector(
                onTap: () => context.push(
                  AppRoutes.historialResultados,
                  extra: data,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 8,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Historial',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileBall extends StatelessWidget {
  const _MobileBall({required this.numero});
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C2E6F),
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Calendario (Figma node 1317:4515) ─────────────────────────────────────────

class _CalendarioWidget extends StatefulWidget {
  const _CalendarioWidget({
    required this.selectedDate,
    required this.onDateSelected,
  });
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_CalendarioWidget> createState() => _CalendarioWidgetState();
}

class _CalendarioWidgetState extends State<_CalendarioWidget> {
  late int _viewMonth;
  late int _viewYear;

  static const _diasSemana = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _viewMonth = widget.selectedDate.month;
    _viewYear  = widget.selectedDate.year;
  }

  void _prevMonth() => setState(() {
    if (_viewMonth == 1) { _viewMonth = 12; _viewYear--; }
    else { _viewMonth--; }
  });

  void _nextMonth() => setState(() {
    if (_viewMonth == 12) { _viewMonth = 1; _viewYear++; }
    else { _viewMonth++; }
  });

  List<_DiaCell> _buildCells() {
    final firstDay = DateTime(_viewYear, _viewMonth, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final daysInPrevMonth = DateTime(_viewYear, _viewMonth, 0).day;

    final cells = <_DiaCell>[];

    for (int i = startOffset - 1; i >= 0; i--) {
      cells.add(_DiaCell(
        day: daysInPrevMonth - i,
        month: _viewMonth - 1 == 0 ? 12 : _viewMonth - 1,
        year: _viewMonth - 1 == 0 ? _viewYear - 1 : _viewYear,
        otherMonth: true,
      ));
    }

    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(_DiaCell(day: d, month: _viewMonth, year: _viewYear));
    }

    final remaining = (7 - cells.length % 7) % 7;
    for (int d = 1; d <= remaining; d++) {
      cells.add(_DiaCell(
        day: d,
        month: _viewMonth + 1 == 13 ? 1 : _viewMonth + 1,
        year: _viewMonth + 1 == 13 ? _viewYear + 1 : _viewYear,
        otherMonth: true,
      ));
    }

    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildCells();
    final rows = <List<_DiaCell>>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(cells.sublist(i, i + 7));
    }

    return Container(
      width: 318,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _NavBtn(icon: Icons.chevron_left, onTap: _prevMonth),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD9D9D9)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _meses[_viewMonth - 1],
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Color(0xFF1E1E1E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFD9D9D9)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$_viewYear',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF1E1E1E),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: Color(0xFF1E1E1E),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NavBtn(icon: Icons.chevron_right, onTap: _nextMonth),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in _diasSemana)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (final row in rows)
            Row(
              children: [
                for (final cell in row)
                  Expanded(
                    child: _DayCellWidget(
                      cell: cell,
                      isSelected: cell.day == widget.selectedDate.day &&
                          cell.month == widget.selectedDate.month &&
                          cell.year == widget.selectedDate.year,
                      onTap: cell.otherMonth
                          ? null
                          : () => widget.onDateSelected(
                              DateTime(cell.year, cell.month, cell.day)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DiaCell {
  const _DiaCell({
    required this.day,
    required this.month,
    required this.year,
    this.otherMonth = false,
  });
  final int day, month, year;
  final bool otherMonth;
}

class _DayCellWidget extends StatelessWidget {
  const _DayCellWidget({
    required this.cell,
    required this.isSelected,
    this.onTap,
  });
  final _DiaCell cell;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3C9BD6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          '${cell.day}',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isSelected
                ? Colors.white
                : cell.otherMonth
                    ? const Color(0xFFB3B3B3)
                    : const Color(0xFF1E1E1E),
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: const Color(0xFF1E1E1E)),
      ),
    );
  }
}

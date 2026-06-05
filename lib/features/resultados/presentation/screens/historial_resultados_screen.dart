import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';
import '../../../home/presentation/widgets/resultado_card_widget.dart';

// ── Modelos mock de historial ─────────────────────────────────────────────────

class HistorialItem {
  const HistorialItem({
    required this.dia,
    required this.mes,
    required this.diaSemana,
    required this.serie,
    required this.numeros,
  });
  final int dia;
  final String mes;
  final String diaSemana;
  final String serie;
  final List<int> numeros;
}

// ── Pantalla ──────────────────────────────────────────────────────────────────

class HistorialResultadosScreen extends StatefulWidget {
  const HistorialResultadosScreen({super.key, required this.loteria});
  final ResultadoData loteria;

  @override
  State<HistorialResultadosScreen> createState() =>
      _HistorialResultadosScreenState();
}

class _HistorialResultadosScreenState
    extends State<HistorialResultadosScreen> {
  final _numCtrl = TextEditingController();
  DateTime _desde = DateTime(2026, 4, 6);
  DateTime _hasta = DateTime(2026, 5, 11);

  final _items = List.generate(
    10,
    (_) => const HistorialItem(
      dia: 14,
      mes: 'ABR',
      diaSemana: 'MARTES',
      serie: 'SERIE: 000',
      numeros: [6, 9, 9, 2],
    ),
  );

  late List<HistorialItem> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(_items);
  }

  void _applyFilters() {
    final query = _numCtrl.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_items);
      } else {
        _filteredItems = _items
            .where((item) => item.numeros.join('').contains(query))
            .toList();
      }
    });
  }

  static double _navbarHeight(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtFull(DateTime d) {
    const meses = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return '${d.day} De ${meses[d.month]} De ${d.year}';
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) =>
          (p.user == null) != (c.user == null) || p.status != c.status,
      builder: (context, authState) {
        final bool isLoggedIn = authState.user != null ||
            authState.status == AuthStatus.success ||
            authState.status == AuthStatus.registrationSuccess;

        final double screenW = MediaQuery.of(context).size.width;
        final bool isMobile  = screenW < 720;
        final double navH    = _navbarHeight(screenW, isLoggedIn);

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              // ── Degradado inferior (solo mobile) ──────────────────────
              if (isMobile)
                Positioned(
                  bottom: 0, left: 0, right: 0, height: 300,
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

              // ── Contenido scrollable ───────────────────────────────────
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: navH),

                    // ── Banner amarillo ────────────────────────────────
                    const _HistorialBanner(),

                    if (isMobile) ...[
                      // ════════════ LAYOUT MOBILE ════════════
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),

                            // ── Título ───────────────────────────────
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.menu_book_outlined,
                                    size: 18,
                                    color: AppColors.neutralWhite),
                                const SizedBox(width: 6),
                                Text(
                                  'Historial de resultados',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.neutralWhite,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),

                            // ── Subtítulo ────────────────────────────
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                'Consulta sorteos anteriores y filtra por fechas',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.neutralWhite,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ── Filtros mobile (3 filas apiladas) ────
                            _FiltrosBarMobile(
                              desde: _fmtFull(_desde),
                              hasta: _fmtFull(_hasta),
                              desdeDate: _desde,
                              hastaDate: _hasta,
                              numCtrl: _numCtrl,
                              onFiltrar: _applyFilters,
                              onDesdeSelected: (d) =>
                                  setState(() => _desde = d),
                              onHastaSelected: (d) =>
                                  setState(() => _hasta = d),
                            ),
                            const SizedBox(height: 10),

                            // ── Card resumen lotería ─────────────────
                            _LotteriaInfoCardMobile(
                              loteria: widget.loteria,
                              desde: _fmt(_desde),
                              hasta: _fmt(_hasta),
                            ),
                            const SizedBox(height: 10),

                            // ── Lista de resultados ──────────────────
                            if (_filteredItems.isEmpty)
                              const _EmptyHistoryState()
                            else
                              for (final item in _filteredItems) ...[
                                _HistorialRowMobile(item: item),
                                const SizedBox(height: 6),
                              ],

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ] else ...[
                      // ════════════ LAYOUT DESKTOP ════════════
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1728),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 50, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FiltrosBar(
                                  desde: _fmtFull(_desde),
                                  hasta: _fmtFull(_hasta),
                                  desdeDate: _desde,
                                  hastaDate: _hasta,
                                  numCtrl: _numCtrl,
                                  onFiltrar: _applyFilters,
                                  onDesdeSelected: (d) =>
                                      setState(() => _desde = d),
                                  onHastaSelected: (d) =>
                                      setState(() => _hasta = d),
                                ),
                                const SizedBox(height: 28),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.menu_book_rounded,
                                        size: 44,
                                        color: AppColors.neutralWhite),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Historial de resultados',
                                      style: GoogleFonts.inter(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.neutralWhite,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Consulta sorteos anteriores y filtra por fechas',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.neutralWhite
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _LotteriaInfoCard(
                                  loteria: widget.loteria,
                                  desde: _fmt(_desde),
                                  hasta: _fmt(_hasta),
                                ),
                                const SizedBox(height: 16),
                                if (_filteredItems.isEmpty)
                                  const _EmptyHistoryState()
                                else
                                  for (final item in _filteredItems) ...[
                                    _HistorialRow(item: item),
                                    const SizedBox(height: 12),
                                  ],
                                const SizedBox(height: 48),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Navbar fija ────────────────────────────────────────────
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

// ── Banner amarillo — idéntico al de Resultados ───────────────────────────────

class _HistorialBanner extends StatelessWidget {
  const _HistorialBanner();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW < 720;
    final copaSize = isMobile ? 25.0 : 96.0;
    final gap = isMobile ? 10.0 : 32.0;

    return Container(
      width: double.infinity,
      color: const Color(0xFFFFE100),
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
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 48,
              vertical: isMobile ? 20 : 40,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppAssets.iconCopa,
                  width: copaSize,
                  height: copaSize,
                ),
                SizedBox(width: gap),
                Flexible(
                  child: Text(
                    'Descubre si tu apuesta fue la ganadora',
                    style: GoogleFonts.inter(
                      fontSize: isMobile ? 16 : 36,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1372AE),
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: gap),
                SvgPicture.asset(
                  AppAssets.iconCopa,
                  width: copaSize,
                  height: copaSize,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de loterías disponibles ─────────────────────────────────────────────
const _kLoterias = [
  'Lotería del Quindio',
  'Lotería del Risaralda',
  'Lotería de Santander',
  'Lotería de Medellín',
  'Lotería del Huila',
  'Lotería del Valle',
  'Lotería del Tolima',
];

// ── Barra de filtros ──────────────────────────────────────────────────────────
// Desktop: fila única · Lotería flexible · Desde · Hasta · Número · Filtrar
// Mobile: columna apilada

class _FiltrosBar extends StatefulWidget {
  const _FiltrosBar({
    required this.desde,
    required this.hasta,
    required this.desdeDate,
    required this.hastaDate,
    required this.numCtrl,
    required this.onFiltrar,
    required this.onDesdeSelected,
    required this.onHastaSelected,
  });

  final String desde;
  final String hasta;
  final DateTime desdeDate;
  final DateTime hastaDate;
  final TextEditingController numCtrl;
  final VoidCallback onFiltrar;
  final ValueChanged<DateTime> onDesdeSelected;
  final ValueChanged<DateTime> onHastaSelected;

  @override
  State<_FiltrosBar> createState() => _FiltrosBarState();
}

class _FiltrosBarState extends State<_FiltrosBar> {
  final _loteriaLink = LayerLink();
  final _desdeLink    = LayerLink();
  final _hastaLink    = LayerLink();

  OverlayEntry? _loteriaOverlay;
  OverlayEntry? _desdeOverlay;
  OverlayEntry? _hastaOverlay;

  String? _loteriaSelected;

  @override
  void dispose() {
    _loteriaOverlay?.remove();
    _desdeOverlay?.remove();
    _hastaOverlay?.remove();
    super.dispose();
  }

  void _removeOverlay() {
    _loteriaOverlay?.remove();
    _loteriaOverlay = null;
  }

  void _removeDesde() {
    _desdeOverlay?.remove();
    _desdeOverlay = null;
  }

  void _removeHasta() {
    _hastaOverlay?.remove();
    _hastaOverlay = null;
  }

  void _toggleDesde() {
    if (_desdeOverlay != null) { _removeDesde(); return; }
    _removeHasta(); // cierra Hasta si está abierto

    _desdeOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeDesde,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _desdeLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: _HistorialCalendario(
                selectedDate: widget.desdeDate,
                onDateSelected: (d) {
                  widget.onDesdeSelected(d);
                  _removeDesde();
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_desdeOverlay!);
  }

  void _toggleHasta() {
    if (_hastaOverlay != null) { _removeHasta(); return; }
    _removeDesde(); // cierra Desde si está abierto

    _hastaOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeHasta,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          CompositedTransformFollower(
            link: _hastaLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            offset: const Offset(0, 8),
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: _HistorialCalendario(
                selectedDate: widget.hastaDate,
                onDateSelected: (d) {
                  widget.onHastaSelected(d);
                  _removeHasta();
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_hastaOverlay!);
  }

  void _toggleLoteria() {
    if (_loteriaOverlay != null) {
      _removeOverlay();
      return;
    }

    _loteriaOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Barrier para cerrar al tocar fuera
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          // Dropdown flotante anclado al campo Lotería
          CompositedTransformFollower(
            link: _loteriaLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              child: _LoteriasDropdown(
                selected: _loteriaSelected,
                onSelected: (v) {
                  setState(() => _loteriaSelected = v);
                  _removeOverlay();
                },
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_loteriaOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 860;

    // Campo Lotería con CompositedTransformTarget (compartido mobile/desktop)
    final loteriaField = CompositedTransformTarget(
      link: _loteriaLink,
      child: GestureDetector(
        onTap: _toggleLoteria,
        child: _buildFiltroField(
          label: 'Lotería',
          child: _loteriaContent(),
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          loteriaField,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFiltroField(
                  label: 'Desde',
                  child: _fechaContent(widget.desde),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFiltroField(
                  label: 'Hasta',
                  child: _fechaContent(widget.hasta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFiltroField(
            label: 'Número ganador',
            child: _numeroContent(),
          ),
          const SizedBox(height: 16),
          _buildFiltrarBtn(),
        ],
      );
    }

    // Desktop: una sola fila horizontal full-width
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Lotería — mucho más ancho (flex 5 ≈ 45%)
        Expanded(flex: 5, child: loteriaField),
        const SizedBox(width: 16),
        // Desde (flex 3)
        Expanded(
          flex: 3,
          child: CompositedTransformTarget(
            link: _desdeLink,
            child: GestureDetector(
              onTap: _toggleDesde,
              child: _buildFiltroField(
                label: 'Desde',
                child: _fechaContent(widget.desde),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Hasta (flex 3)
        Expanded(
          flex: 3,
          child: CompositedTransformTarget(
            link: _hastaLink,
            child: GestureDetector(
              onTap: _toggleHasta,
              child: _buildFiltroField(
                label: 'Hasta',
                child: _fechaContent(widget.hasta),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Número ganador (flex 3)
        Expanded(
          flex: 3,
          child: _buildFiltroField(
            label: 'Número ganador',
            child: _numeroContent(),
          ),
        ),
        const SizedBox(width: 16),
        // Filtrar — compacto alineado al fondo
        _buildFiltrarBtn(),
      ],
    );
  }

  Widget _loteriaContent() => Row(
        children: [
          Expanded(
            child: Text(
              _loteriaSelected ?? 'Lotería',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF071647),
              ),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF071647)),
        ],
      );

  Widget _fechaContent(String label) => Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: Color(0xFF071647)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF071647),
              ),
            ),
          ),
        ],
      );

  Widget _numeroContent() => Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.numCtrl,
              decoration: InputDecoration(
                hintText: '# Ej: 123 o 14',
                hintStyle: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF9CA3AF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF1E1E1E)),
            ),
          ),
          GestureDetector(
            onTap: () => widget.numCtrl.clear(),
            child: const Icon(Icons.close_rounded,
                size: 16, color: Color(0xFF9CA3AF)),
          ),
        ],
      );

  Widget _buildFiltroField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralWhite,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(40),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }

  Widget _buildFiltrarBtn() {
    return GestureDetector(
      onTap: widget.onFiltrar,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2D5E),
          borderRadius: BorderRadius.circular(40),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Filtrar',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltroField extends StatelessWidget {
  const _FiltroField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.neutralWhite,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(40),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }
}

// ── Card banner de la lotería ─────────────────────────────────────────────────
// Figma: w=990 · h=140 · rounded-80 · bg-white · logo izq · texto der

class _LotteriaInfoCard extends StatelessWidget {
  const _LotteriaInfoCard({
    required this.loteria,
    required this.desde,
    required this.hasta,
  });

  final ResultadoData loteria;
  final String desde;
  final String hasta;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 990),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 24 : 80),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 32,
            vertical: isMobile ? 20 : 16,
          ),
          child: Row(
            children: [
              // ── Logo limpio sin recuadro gris ──────────────────────────
              SizedBox(
                width: isMobile ? 72 : 104,
                height: isMobile ? 72 : 114,
                child: loteria.logoUrl != null
                    ? Image.asset(
                        loteria.logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.casino, color: Colors.grey),
                      )
                    : const Icon(Icons.casino, color: Colors.grey),
              ),
              SizedBox(width: isMobile ? 16 : 32),
              // ── Info ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loteria.nombre,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF064679),
                        height: 1.3,
                      ),
                    ),
                    Text(
                      loteria.subtitulo ?? 'Resultado Oficial',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 14 : 16,
                        color: const Color(0xFF064679),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Resultados del $desde al $hasta',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF064679),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fila de resultado histórico ───────────────────────────────────────────────
// Figma: w=852 · h=84 · rounded-30 · px-34 · gap-41 · balls gap-27

class _HistorialRow extends StatelessWidget {
  const _HistorialRow({required this.item});
  final HistorialItem item;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    final ballSize = isMobile ? 36.0 : 40.0;
    final ballFontSize = isMobile ? 18.0 : 24.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 852),
        child: Container(
          height: isMobile ? null : 84,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 34,
            vertical: isMobile ? 14 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Día + mes ─────────────────────────────────────────────
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.dia}',
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 28 : 40,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF064679),
                        height: 1.0,
                      ),
                    ),
                    Text(
                      item.mes,
                      style: GoogleFonts.inter(
                        fontSize: isMobile ? 13 : 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF064679),
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // ── Separador ─────────────────────────────────────────────
              Container(width: 1, height: 44, color: const Color(0xFFE5E7EB)),
              const SizedBox(width: 16),

              // ── Día semana + serie ────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.diaSemana,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF064679),
                      ),
                    ),
                    Text(
                      item.serie,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF064679),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bolas ─────────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < item.numeros.length; i++) ...[
                    _HistorialBall(
                      numero: item.numeros[i],
                      size: ballSize,
                      fontSize: ballFontSize,
                    ),
                    if (i < item.numeros.length - 1)
                      SizedBox(width: isMobile ? 6 : 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorialBall extends StatelessWidget {
  const _HistorialBall({
    required this.numero,
    this.size = 40,
    this.fontSize = 24,
  });
  final int numero;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF064679),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$numero',
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Dropdown de loterías (overlay flotante) ───────────────────────────────────

class _LoteriasDropdown extends StatefulWidget {
  const _LoteriasDropdown({
    required this.selected,
    required this.onSelected,
  });
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_LoteriasDropdown> createState() => _LoteriasDropdownState();
}

class _LoteriasDropdownState extends State<_LoteriasDropdown> {
  final _searchCtrl = TextEditingController();
  List<String> _filtradas = _kLoterias;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      _filtradas = q.isEmpty
          ? _kLoterias
          : _kLoterias
              .where((l) => l.toLowerCase().contains(q.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Buscador ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 16, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'Buscar Lotería...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 13, color: const Color(0xFF9CA3AF)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFF1E1E1E)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Separador ─────────────────────────────────────────────────
          Container(height: 1, color: const Color(0xFFE5E7EB)),

          // ── Lista ─────────────────────────────────────────────────────
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _filtradas.length,
              separatorBuilder: (_, __) =>
                  Container(height: 1, color: const Color(0xFFF3F4F6)),
              itemBuilder: (_, i) {
                final item = _filtradas[i];
                final isSelected = item == widget.selected;
                return GestureDetector(
                  onTap: () => widget.onSelected(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFE8F4FD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? const Color(0xFF1372AE)
                            : const Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Calendario flotante para Historial ────────────────────────────────────────

class _HistorialCalendario extends StatefulWidget {
  const _HistorialCalendario({
    required this.selectedDate,
    required this.onDateSelected,
  });
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_HistorialCalendario> createState() => _HistorialCalendarioState();
}

class _HistorialCalendarioState extends State<_HistorialCalendario> {
  late int _viewMonth;
  late int _viewYear;

  static const _dias = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
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

  void _prev() => setState(() {
    if (_viewMonth == 1) { _viewMonth = 12; _viewYear--; }
    else { _viewMonth--; }
  });

  void _next() => setState(() {
    if (_viewMonth == 12) { _viewMonth = 1; _viewYear++; }
    else { _viewMonth++; }
  });

  List<_HCalCell> _cells() {
    final first     = DateTime(_viewYear, _viewMonth, 1);
    final offset    = first.weekday % 7;
    final daysMonth = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final daysPrev  = DateTime(_viewYear, _viewMonth, 0).day;
    final cells     = <_HCalCell>[];

    for (int i = offset - 1; i >= 0; i--) {
      cells.add(_HCalCell(
        day: daysPrev - i,
        month: _viewMonth == 1 ? 12 : _viewMonth - 1,
        year:  _viewMonth == 1 ? _viewYear - 1 : _viewYear,
        other: true,
      ));
    }
    for (int d = 1; d <= daysMonth; d++) {
      cells.add(_HCalCell(day: d, month: _viewMonth, year: _viewYear));
    }
    final rem = (7 - cells.length % 7) % 7;
    for (int d = 1; d <= rem; d++) {
      cells.add(_HCalCell(
        day: d,
        month: _viewMonth == 12 ? 1 : _viewMonth + 1,
        year:  _viewMonth == 12 ? _viewYear + 1 : _viewYear,
        other: true,
      ));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _cells();
    final rows  = <List<_HCalCell>>[];
    for (int i = 0; i < cells.length; i += 7) rows.add(cells.sublist(i, i + 7));

    return Container(
      width: 318,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD9D9D9)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _prev,
                child: const Icon(Icons.chevron_left, size: 20, color: Color(0xFF1E1E1E)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD9D9D9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_meses[_viewMonth - 1],
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1E1E1E))),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E1E1E)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFD9D9D9)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('$_viewYear',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF1E1E1E))),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF1E1E1E)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _next,
                child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF1E1E1E)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final d in _dias)
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF757575))),
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
                    child: GestureDetector(
                      onTap: cell.other
                          ? null
                          : () => widget.onDateSelected(
                              DateTime(cell.year, cell.month, cell.day)),
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: (!cell.other &&
                                  cell.day   == widget.selectedDate.day &&
                                  cell.month == widget.selectedDate.month &&
                                  cell.year  == widget.selectedDate.year)
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
                            color: (!cell.other &&
                                    cell.day   == widget.selectedDate.day &&
                                    cell.month == widget.selectedDate.month &&
                                    cell.year  == widget.selectedDate.year)
                                ? Colors.white
                                : cell.other
                                    ? const Color(0xFFB3B3B3)
                                    : const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HCalCell {
  const _HCalCell({required this.day, required this.month, required this.year, this.other = false});
  final int day, month, year;
  final bool other;
}

// ── Filtros Mobile (node 1387:39157-39165) ───────────────────────────────────
// Fila 1: Lotería (full width, h=36, rounded=30)
// Fila 2: Desde | Hasta (cada uno 183px, h=36, rounded=40)
// Fila 3: Número ganador | Filtrar (cada uno ~181px, h=36)

class _FiltrosBarMobile extends StatefulWidget {
  const _FiltrosBarMobile({
    required this.desde,
    required this.hasta,
    required this.desdeDate,
    required this.hastaDate,
    required this.numCtrl,
    required this.onFiltrar,
    required this.onDesdeSelected,
    required this.onHastaSelected,
  });
  final String desde;
  final String hasta;
  final DateTime desdeDate;
  final DateTime hastaDate;
  final TextEditingController numCtrl;
  final VoidCallback onFiltrar;
  final ValueChanged<DateTime> onDesdeSelected;
  final ValueChanged<DateTime> onHastaSelected;

  @override
  State<_FiltrosBarMobile> createState() => _FiltrosBarMobileState();
}

class _FiltrosBarMobileState extends State<_FiltrosBarMobile> {
  final _loteriaLink = LayerLink();
  final _desdeLink   = LayerLink();
  final _hastaLink   = LayerLink();

  OverlayEntry? _loteriaOverlay;
  OverlayEntry? _desdeOverlay;
  OverlayEntry? _hastaOverlay;

  String? _loteriaSelected;

  @override
  void dispose() {
    _loteriaOverlay?.remove();
    _desdeOverlay?.remove();
    _hastaOverlay?.remove();
    super.dispose();
  }

  void _closeAll() {
    _loteriaOverlay?.remove(); _loteriaOverlay = null;
    _desdeOverlay?.remove();   _desdeOverlay = null;
    _hastaOverlay?.remove();   _hastaOverlay = null;
  }

  void _toggleLoteria() {
    if (_loteriaOverlay != null) { _closeAll(); return; }
    _closeAll();
    _loteriaOverlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeAll,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _loteriaLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            child: _LoteriasDropdown(
              selected: _loteriaSelected,
              onSelected: (v) {
                setState(() => _loteriaSelected = v);
                _closeAll();
              },
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_loteriaOverlay!);
  }

  void _toggleDesde() {
    if (_desdeOverlay != null) { _closeAll(); return; }
    _closeAll();
    _desdeOverlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeAll,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _desdeLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            child: _HistorialCalendario(
              selectedDate: widget.desdeDate,
              onDateSelected: (d) {
                widget.onDesdeSelected(d);
                _closeAll();
              },
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_desdeOverlay!);
  }

  void _toggleHasta() {
    if (_hastaOverlay != null) { _closeAll(); return; }
    _closeAll();
    _hastaOverlay = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeAll,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _hastaLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            child: _HistorialCalendario(
              selectedDate: widget.hastaDate,
              onDateSelected: (d) {
                widget.onHastaSelected(d);
                _closeAll();
              },
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_hastaOverlay!);
  }

  // Campo con label blanco arriba + contenedor blanco abajo
  Widget _campo({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Fila 1: Lotería ───────────────────────────────────────────
        _campo(
          label: 'Lotería',
          child: CompositedTransformTarget(
            link: _loteriaLink,
            child: GestureDetector(
              onTap: _toggleLoteria,
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _loteriaSelected ?? 'Lotería',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C2577),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Color(0xFF0C2577)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Fila 2: Desde | Hasta ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _campo(
                label: 'Desde',
                child: CompositedTransformTarget(
                  link: _desdeLink,
                  child: GestureDetector(
                    onTap: _toggleDesde,
                    child: _fechaBtn(widget.desde),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _campo(
                label: 'Hasta',
                child: CompositedTransformTarget(
                  link: _hastaLink,
                  child: GestureDetector(
                    onTap: _toggleHasta,
                    child: _fechaBtn(widget.hasta),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Fila 3: Número ganador | Filtrar ─────────────────────────
        _campo(
          label: 'Número ganador',
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(80),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.numCtrl,
                          decoration: InputDecoration(
                            hintText: '# Ej: 123 o 14',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFD1D5DB),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF1E1E1E),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.numCtrl.clear(),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
               child: GestureDetector(
                onTap: widget.onFiltrar,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF064679),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'Filtrar',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
               ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fechaBtn(String label) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 16, color: Color(0xFF071647)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF071647),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card resumen lotería Mobile (node 1387:39172) ─────────────────────────────
// h=82, rounded=16, pl=25 pr=20 py=10
// Logo 57×63, título Inter Bold 14px, subtitle Inter Medium 14px,
// fechas Poppins SemiBold 12px, color #064679

class _LotteriaInfoCardMobile extends StatelessWidget {
  const _LotteriaInfoCardMobile({
    required this.loteria,
    required this.desde,
    required this.hasta,
  });
  final ResultadoData loteria;
  final String desde;
  final String hasta;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(15, 10, 20, 10),
      child: Row(
        children: [
          // ── Logo ──────────────────────────────────────────────────────
          SizedBox(
            width: 57,
            height: 63,
            child: loteria.logoUrl != null
                ? Image.asset(
                    loteria.logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.casino, color: Colors.grey, size: 32),
                  )
                : const Icon(Icons.casino, color: Colors.grey, size: 32),
          ),
          const SizedBox(width: 14),
          // ── Textos ────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  loteria.nombre,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF064679),
                    height: 1.4,
                  ),
                ),
                Text(
                  loteria.subtitulo ?? 'Resultado Oficial',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF064679),
                    height: 1.4,
                  ),
                ),
                Text(
                  'Resultados del $desde al $hasta',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF064679),
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fila de resultado Mobile (LineaDeResultados node 1359:5016) ───────────────
// h=31, rounded=60, w=full
// Fecha: día Inter Bold 16px + mes Inter Bold 10px (left:16)
// Día/Serie: Inter SemiBold 12px/9px (left:52)
// Bolas: 16×16px bg #064679 text 11px, gap 6px (right side)

class _HistorialRowMobile extends StatelessWidget {
  const _HistorialRowMobile({required this.item});
  final HistorialItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Día + Mes ────────────────────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${item.dia}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF064679),
                    height: 1.0,
                  ),
                ),
                Text(
                  item.mes,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF064679),
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Día semana + serie ───────────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.diaSemana,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF064679),
                  height: 1.1,
                ),
              ),
              Text(
                item.serie,
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF064679),
                  height: 1.1,
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── Balotas (16×16, gap 6px) ──────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < item.numeros.length; i++) ...[
                _MobileBallSmall(numero: item.numeros[i]),
                if (i < item.numeros.length - 1)
                  const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileBallSmall extends StatelessWidget {
  const _MobileBallSmall({required this.numero});
  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: Color(0xFF064679),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$numero',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Empty state — sin resultados de búsqueda ──────────────────────────────────

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ícono compuesto: lupa + X (zoom-in 170px · cancel centrado 104px)
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/zoom-in.svg',
                    width: 140,
                    height: 140,
                    colorFilter: const ColorFilter.mode(
                      Color(0xBFF0F0F0),
                      BlendMode.srcIn,
                    ),
                  ),
                  Positioned(
                    top: 26,
                    left: 26,
                    child: SvgPicture.asset(
                      'assets/images/cancel.svg',
                      width: 76,
                      height: 76,
                      colorFilter: const ColorFilter.mode(
                        Color(0xBFF0F0F0),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No hay resultados',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ampliar el rango de fechas',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

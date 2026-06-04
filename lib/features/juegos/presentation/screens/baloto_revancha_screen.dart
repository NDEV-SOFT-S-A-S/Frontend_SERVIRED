import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';

// ── Constantes de negocio ─────────────────────────────────────────────────────

const int _kBalotaMax = 43;
const int _kSuperbalotaMax = 16;
const int _kBalotasRequeridas = 5;
const int _kPrecioBaloto = 6000;
const int _kPrecioRevancha = 3000;
const int _kMaxSorteos = 9;

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtCop(int amount) {
  if (amount == 0) return '\$0';
  final s = amount.toString();
  final buf = StringBuffer('\$');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

enum _SelectionMode { manual, automatica }

// ── Plan de premios (referencia ONJ / Coljuegos) ──────────────────────────────

const _kPlanPremios = <({String combo, String descripcion, String valor})>[
  (combo: '5+S', descripcion: '5 balotas + superbalota', valor: 'Acumulado'),
  (combo: '5', descripcion: '5 balotas', valor: '\$3.000.000'),
  (combo: '4+S', descripcion: '4 balotas + superbalota', valor: '\$200.000'),
  (combo: '4', descripcion: '4 balotas', valor: '\$50.000'),
  (combo: '3+S', descripcion: '3 balotas + superbalota', valor: '\$20.000'),
  (combo: '3', descripcion: '3 balotas', valor: '\$4.000'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class BalotoRevanchaScreen extends StatefulWidget {
  const BalotoRevanchaScreen({super.key});

  @override
  State<BalotoRevanchaScreen> createState() => _BalotoRevanchaScreenState();
}

class _BalotoRevanchaScreenState extends State<BalotoRevanchaScreen> {
  _SelectionMode _modo = _SelectionMode.manual;
  final Set<int> _balotas = {};
  int? _superbalota;
  bool _conRevancha = false;
  int _sorteos = 1;

  String? _errorBalotas;
  String? _errorSuperbalota;
  bool _confirmado = false;

  // ── Helpers ─────────────────────────────────────────────────────────────

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  int get _totalPagar =>
      (_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)) * _sorteos;

  bool get _apuestaCompleta =>
      _balotas.length == _kBalotasRequeridas && _superbalota != null;

  void _toggleBalota(int n) {
    setState(() {
      if (_balotas.contains(n)) {
        _balotas.remove(n);
        _errorBalotas = null;
      } else {
        if (_balotas.length >= _kBalotasRequeridas) {
          _errorBalotas =
              'Solo puedes seleccionar $_kBalotasRequeridas balotas';
          return;
        }
        _balotas.add(n);
        _errorBalotas = null;
      }
    });
  }

  void _toggleSuperbalota(int n) {
    setState(() {
      _superbalota = _superbalota == n ? null : n;
      _errorSuperbalota = null;
    });
  }

  void _generarAutomatico() {
    final rng = math.Random();
    final pool = List.generate(_kBalotaMax, (i) => i + 1)..shuffle(rng);
    final superPool = List.generate(_kSuperbalotaMax, (i) => i + 1)
      ..shuffle(rng);
    setState(() {
      _balotas
        ..clear()
        ..addAll(pool.take(_kBalotasRequeridas));
      _superbalota = superPool.first;
      _errorBalotas = null;
      _errorSuperbalota = null;
    });
  }

  void _limpiar() {
    setState(() {
      _balotas.clear();
      _superbalota = null;
      _conRevancha = false;
      _sorteos = 1;
      _errorBalotas = null;
      _errorSuperbalota = null;
      _confirmado = false;
      _modo = _SelectionMode.manual;
    });
  }

  bool _validar() {
    bool ok = true;
    setState(() {
      _errorBalotas = _balotas.length != _kBalotasRequeridas
          ? 'Debes seleccionar exactamente $_kBalotasRequeridas balotas'
          : null;
      _errorSuperbalota =
          _superbalota == null ? 'Debes seleccionar la superbalota' : null;
      ok = _errorBalotas == null && _errorSuperbalota == null;
    });
    return ok;
  }

  void _anadirAlCarrito() {
    if (!_validar()) return;
    setState(() => _confirmado = true);
  }

  // ── Modal de login ───────────────────────────────────────────────────────

  void _showLoginModal(BuildContext ctx) {
    if (MediaQuery.sizeOf(ctx).width < 600) {
      ctx.push(AppRoutes.login);
      return;
    }
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: LoginFormWidget(
            onClose: () => Navigator.pop(dialogContext),
            onLoginSuccess: () => Navigator.pop(dialogContext),
            onRegisterRequested: () => Navigator.pop(dialogContext),
            onRecoveryRequested: (identifier) {
              Navigator.pop(dialogContext);
              dialogContext.push(
                AppRoutes.otpVerification,
                extra: {
                  'destination': identifier,
                  'flow': OtpFlow.passwordRecovery,
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Bottom nav bar móvil ─────────────────────────────────────────────────

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.home_outlined,
            label: 'Inicio',
            onTap: () => context.go(AppRoutes.home),
          ),
          _NavIcon(
            icon: Icons.sports_esports_outlined,
            label: 'Juegos',
            isActive: true,
            onTap: () => context.go(AppRoutes.juegos),
          ),
          _NavIcon(
              icon: Icons.shopping_cart_outlined,
              label: 'Carrito',
              onTap: () {}),
          _NavIcon(icon: Icons.person_outline, label: 'Perfil', onTap: () {}),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) =>
          (p.user == null) != (c.user == null) || p.status != c.status,
      builder: (context, authState) {
        final loggedIn = authState.user != null ||
            authState.status == AuthStatus.success ||
            authState.status == AuthStatus.registrationSuccess;
        final sw = MediaQuery.of(context).size.width;
        final navH = _navH(sw, loggedIn);
        final isMobile = sw < 720;

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          bottomNavigationBar: isMobile ? _buildBottomNav(context) : null,
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: navH),
                    if (!loggedIn)
                      _buildAuthRequired(context)
                    else if (_confirmado)
                      _buildConfirmacion(isMobile)
                    else
                      _buildContent(isMobile),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: NavbarWidget(
                  isLoggedIn: loggedIn,
                  activeNavItem: 'Juegos',
                  onInicioTap: () => context.go(AppRoutes.home),
                  onResultadosTap: () => context.go(AppRoutes.resultados),
                  onWalletTap: loggedIn ? () {} : null,
                  onCartTap: loggedIn ? () {} : null,
                  onAvatarTap: loggedIn ? () {} : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Auth requerido ────────────────────────────────────────────────────────

  Widget _buildAuthRequired(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  AppAssets.juegoBalotoRevancha,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.lock_outline_rounded,
                    size: 80,
                    color: Color(0xFF0C2577),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicia sesión para jugar',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C2577),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en Baloto Revancha.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => _showLoginModal(ctx),
                  child: Text(
                    'Iniciar sesión',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Contenido principal ───────────────────────────────────────────────────

  Widget _buildContent(bool isMobile) {
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 24);

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              _buildFormCard(),
              const SizedBox(height: 16),
              _buildApuestasAvanzadasCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card de selección ─────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          _buildModoToggle(),
          const SizedBox(height: 16),
          if (_modo == _SelectionMode.manual)
            _buildSeccionManual()
          else
            _buildSeccionAutomatica(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.logoBalotoRevancha,
        width: double.infinity,
        height: 150,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 150,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF091A5C), Color(0xFF1372AE)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'BALOTO\nREVANCHA!',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildModoToggle() {
    return Center(
      child: Container(
        height: 33,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ModoBtn(
              label: 'Manual',
              isSelected: _modo == _SelectionMode.manual,
              onTap: () => setState(() => _modo = _SelectionMode.manual),
            ),
            _ModoBtn(
              label: 'Automática',
              isSelected: _modo == _SelectionMode.automatica,
              onTap: () {
                setState(() => _modo = _SelectionMode.automatica);
                _generarAutomatico();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Modo manual ───────────────────────────────────────────────────────────

  Widget _buildSeccionManual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeceras de columnas
        Row(
          children: [
            Expanded(
              flex: 54,
              child: Text(
                'Selecciona 5 números',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0C2577),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 44,
              child: Text(
                'Seleccione la superbalota',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0C2577),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Grids
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 54, child: _buildBalotasGrid()),
            // Separador con flecha
            Padding(
              padding: const EdgeInsets.only(top: 36, left: 2, right: 2),
              child: Icon(
                Icons.chevron_right,
                color: const Color(0xFF0C2577),
                size: 26,
              ),
            ),
            Expanded(flex: 44, child: _buildSuperbalotaGrid()),
          ],
        ),
        if (_errorBalotas != null) ...[
          const SizedBox(height: 6),
          _ErrorText(_errorBalotas!),
        ],
        if (_errorSuperbalota != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorSuperbalota!),
        ],
        const SizedBox(height: 12),
        _buildNumerosMostrados(),
      ],
    );
  }

  Widget _buildBalotasGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 7;
      const gap = 6.0;
      final cell =
          ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(20.0, 32.0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(_kBalotaMax, (i) {
          final n = i + 1;
          return _BalotaCell(
            numero: n,
            isSelected: _balotas.contains(n),
            isSuperbalota: false,
            size: cell,
            onTap: () => _toggleBalota(n),
          );
        }),
      );
    });
  }

  Widget _buildSuperbalotaGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      const cols = 4;
      const gap = 6.0;
      final cell =
          ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(20.0, 32.0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: List.generate(_kSuperbalotaMax, (i) {
          final n = i + 1;
          return _BalotaCell(
            numero: n,
            isSelected: _superbalota == n,
            isSuperbalota: true,
            size: cell,
            onTap: () => _toggleSuperbalota(n),
          );
        }),
      );
    });
  }

  // ── Modo automático ───────────────────────────────────────────────────────

  Widget _buildSeccionAutomatica() {
    return Column(
      children: [
        _buildNumerosMostrados(),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _generarAutomatico,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFECA0C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 18, color: Color(0xFF0C2577)),
                  const SizedBox(width: 8),
                  Text(
                    'Generar nuevos números',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C2577),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Números seleccionados ─────────────────────────────────────────────────

  Widget _buildNumerosMostrados() {
    final balotas = _balotas.toList()..sort();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila balotas
          Row(
            children: [
              Text(
                'Balotas:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final n in balotas)
                      _NumCircle(numero: n, isSuper: false),
                    for (int i = balotas.length; i < _kBalotasRequeridas; i++)
                      _NumCircleEmpty(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila superbalota
          Row(
            children: [
              Text(
                'Superbalota:',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 8),
              if (_superbalota != null)
                _NumCircle(numero: _superbalota!, isSuper: true)
              else
                _NumCircleEmpty(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Apuestas avanzadas + resumen ──────────────────────────────────────────

  Widget _buildApuestasAvanzadasCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF0C2577)),
      ),
      child: Column(
        children: [
          Text(
            'Apuestas Avanzadas',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0C2577),
              height: 28 / 22,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _buildRevanchaSelector(),
          const SizedBox(height: 12),
          Text(
            '¡Adelanta tus apuestas hasta en $_kMaxSorteos sorteos y ahorra tiempo!',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF0D2677),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          _buildSorteosDropdown(),
          const SizedBox(height: 20),
          Text(
            'Resumen de la apuesta',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C2577),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          _buildResumenRow(
            'Valor Baloto',
            _fmtCop(_kPrecioBaloto * _sorteos),
            bg: const Color(0xFFF0F0F0),
          ),
          if (_conRevancha) ...[
            const SizedBox(height: 4),
            _buildResumenRow(
              'Valor Revancha',
              _fmtCop(_kPrecioRevancha * _sorteos),
              bg: const Color(0xFFF7F7F7),
            ),
          ],
          const SizedBox(height: 4),
          _buildResumenRow(
            _sorteos > 1 ? 'Total (×$_sorteos sorteos)' : 'Total a pagar',
            _fmtCop(_totalPagar),
            bg: const Color(0xFFF0F0F0),
          ),
          const SizedBox(height: 20),
          _buildBotonCarrito(),
        ],
      ),
    );
  }

  Widget _buildRevanchaSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Text(
            '¿Deseas Jugar con Revancha?',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0D2677),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RadioOpcion(
                label: 'SI',
                selected: _conRevancha,
                onTap: () => setState(() => _conRevancha = true),
              ),
              const SizedBox(width: 40),
              _RadioOpcion(
                label: 'NO',
                selected: !_conRevancha,
                onTap: () => setState(() => _conRevancha = false),
              ),
            ],
          ),
          if (_conRevancha) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECA0C)),
              ),
              child: Text(
                'Tus mismos números participan en el sorteo Revancha. Costo adicional: ${_fmtCop(_kPrecioRevancha)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF92400E),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSorteosDropdown() {
    final opciones = [
      'Jugada única',
      ...List.generate(_kMaxSorteos - 1, (i) => '${i + 2} sorteos'),
    ];
    final valorActual = _sorteos == 1 ? 'Jugada única' : '$_sorteos sorteos';

    return GestureDetector(
      onTap: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Número de sorteos',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0C2577),
                ),
              ),
              const Divider(),
              for (int i = 0; i < opciones.length; i++)
                ListTile(
                  title: Text(
                    opciones[i],
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: (i + 1) == _sorteos
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: const Color(0xFF0C2577),
                    ),
                  ),
                  trailing: (i + 1) == _sorteos
                      ? const Icon(Icons.check, color: Color(0xFF43B75D))
                      : null,
                  onTap: () {
                    setState(() => _sorteos = i + 1);
                    Navigator.pop(ctx);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF0C2577)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              valorActual,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF0C2577),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF0C2577), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenRow(String label, String valor, {required Color bg}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF0C2577),
            ),
          ),
          Text(
            valor,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0C2577),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonCarrito() {
    final activo = _apuestaCompleta;
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              activo ? const Color(0xFF43B75D) : const Color(0xFFBDD7EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: _anadirAlCarrito,
        child: Text(
          'AÑADIR AL CARRITO',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: activo ? Colors.white : const Color(0xFF6B99B9),
          ),
        ),
      ),
    );
  }

  // ── Confirmación ──────────────────────────────────────────────────────────

  Widget _buildConfirmacion(bool isMobile) {
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 24);
    final balotas = _balotas.toList()..sort();

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              // ── Card de confirmación ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      'Tu apuesta Baloto',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0C2577),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Balotas seleccionadas
                    Text(
                      'Balotas',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: balotas
                          .map((n) =>
                              _NumCircle(numero: n, isSuper: false, size: 36))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Superbalota',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _NumCircle(numero: _superbalota!, isSuper: true, size: 44),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 8),
                    _FilaDetalle(
                        'Revancha',
                        _conRevancha
                            ? 'Sí (+${_fmtCop(_kPrecioRevancha)})'
                            : 'No'),
                    _FilaDetalle('Sorteos',
                        _sorteos == 1 ? 'Jugada única' : '$_sorteos sorteos'),
                    _FilaDetalle(
                        'Valor Baloto', _fmtCop(_kPrecioBaloto * _sorteos)),
                    if (_conRevancha)
                      _FilaDetalle('Valor Revancha',
                          _fmtCop(_kPrecioRevancha * _sorteos)),
                    const Divider(color: Color(0xFFE5E7EB)),
                    _FilaDetalle('Total a pagar', _fmtCop(_totalPagar),
                        isBold: true),
                    const SizedBox(height: 20),
                    // Éxito
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF43B75D)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF43B75D), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            '¡Apuesta registrada exitosamente!',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B5E20),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _limpiar,
                            child: Text(
                              'Realizar otra apuesta',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Plan de premios ────────────────────────────────────
              _buildPlanPremios(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanPremios() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Plan de premios',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0C2577),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2577),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                // Cabecera combos
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: Color(0xFF1A3A8E), width: 1)),
                  ),
                  child: Row(
                    children: _kPlanPremios
                        .map((p) => Expanded(
                              child: Text(
                                'Acierta\n${p.combo}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                  height: 1.3,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                // Valores
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      for (int i = 0; i < _kPlanPremios.length; i++) ...[
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _kPlanPremios[i].valor,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFFFE30C),
                              ),
                            ),
                          ),
                        ),
                        if (i < _kPlanPremios.length - 1)
                          Container(
                              width: 1,
                              height: 24,
                              color: const Color(0xFF1A3A8E)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '* Premios sujetos a retención del 20% para valores que superen los \$48.000.',
            style:
                GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _BalotaCell extends StatelessWidget {
  const _BalotaCell({
    required this.numero,
    required this.isSelected,
    required this.isSuperbalota,
    required this.size,
    required this.onTap,
  });
  final int numero;
  final bool isSelected;
  final bool isSuperbalota;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (isSelected) {
      bg = isSuperbalota ? const Color(0xFFE53E3E) : const Color(0xFFFECA0C);
      fg = isSuperbalota ? Colors.white : const Color(0xFF0C2577);
    } else {
      bg = const Color(0xFFD1D5DB);
      fg = const Color(0xFF111827);
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: bg.withValues(alpha: 0.45),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          numero.toString().padLeft(2, '0'),
          style: GoogleFonts.inter(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: fg,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _NumCircle extends StatelessWidget {
  const _NumCircle({
    required this.numero,
    required this.isSuper,
    this.size = 26,
  });
  final int numero;
  final bool isSuper;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSuper ? const Color(0xFFE53E3E) : const Color(0xFFFECA0C),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: GoogleFonts.inter(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
          color: isSuper ? Colors.white : const Color(0xFF0C2577),
        ),
      ),
    );
  }
}

class _NumCircleEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF9CA3AF)),
      ),
    );
  }
}

class _RadioOpcion extends StatelessWidget {
  const _RadioOpcion({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? const Color(0xFFFECA0C)
                    : const Color(0xFFD1D5DB),
                width: 2,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFECA0C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF0D2677),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModoBtn extends StatelessWidget {
  const _ModoBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0C2577) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  const _FilaDetalle(this.label, this.valor, {this.isBold = false});
  final String label;
  final String valor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          Text(
            valor,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF0C2577),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFDA1414)),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF1372AE) : const Color(0xFF9CA3AF);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

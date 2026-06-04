// HU-BAL001 – Baloto
// Producto: Baloto / Baloto Revancha
// Módulo: Aplicación Móvil
// Versión: 1.0.0.0 – 24/04/2026

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

// ── Constantes de negocio HU-BAL001 ──────────────────────────────────────────
// RN: Baloto $6.000 · Revancha $3.000 adicionales · total con Revancha $9.000
// Días de sorteo: lunes (1), miércoles (3), sábado (6)
// Balotas: 5 únicas de 1-43 · Superbalota: 1 de 1-16

const int _kPrecioBaloto = 6000;
const int _kPrecioRevancha = 3000;
const int _kBalotaMax = 43;
const int _kSuperbalotaMax = 16;
const int _kBalotasRequeridas = 5;
const int _kMaxSorteosVenta = 9;

// Acumulados base (HU-BAL001) — se reemplaza por API cuando esté disponible
const int _kAcumuladoBalotoBase = 4000000000; // $4.000 millones
const int _kAcumuladoRevanchaBase = 2000000000; // $2.000 millones

// Días de sorteo ISO weekday: 1=lun, 3=mié, 6=sáb
const List<int> _kDiasSorteo = [1, 3, 6];
const List<String> _kNombresDias = [
  '',
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom'
];

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

String _fmtMillones(int amount) {
  if (amount >= 1000000000) {
    final bil = amount / 1000000000;
    final fmt =
        bil == bil.truncate() ? '${bil.truncate()}' : bil.toStringAsFixed(1);
    return '\$$fmt mil millones';
  }
  if (amount >= 1000000) {
    final mil = amount / 1000000;
    final fmt =
        mil == mil.truncate() ? '${mil.truncate()}' : mil.toStringAsFixed(0);
    return '\$$fmt millones';
  }
  return _fmtCop(amount);
}

/// Genera los próximos N sorteos a partir de hoy (lunes, miércoles, sábado).
List<DateTime> _proximosSorteos(int cantidad) {
  final sorteos = <DateTime>[];
  var dia = DateTime.now();
  while (sorteos.length < cantidad) {
    dia = dia.add(const Duration(days: 1));
    if (_kDiasSorteo.contains(dia.weekday)) {
      sorteos.add(dia);
    }
  }
  return sorteos;
}

String _labelSorteo(DateTime d, int idx) {
  final diaNombre = _kNombresDias[d.weekday];
  return '$diaNombre ${d.day}/${d.month}';
}

// ── Estado de geo / compra ────────────────────────────────────────────────────

enum _GeoEstado { pendiente, activa, bloqueada }

enum _CompraEstado { idle, procesando, exitosa, error }

// ── Plan de premios (paramutual — HU-BAL001) ─────────────────────────────────
// Los valores exactos dependen del acumulado; se muestran como referencia.

const _kPlanPremios = <({String combo, String descripcion, String valor})>[
  (combo: '5+S', descripcion: '5 balotas + superbalota', valor: 'Acumulado'),
  (combo: '5', descripcion: '5 balotas', valor: 'Variable'),
  (combo: '4+S', descripcion: '4 balotas + superbalota', valor: 'Variable'),
  (combo: '4', descripcion: '4 balotas', valor: 'Variable'),
  (combo: '3+S', descripcion: '3 balotas + superbalota', valor: 'Variable'),
  (combo: '3', descripcion: '3 balotas', valor: 'Variable'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class BalotoRevanchaScreen extends StatefulWidget {
  const BalotoRevanchaScreen({super.key});

  @override
  State<BalotoRevanchaScreen> createState() => _BalotoRevanchaScreenState();
}

class _BalotoRevanchaScreenState extends State<BalotoRevanchaScreen> {
  // ── Estado de selección ──────────────────────────────────────────────────
  bool _modoAutomatico = false;
  final Set<int> _balotas = {};
  int? _superbalota;
  bool _conRevancha = false;

  // ── Sorteos disponibles (HU-BAL001 RN: lun/mié/sáb) ────────────────────
  late final List<DateTime> _sorteosDisponibles;
  final Set<int> _sorteosSeleccionados =
      {}; // índices dentro de _sorteosDisponibles

  // ── Estado geo / compra ─────────────────────────────────────────────────
  _GeoEstado _geoEstado = _GeoEstado.pendiente;
  _CompraEstado _compraEstado = _CompraEstado.idle;
  String? _ticketNumero;

  // ── Acumulados vigentes (stub — reemplazar con API ONJ) ─────────────────
  int _acumuladoBaloto = _kAcumuladoBalotoBase;
  int _acumuladoRevancha = _kAcumuladoRevanchaBase;

  // ── Errores de validación ────────────────────────────────────────────────
  String? _errorBalotas;
  String? _errorSuperbalota;
  String? _errorSorteo;

  bool _confirmacionVisible = false;

  @override
  void initState() {
    super.initState();
    _sorteosDisponibles = _proximosSorteos(_kMaxSorteosVenta);
    _iniciarGeovalidacion();
  }

  // ── Georreferenciación (HU-BAL001 E6) ────────────────────────────────────
  // TODO: reemplazar con plugin de geolocalización real (geolocator / permission_handler)
  void _iniciarGeovalidacion() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _geoEstado = _GeoEstado.activa);
    });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  int get _cantidadSorteos =>
      _sorteosSeleccionados.isEmpty ? 1 : _sorteosSeleccionados.length;

  int get _totalPagar =>
      (_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)) *
      _cantidadSorteos;

  bool get _apuestaCompleta =>
      _balotas.length == _kBalotasRequeridas &&
      _superbalota != null &&
      _cantidadSorteos >= 1;

  // ── Lógica de negocio ────────────────────────────────────────────────────

  void _toggleBalota(int n) {
    setState(() {
      if (_balotas.contains(n)) {
        _balotas.remove(n);
        _errorBalotas = null;
      } else {
        if (_balotas.length >= _kBalotasRequeridas) {
          // E2: no permitir más de 5 balotas (HU-BAL001)
          _errorBalotas =
              'Ya seleccionaste $_kBalotasRequeridas balotas. Deselecciona una para cambiar.';
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

  void _toggleSorteo(int idx) {
    setState(() {
      if (_sorteosSeleccionados.contains(idx)) {
        _sorteosSeleccionados.remove(idx);
      } else {
        _sorteosSeleccionados.add(idx);
      }
      _errorSorteo = null;
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

  // Limpiar (HU-BAL001 botón Limpiar)
  void _limpiar() {
    setState(() {
      _balotas.clear();
      _superbalota = null;
      _conRevancha = false;
      _sorteosSeleccionados.clear();
      _errorBalotas = null;
      _errorSuperbalota = null;
      _errorSorteo = null;
      _modoAutomatico = false;
      _confirmacionVisible = false;
      _compraEstado = _CompraEstado.idle;
      _ticketNumero = null;
    });
  }

  // Cancelar (HU-BAL001 botón Cancelar — regresa sin registrar)
  void _cancelar(BuildContext ctx) {
    if (Navigator.canPop(ctx)) {
      Navigator.pop(ctx);
    } else {
      ctx.go(AppRoutes.juegos);
    }
  }

  bool _validar() {
    bool ok = true;
    setState(() {
      _errorBalotas = _balotas.length != _kBalotasRequeridas
          ? 'Debes seleccionar exactamente $_kBalotasRequeridas balotas (1-$_kBalotaMax)'
          : null;
      _errorSuperbalota = _superbalota == null
          ? 'Debes seleccionar la superbalota (1-$_kSuperbalotaMax)'
          : null;
      ok = _errorBalotas == null && _errorSuperbalota == null;
    });
    return ok;
  }

  // Avanzar a confirmación (HU-BAL001 paso 11-12)
  void _continuarAConfirmacion() {
    if (_geoEstado == _GeoEstado.bloqueada) {
      _mostrarGeoError();
      return;
    }
    if (!_validar()) return;
    setState(() => _confirmacionVisible = true);
  }

  // Procesar compra (HU-BAL001 paso 13-14)
  Future<void> _confirmarCompra() async {
    setState(() {
      _compraEstado = _CompraEstado.procesando;
    });
    // TODO: Integrar con API transaccional ONJ/Baloto
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    // Simulación exitosa — reemplazar con respuesta real del servicio
    setState(() {
      _compraEstado = _CompraEstado.exitosa;
      _ticketNumero =
          'BAL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    });
  }

  void _mostrarGeoError() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ubicación requerida',
          style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0C2577)),
        ),
        content: Text(
          'La venta de Baloto solo está disponible en zonas autorizadas. '
          'Por favor, activa la geolocalización y verifica que te encuentras en un área permitida.',
          style: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFF4B5563), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Entendido',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C2577))),
          ),
        ],
      ),
    );
  }

  // ── Login modal ──────────────────────────────────────────────────────────

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
            onTap: () {},
          ),
          _NavIcon(
            icon: Icons.person_outline,
            label: 'Perfil',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Build principal ──────────────────────────────────────────────────────

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
                    else
                      _buildBodyPrincipal(context, isMobile),
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

  Widget _buildBodyPrincipal(BuildContext context, bool isMobile) {
    // E4: sin sorteos disponibles
    if (_sorteosDisponibles.isEmpty) {
      return _buildSinSorteos();
    }
    // E6: geo bloqueada (se muestra banner pero bloquea compra)
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 24);

    if (_compraEstado == _CompraEstado.exitosa && _ticketNumero != null) {
      return Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildCompraExitosa(),
          ),
        ),
      );
    }

    if (_confirmacionVisible) {
      return Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildConfirmacion(context),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              _buildCardPrincipal(context),
              const SizedBox(height: 16),
              _buildApuestasAvanzadasCard(),
              const SizedBox(height: 16),
              _buildPlanPremios(),
            ],
          ),
        ),
      ),
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
                'Inicia sesión para jugar Baloto',
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
                    fontSize: 15, color: const Color(0xFF4B5563), height: 1.5),
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
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── E4: sin sorteos disponibles ───────────────────────────────────────────

  Widget _buildSinSorteos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy, size: 56, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 16),
              Text(
                'Sin sorteos disponibles',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'No existen sorteos disponibles para venta en este momento. '
                'Los sorteos se realizan los lunes, miércoles y sábados.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF4B5563), height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card principal del formulario ─────────────────────────────────────────

  Widget _buildCardPrincipal(BuildContext context) {
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
          // Banner con logo
          _buildBanner(),
          const SizedBox(height: 12),
          // Sección acumulados + días de sorteo (HU-BAL001)
          _buildInfoJuego(),
          const SizedBox(height: 16),
          // Alerta geo si está pendiente
          if (_geoEstado == _GeoEstado.bloqueada) _buildGeoBloqueadaBanner(),
          // Sorteos (HU-BAL001 paso 3-4)
          _buildPasoSorteos(),
          const SizedBox(height: 16),
          const _Divisor(),
          const SizedBox(height: 16),
          // Selección de números (HU-BAL001 paso 5-8)
          _buildPasoNumeros(),
          const SizedBox(height: 20),
          // Botones principales (HU-BAL001)
          _buildBotonesAccion(context),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

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
            'BALOTO  REVANCHA!',
            style: GoogleFonts.inter(
              fontSize: 26,
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

  // ── Información del juego — HU-BAL001 paso 2 ─────────────────────────────
  // Muestra: valor Baloto, valor Revancha, días de sorteo, acumulados vigentes

  Widget _buildInfoJuego() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFD0FF)),
      ),
      child: Column(
        children: [
          // Fila de valores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InfoChip(
                label: 'Baloto',
                valor: _fmtCop(_kPrecioBaloto),
                color: const Color(0xFF0C2577),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFBFD0FF)),
              _InfoChip(
                label: 'Revancha',
                valor: '+ ${_fmtCop(_kPrecioRevancha)}',
                color: const Color(0xFF1372AE),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFBFD0FF)),
              _InfoChip(
                label: 'Con Revancha',
                valor: _fmtCop(_kPrecioBaloto + _kPrecioRevancha),
                color: const Color(0xFF43B75D),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Días de sorteo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Color(0xFF6B7280)),
              const SizedBox(width: 4),
              Text(
                'Sorteos: Lunes · Miércoles · Sábado',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Acumulados vigentes (HU-BAL001 RN: consultar desde fuente oficial)
          Row(
            children: [
              Expanded(
                child: _AcumuladoCard(
                  titulo: 'Acumulado Baloto',
                  valor: _fmtMillones(_acumuladoBaloto),
                  color: const Color(0xFF0C2577),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AcumuladoCard(
                  titulo: 'Acumulado Revancha',
                  valor: _fmtMillones(_acumuladoRevancha),
                  color: const Color(0xFF1372AE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Banner geo bloqueada (E6) ─────────────────────────────────────────────

  Widget _buildGeoBloqueadaBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Geolocalización bloqueada. La venta de Baloto solo está disponible en zonas autorizadas.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF991B1B), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Paso sorteos — HU-BAL001 pasos 3-4 ───────────────────────────────────

  Widget _buildPasoSorteos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PasoLabel(
          numero: '1',
          texto: 'Selecciona el sorteo o sorteos en que deseas participar',
        ),
        const SizedBox(height: 10),
        // Próximo sorteo siempre visible como opción rápida
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_sorteosDisponibles.length, (i) {
            final d = _sorteosDisponibles[i];
            final seleccionado = _sorteosSeleccionados.contains(i) ||
                (_sorteosSeleccionados.isEmpty && i == 0);
            return _SorteoChip(
              label:
                  i == 0 ? 'Próx. ${_labelSorteo(d, i)}' : _labelSorteo(d, i),
              isSelected: seleccionado,
              onTap: () => _toggleSorteo(i),
            );
          }),
        ),
        if (_errorSorteo != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorSorteo!),
        ],
        const SizedBox(height: 6),
        Text(
          'Puedes seleccionar hasta $_kMaxSorteosVenta sorteos. Valor total: ${_fmtCop(_totalPagar)}',
          style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF6B7280),
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ── Paso selección de números — HU-BAL001 pasos 5-8 ──────────────────────

  Widget _buildPasoNumeros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PasoLabel(
          numero: '2',
          texto: 'Selecciona tus números',
        ),
        const SizedBox(height: 12),
        // Toggle Manual / Automática
        _buildModoToggle(),
        const SizedBox(height: 16),
        if (_modoAutomatico)
          _buildSeccionAutomatica()
        else
          _buildSeccionManual(),
      ],
    );
  }

  Widget _buildModoToggle() {
    return Center(
      child: Container(
        height: 34,
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
              isSelected: !_modoAutomatico,
              onTap: () => setState(() => _modoAutomatico = false),
            ),
            _ModoBtn(
              label: 'Automática',
              isSelected: _modoAutomatico,
              onTap: () {
                setState(() => _modoAutomatico = true);
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
        // Cabeceras
        Row(
          children: [
            Expanded(
              flex: 54,
              child: Text(
                'Selecciona 5 números (1-$_kBalotaMax)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C2577)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 44,
              child: Text(
                'Superbalota (1-$_kSuperbalotaMax)',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C2577)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 54, child: _buildBalotasGrid()),
            Padding(
              padding: const EdgeInsets.only(top: 36, left: 2, right: 2),
              child: const Icon(Icons.chevron_right,
                  color: Color(0xFF0C2577), size: 26),
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
      const gap = 5.0;
      final cell =
          ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(20.0, 30.0);
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
      const gap = 5.0;
      final cell =
          ((constraints.maxWidth - gap * (cols - 1)) / cols).clamp(20.0, 30.0);
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

  // ── Modo automático (HU-BAL001 flujo 5.1) ────────────────────────────────

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

  // ── Números mostrados ─────────────────────────────────────────────────────

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
          Row(
            children: [
              Text(
                'Balotas:',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563)),
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
          Row(
            children: [
              Text(
                'Superbalota:',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4B5563)),
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

  // ── Botones acción — HU-BAL001 (Limpiar, Automática, Continuar, Cancelar) ─

  Widget _buildBotonesAccion(BuildContext context) {
    return Column(
      children: [
        // Fila Limpiar + Automática (HU-BAL001)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6B7280)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _limpiar,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: Color(0xFF6B7280)),
                label: Text(
                  'Limpiar',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFECA0C), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () {
                  setState(() => _modoAutomatico = true);
                  _generarAutomatico();
                },
                icon: const Icon(Icons.shuffle,
                    size: 16, color: Color(0xFF0C2577)),
                label: Text(
                  'Automática',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0C2577)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Botón Continuar (solo habilitado si completo — HU-BAL001)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _apuestaCompleta
                  ? const Color(0xFF0C2577)
                  : const Color(0xFFBDD7EE),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            onPressed: () => _continuarAConfirmacion(),
            child: Text(
              'Continuar',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    _apuestaCompleta ? Colors.white : const Color(0xFF6B99B9),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Botón Cancelar (HU-BAL001 — regresa sin registrar)
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () => _cancelar(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Apuestas Avanzadas — Revancha + Sorteos ───────────────────────────────

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
          // Revancha (HU-BAL001 paso 9-10)
          _buildRevanchaSelector(),
          const SizedBox(height: 20),
          // Resumen (HU-BAL001)
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
            _fmtCop(_kPrecioBaloto),
            bg: const Color(0xFFF0F0F0),
          ),
          if (_conRevancha) ...[
            const SizedBox(height: 4),
            _buildResumenRow(
              'Valor Revancha',
              '+ ${_fmtCop(_kPrecioRevancha)}',
              bg: const Color(0xFFF7F7F7),
            ),
          ],
          const SizedBox(height: 4),
          _buildResumenRow(
            'Subtotal por sorteo',
            _fmtCop(_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)),
            bg: const Color(0xFFF0F0F0),
          ),
          if (_cantidadSorteos > 1) ...[
            const SizedBox(height: 4),
            _buildResumenRow(
              'Cantidad de sorteos',
              '× $_cantidadSorteos',
              bg: const Color(0xFFF7F7F7),
            ),
          ],
          const SizedBox(height: 4),
          _buildResumenRow(
            'Total a pagar',
            _fmtCop(_totalPagar),
            bg: const Color(0xFFF0F0F0),
            isBold: true,
          ),
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
                // HU-BAL001 flujo alterno 9.1.1
                'Revancha participa con los mismos números de Baloto en un sorteo independiente. '
                'Costo adicional: ${_fmtCop(_kPrecioRevancha)} por sorteo.',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF92400E)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResumenRow(
    String label,
    String valor, {
    required Color bg,
    bool isBold = false,
  }) {
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
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
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

  // ── Confirmación — HU-BAL001 paso 12 ─────────────────────────────────────
  // Muestra: sorteo(s), números, estado Revancha, valor total, acumulado vigente

  Widget _buildConfirmacion(BuildContext context) {
    final balotas = _balotas.toList()..sort();
    final sorteosMostrar = _sorteosSeleccionados.isEmpty
        ? [_sorteosDisponibles[0]]
        : _sorteosSeleccionados.map((i) => _sorteosDisponibles[i]).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Confirma tu apuesta',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Números
              Center(
                child: Text(
                  'Tus balotas',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: balotas
                      .map((n) =>
                          _NumCircle(numero: n, isSuper: false, size: 36))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Tu superbalota',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child:
                    _NumCircle(numero: _superbalota!, isSuper: true, size: 44),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 8),
              // Sorteos
              _FilaDetalle(
                'Sorteo(s)',
                sorteosMostrar.map((d) => _labelSorteo(d, 0)).join(' · '),
              ),
              _FilaDetalle(
                  'Revancha',
                  _conRevancha
                      ? 'Sí (+${_fmtCop(_kPrecioRevancha)}/sorteo)'
                      : 'No'),
              _FilaDetalle('Cantidad de sorteos', '$_cantidadSorteos'),
              _FilaDetalle(
                  'Valor por sorteo',
                  _fmtCop(
                      _kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0))),
              const Divider(color: Color(0xFFE5E7EB)),
              _FilaDetalle('Total a pagar', _fmtCop(_totalPagar), isBold: true),
              const SizedBox(height: 12),
              // Acumulado vigente en confirmación (HU-BAL001 paso 12)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Acumulado vigente',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              'Baloto',
                              style: GoogleFonts.inter(
                                  fontSize: 10, color: const Color(0xFF6B7280)),
                            ),
                            Text(
                              _fmtMillones(_acumuladoBaloto),
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0C2577)),
                            ),
                          ],
                        ),
                        if (_conRevancha)
                          Column(
                            children: [
                              Text(
                                'Revancha',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF6B7280)),
                              ),
                              Text(
                                _fmtMillones(_acumuladoRevancha),
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1372AE)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // E5: error de procesamiento
              if (_compraEstado == _CompraEstado.error) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    'No se pudo completar la compra. Intente nuevamente más tarde.',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF991B1B),
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // Botones Comprar + Cancelar (HU-BAL001 pasos 13-14)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6B7280)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      // E7: cancelar antes de confirmar — no registra apuesta
                      onPressed: () =>
                          setState(() => _confirmacionVisible = false),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B7280)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43B75D),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _compraEstado == _CompraEstado.procesando
                          ? null
                          : _confirmarCompra,
                      child: _compraEstado == _CompraEstado.procesando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Comprar',
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Compra exitosa — HU-BAL001 paso 14 ───────────────────────────────────
  // Mensaje: "Compra realizada con éxito" + número de comprobante

  Widget _buildCompraExitosa() {
    final balotas = _balotas.toList()..sort();
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Icono éxito
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF43B75D), size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                'Compra realizada con éxito',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B5E20),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Número de comprobante (HU-BAL001 postcondiciones)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Comprobante: ${_ticketNumero ?? ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577),
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Detalle de compra
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Tus balotas',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: balotas
                          .map((n) =>
                              _NumCircle(numero: n, isSuper: false, size: 32))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Superbalota',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 6),
                    _NumCircle(numero: _superbalota!, isSuper: true, size: 36),
                    const SizedBox(height: 10),
                    const Divider(color: Color(0xFFE5E7EB)),
                    _FilaDetalle('Revancha', _conRevancha ? 'Sí' : 'No'),
                    _FilaDetalle('Sorteos', '$_cantidadSorteos'),
                    _FilaDetalle('Total pagado', _fmtCop(_totalPagar),
                        isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C2577),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _limpiar,
                  child: Text(
                    'Realizar otra apuesta',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildPlanPremios(),
      ],
    );
  }

  // ── Plan de premios paramutual (HU-BAL001) ────────────────────────────────

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
          const SizedBox(height: 4),
          Text(
            'Los premios son paramutuales y dependen del acumulado y número de ganadores.',
            style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF6B7280), height: 1.4),
            textAlign: TextAlign.center,
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
            '* Premio mayor: acumulado base de ${_fmtMillones(_kAcumuladoBalotoBase)}. '
            'Sujeto a retención del 20% para premios que superen \$48.000.',
            style: GoogleFonts.inter(
                fontSize: 10, color: const Color(0xFF9CA3AF), height: 1.4),
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
                  ),
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
  const _NumCircle(
      {required this.numero, required this.isSuper, this.size = 26});
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

class _SorteoChip extends StatelessWidget {
  const _SorteoChip({
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
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0C2577) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0C2577) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _PasoLabel extends StatelessWidget {
  const _PasoLabel({required this.numero, required this.texto});
  final String numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: Color(0xFF0C2577),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            numero,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C2577),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.valor,
    required this.color,
  });
  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style:
              GoogleFonts.inter(fontSize: 10, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}

class _AcumuladoCard extends StatelessWidget {
  const _AcumuladoCard({
    required this.titulo,
    required this.valor,
    required this.color,
  });
  final String titulo;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style:
                GoogleFonts.inter(fontSize: 10, color: const Color(0xFF4B5563)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
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

class _Divisor extends StatelessWidget {
  const _Divisor();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1);
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

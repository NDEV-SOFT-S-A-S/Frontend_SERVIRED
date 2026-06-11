// HU-BAL001 – Baloto
// Producto: Baloto / Baloto Revancha
// Módulo: Aplicación Móvil
// Versión: 1.0.0.0 – 24/04/2026

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/login_redirect_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../carrito/presentation/screens/carrito_screen.dart';
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
  bool _conRevancha = true;

  // ── Líneas guardadas (múltiples apuestas) ────────────────────────────────
  final List<_LineaData> _lineasGuardadas = [];

  // ── Sorteos disponibles (HU-BAL001 RN: lun/mié/sáb) ────────────────────
  late final List<DateTime> _sorteosDisponibles;
  final Set<int> _sorteosSeleccionados =
      {}; // índices dentro de _sorteosDisponibles

  // ── Animación balotera ───────────────────────────────────────────────────
  bool _animandoBalotera = false;
  List<int> _numerosVisibles = List.filled(6, 0); // índice 0-4 balotas, 5 super
  List<bool> _balotasDetenidas = List.filled(6, false);
  Timer? _timerRuleta;

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

  int get _totalLineas => _lineasGuardadas.length + 1;

  int get _totalPagar =>
      (_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)) *
      _cantidadSorteos *
      _totalLineas;

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

  @override
  void dispose() {
    _timerRuleta?.cancel();
    super.dispose();
  }

  void _generarAutomatico() {
    final rng = math.Random();
    final pool = List.generate(_kBalotaMax, (i) => i + 1)..shuffle(rng);
    final superPool = List.generate(_kSuperbalotaMax, (i) => i + 1)
      ..shuffle(rng);
    final finalesBalotas = pool.take(_kBalotasRequeridas).toList();
    final finalSuper = superPool.first;

    // Cancelar animación anterior si existe
    _timerRuleta?.cancel();

    setState(() {
      _balotas.clear();
      _superbalota = null;
      _animandoBalotera = true;
      _numerosVisibles = List.filled(6, 1);
      _balotasDetenidas = List.filled(6, false);
      _errorBalotas = null;
      _errorSuperbalota = null;
    });

    // Rotar números aleatorios cada 60ms
    _timerRuleta = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        for (int i = 0; i < 6; i++) {
          if (!_balotasDetenidas[i]) {
            _numerosVisibles[i] = i < 5
                ? rng.nextInt(_kBalotaMax) + 1
                : rng.nextInt(_kSuperbalotaMax) + 1;
          }
        }
      });
    });

    // Detener cada bola secuencialmente con delay creciente
    for (int i = 0; i < 6; i++) {
      final idx = i;
      Future.delayed(Duration(milliseconds: 600 + idx * 250), () {
        if (!mounted) return;
        setState(() {
          _balotasDetenidas[idx] = true;
          _numerosVisibles[idx] =
              idx < 5 ? finalesBalotas[idx] : finalSuper;
        });
        // Cuando la última bola se detiene, guardar resultado
        if (idx == 5) {
          _timerRuleta?.cancel();
          setState(() {
            _animandoBalotera = false;
            _balotas
              ..clear()
              ..addAll(finalesBalotas);
            _superbalota = finalSuper;
          });
        }
      });
    }
  }

  // Limpiar (HU-BAL001 botón Limpiar)
  void _limpiar() {
    setState(() {
      _balotas.clear();
      _superbalota = null;
      _conRevancha = true;
      _sorteosSeleccionados.clear();
      _errorBalotas = null;
      _errorSuperbalota = null;
      _modoAutomatico = false;
      _confirmacionVisible = false;
      _compraEstado = _CompraEstado.idle;
      _ticketNumero = null;
      _lineasGuardadas.clear();
    });
  }

  // Agregar línea actual y crear nueva
  void _agregarLinea() {
    if (!_validar()) return;
    setState(() {
      _lineasGuardadas.add(_LineaData(
        numero: _lineasGuardadas.length + 1,
        balotas: _balotas.toList()..sort(),
        superbalota: _superbalota!,
      ));
      _balotas.clear();
      _superbalota = null;
      _errorBalotas = null;
      _errorSuperbalota = null;
      _modoAutomatico = false;
    });
  }

  // Eliminar línea guardada por índice
  void _irAlCarrito() {
    if (!_validar()) return;
    // Construir la lista de ítems: guardadas + la línea actual
    final todasLasLineas = [
      ..._lineasGuardadas.map((l) => CarritoItem(
            balotas: l.balotas,
            superbalota: l.superbalota,
            conRevancha: _conRevancha,
            cantidadSorteos: _cantidadSorteos,
            precioTotal: (_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)) * _cantidadSorteos,
          )),
      CarritoItem(
        balotas: _balotas.toList()..sort(),
        superbalota: _superbalota!,
        conRevancha: _conRevancha,
        cantidadSorteos: _cantidadSorteos,
        precioTotal: (_kPrecioBaloto + (_conRevancha ? _kPrecioRevancha : 0)) * _cantidadSorteos,
      ),
    ];
    context.push(AppRoutes.carrito, extra: todasLasLineas);
  }

  void _eliminarLinea(int index) {
    setState(() {
      _lineasGuardadas.removeAt(index);
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
      LoginRedirectService.save(AppRoutes.balotoRevancha);
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
          backgroundColor: const Color(0xFF1372AE),
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
    if (_sorteosDisponibles.isEmpty) return _buildSinSorteos();

    final isDesktop = !isMobile;
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 65, vertical: 24);

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
            constraints: BoxConstraints(maxWidth: isDesktop ? 720 : 560),
            child: _buildConfirmacion(context),
          ),
        ),
      );
    }

    if (isMobile) {
      return Padding(
        // Figma: tarjeta a x=9 del borde de la pantalla
        padding: const EdgeInsets.fromLTRB(9, 0, 9, 16),
        child: _buildMobileUnifiedCard(context),
      );
    }

    // Desktop: layout de dos columnas
    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1617),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 885,
                      child: _buildCardPrincipal(context, showCta: false),
                    ),
                    const SizedBox(width: 40),
                    Expanded(
                      flex: 664,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 54),
                        child: _buildApuestasAvanzadasCard(showCta: true),
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

  Widget _buildCardPrincipal(BuildContext context, {bool showCta = true}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          const SizedBox(height: 25),
          if (_geoEstado == _GeoEstado.bloqueada) ...[
            _buildGeoBloqueadaBanner(),
            const SizedBox(height: 25),
          ],
          _buildPasoNumeros(),
          if (showCta) ...[
            const SizedBox(height: 25),
            _buildBotonesAccion(context),
          ],
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.bannerBalotoRevancha,
        width: double.infinity,
        fit: BoxFit.fitWidth,
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

  // ── Paso selección de números — HU-BAL001 pasos 5-8 ──────────────────────

  Widget _buildPasoNumeros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'MANUAL',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0C2577),
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: _modoAutomatico,
          onChanged: (value) {
            setState(() {
              _modoAutomatico = value;
              if (value) {
                _balotas.clear();
                _superbalota = null;
              }
              _errorBalotas = null;
              _errorSuperbalota = null;
            });
          },
          activeThumbColor: Colors.white,
          activeTrackColor: const Color(0xFF0C2577),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFCBD5E1),
          thumbColor: WidgetStateProperty.all(Colors.white),
        ),
        const SizedBox(width: 12),
        Text(
          'AUTOMÁTICO',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0C2577),
          ),
        ),
      ],
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
                'Selecciona 5 números',
                style: GoogleFonts.inter(
                    fontSize: 19.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 44,
              child: Text(
                'Seleccione la superbalota',
                style: GoogleFonts.inter(
                    fontSize: 19.5,
                    fontWeight: FontWeight.w700,
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
            const Padding(
              padding: EdgeInsets.only(top: 36, left: 4, right: 4),
              child: Icon(Icons.chevron_right,
                  color: Color(0xFF0C2577), size: 28),
            ),
            Expanded(flex: 44, child: _buildSuperbalotaGrid()),
          ],
        ),
        // Errores debajo del Row — ancho completo para no desbordarse
        if (_errorBalotas != null) ...[
          const SizedBox(height: 8),
          _ErrorText(_errorBalotas!),
        ],
        if (_errorSuperbalota != null) ...[
          const SizedBox(height: 8),
          _ErrorText(_errorSuperbalota!),
        ],
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 291),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNumerosMostrados(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalotasGrid() {
    const gap = 10.0;
    const cell = 28.0;
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
  }

  Widget _buildSuperbalotaGrid() {
    const gap = 10.0;
    const cell = 28.0;
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
  }

  // ── Modo automático (HU-BAL001 flujo 5.1) ────────────────────────────────

  Widget _buildSeccionAutomatica() {
    final tieneNumeros = _balotas.isNotEmpty && _superbalota != null;
    return Column(
      children: [
        _buildBalotera(),
        const SizedBox(height: 8),
        // Botones: JUGAR cuando vacío, AGREGAR + ↻ cuando hay números
        Center(
          child: tieneNumeros
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón AGREGAR — amarillo
                    GestureDetector(
                      onTap: _agregarLinea,
                      child: Container(
                        width: 191,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE30C),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'AGREGAR',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D1B3E),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón ↻ refresh — gris circular
                    GestureDetector(
                      onTap: _generarAutomatico,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE5E7EB),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF374151),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _generarAutomatico,
                  child: Container(
                    width: 191,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53E3E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'JUGAR',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 291),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_buildNumerosMostrados()],
          ),
        ),
      ],
    );
  }

  Widget _buildBalotera() {
    // Durante animación usamos _numerosVisibles, si no los valores reales
    List<int> displayBalotas;
    int displaySuper;
    List<bool> detenidas;

    if (_animandoBalotera) {
      displayBalotas = _numerosVisibles.sublist(0, 5);
      displaySuper   = _numerosVisibles[5];
      detenidas      = _balotasDetenidas;
    } else {
      final sorted = _balotas.isEmpty
          ? List.filled(_kBalotasRequeridas, 0)
          : (_balotas.toList()..sort());
      displayBalotas = sorted;
      displaySuper   = _superbalota ?? 0;
      detenidas      = List.filled(6, !_balotas.isEmpty);
    }

    // Tubo responsivo: LayoutBuilder externo captura el ancho REAL disponible
    // y desde él deriva: alto del tubo (aspecto fijo) y tamaño de cada bola.
    return GestureDetector(
      onTap: _animandoBalotera ? null : _generarAutomatico,
      child: MouseRegion(
        cursor: _animandoBalotera
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: LayoutBuilder(
          builder: (context, outer) {
            // ── Geometría del tubo ──────────────────────────────────────────
            // Ancho = todo el espacio disponible (sin límite superior)
            final tubeW = outer.maxWidth;
            // Alto = proporción 408:190 → escala según el ancho real
            final tubeH = tubeW * (190 / 408);

            // ── Geometría de las bolas ──────────────────────────────────────
            // Zona interior del tubo (sin tapas metálicas).
            // Figma: tapas ~19.4% c/lado → área de vidrio ~61.2% del ancho total.
            // Se usa 0.58 para dejar ~2% de margen en cada extremo y evitar
            // que la primera y última balota queden detrás de los conectores.
            final innerW  = tubeW * 0.58;
            const nBalls  = 6;
            const nGaps   = nBalls - 1;
            // Gap entre bolas: 1% del ancho del tubo (escala con él)
            final gap     = tubeW * 0.010;
            // Bola por ancho disponible
            final byW     = (innerW - nGaps * gap) / nBalls;
            // Bola por alto disponible (margen 18% arriba/abajo)
            final byH     = tubeH * 0.82;
            // Tamaño final: el menor de los dos límites
            final ballSz  = math.min(byW, byH).clamp(12.0, 72.0);
            final fontSz  = (ballSz * 0.40).clamp(7.0, 24.0);
            final rowW    = ballSz * nBalls + nGaps * gap;

            return SizedBox(
              width: tubeW,
              height: tubeH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Imagen del tubo (ocupa todo) ──
                  Positioned.fill(
                    child: Image.asset(
                      AppAssets.baloteraTube,
                      fit: BoxFit.fill,
                    ),
                  ),
                  // ── Bolas centradas en la zona interior ──
                  SizedBox(
                    width: rowW,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ...List.generate(_kBalotasRequeridas, (i) =>
                          _BalotaCircle(
                            numero: displayBalotas[i],
                            isSuper: false,
                            detenida: detenidas[i],
                            size: ballSz,
                            fontSize: fontSz,
                          ),
                        ),
                        _BalotaCircle(
                          numero: displaySuper,
                          isSuper: true,
                          detenida: detenidas[5],
                          size: ballSz,
                          fontSize: fontSz,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Números mostrados ─────────────────────────────────────────────────────


  Widget _buildNumerosMostrados() {
    final balotasSorted = _balotas.toList()..sort();
    final lineaNum = _lineasGuardadas.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Líneas guardadas anteriores
        ..._lineasGuardadas.asMap().entries.map((e) {
          final idx = e.key;
          final linea = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLineaBar(
              numero: linea.numero,
              balotas: linea.balotas,
              superbalota: linea.superbalota,
              onDelete: () => _eliminarLinea(idx),
              isEditing: false,
            ),
          );
        }),
        // Línea actual (en edición)
        _buildLineaBar(
          numero: lineaNum,
          balotas: balotasSorted,
          superbalota: _superbalota,
          onAdd: _agregarLinea,
          onDelete: _limpiar,
          isEditing: true,
        ),
      ],
    );
  }

  Widget _buildLineaBar({
    required int numero,
    required List<int> balotas,
    required int? superbalota,
    VoidCallback? onAdd,
    required VoidCallback onDelete,
    required bool isEditing,
    bool isMobile = false,
  }) {
    final double containerH  = isMobile ? 52 : 66;
    final double labelFontSz = isMobile ? 12 : 16;
    final double btnSize     = isMobile ? 26 : 38;
    final double iconSz      = isMobile ? 14 : 18;
    final EdgeInsets pad     = isMobile
        ? const EdgeInsets.only(left: 10, right: 8, top: 0, bottom: 0)
        : const EdgeInsets.only(left: 20, right: 14, top: 10, bottom: 10);

    // ── Ancho derecho SIEMPRE fijo (máximo posible) ──────────────────────────
    // Reserva espacio para: BR(30) + gap(4) + gap(5) + addBtn(26) + gap(5) + delBtn(26) + gap(2)
    // Aunque BR o addBtn no se muestren, el espacio reservado es el mismo
    // → las bolas siempre tienen el mismo tamaño.
    final double rightFixedW = isMobile
        ? 4 + 30 + 5 + btnSize + 5 + btnSize + 2   // 4+30+5+26+5+26+2 = 98px fijo
        : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ancho total disponible dentro del contenedor (descontando padding)
        final double totalW   = constraints.maxWidth - pad.left - pad.right;

        // Ancho del label "LÍNEA X" (aprox)
        final double labelW   = isMobile ? 60.0 : 80.0;
        final double gapLabel = 8.0;

        // Espacio libre para los círculos
        final double circlesW = totalW - labelW - gapLabel - rightFixedW;

        // Número de círculos = balotas + superbalota (si existe)
        final int nCircles    = balotas.length + (superbalota != null ? 1 : 0);
        const double gap      = 4.0;

        // Tamaño de cada círculo: llena el espacio, máx 30px en móvil / 30px desktop
        final double maxSz    = isMobile ? 30.0 : 30.0;
        final double calcSz   = nCircles > 0
            ? (circlesW - gap * (nCircles - 1)) / nCircles
            : maxSz;
        final double numSz    = calcSz.clamp(14.0, maxSz);
        final double fontSz   = (numSz * 0.42).clamp(8.0, 14.0);

        return Container(
          width: double.infinity,
          height: containerH,
          padding: pad,
          decoration: BoxDecoration(
            color: const Color(0xFFEBEBEB),
            borderRadius: BorderRadius.circular(80),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Label "LÍNEA X"
              Text(
                'LÍNEA $numero',
                style: GoogleFonts.inter(
                    fontSize: labelFontSz,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577)),
              ),
              SizedBox(width: gapLabel),
              // Círculos — tamaño calculado, sin scroll
              ...balotas.map((n) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _NumCircle(numero: n, isSuper: false,
                        size: numSz, fontSize: fontSz),
                  )),
              if (superbalota != null) ...[
                const SizedBox(width: 4),
                _NumCircle(numero: superbalota, isSuper: true,
                    size: numSz, fontSize: fontSz),
              ],
              const Spacer(),
              // Badge BR
              if (_conRevancha) ...[
                const SizedBox(width: 4),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 5 : 8,
                    vertical: isMobile ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF81515),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'BR',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 10 : 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 5),
              // Botón agregar
              if (isEditing && onAdd != null) ...[
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: btnSize,
                    height: btnSize,
                    decoration: const BoxDecoration(
                        color: Color(0xFF112044), shape: BoxShape.circle),
                    child: Icon(Icons.add, color: Colors.white, size: iconSz),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              // Botón eliminar
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: btnSize,
                  height: btnSize,
                  decoration: const BoxDecoration(
                      color: Color(0xFF112044), shape: BoxShape.circle),
                  child: Icon(Icons.delete_outline,
                      color: Colors.white, size: iconSz),
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),       // Row
        );         // Container
      },           // builder
    );             // LayoutBuilder
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
            onPressed: () => _irAlCarrito(),
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

  Widget _buildApuestasAvanzadasCard({bool showCta = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
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
            '¡Adelanta tus apuestas hasta en 9 sorteos y ahorra tiempo!',
            style: GoogleFonts.inter(
                fontSize: 14, color: const Color(0xFF0D2677)),
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
            'Total apuestas',
            _fmtCop(_kPrecioBaloto * _cantidadSorteos),
            bg: const Color(0xFFF0F0F0),
          ),
          const SizedBox(height: 4),
          _buildResumenRow(
            'Total a pagar',
            _fmtCop(_totalPagar),
            bg: const Color(0xFFF7F7F7),
            isBold: true,
          ),
          if (_conRevancha) ...[
            const SizedBox(height: 4),
            _buildResumenRow(
              'Total apuestas',
              _fmtCop((_kPrecioBaloto + _kPrecioRevancha) * _cantidadSorteos),
              bg: const Color(0xFFF0F0F0),
            ),
          ],
          if (showCta) ...[
            const SizedBox(height: 24),
            const _Divisor(),
            const SizedBox(height: 16),
            _buildBotonesDesktop(),
          ],
        ],
      ),
    );
  }

  Widget _buildSorteosDropdown() {
    final label = _sorteosSeleccionados.isEmpty
        ? 'Jugada única'
        : '$_cantidadSorteos sorteo${_cantidadSorteos > 1 ? "s" : ""}';
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF0C2577)),
      ),
      child: PopupMenuButton<int>(
        onSelected: (v) => setState(() {
          _sorteosSeleccionados.clear();
          if (v > 1) {
            for (int i = 0; i < v && i < _sorteosDisponibles.length; i++) {
              _sorteosSeleccionados.add(i);
            }
          }
        }),
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 16, color: const Color(0xFF0C2577))),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF0C2577), size: 20),
          ],
        ),
        itemBuilder: (_) => [
          for (int i = 1;
              i <= _kMaxSorteosVenta && i <= _sorteosDisponibles.length;
              i++)
            PopupMenuItem(
              value: i,
              child: Text(
                i == 1 ? 'Jugada única' : '$i sorteos',
                style: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF0C2577)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBotonesDesktop() {
    return Column(
      children: [
        SizedBox(
          width: 434,
          height: 47,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43B75D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            onPressed: _irAlCarrito,
            child: Text(
              'AÑADIR AL CARRITO',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
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

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE — Tarjeta unificada (Figma node 1282:5696 · 402×1229)
  // Todo el contenido en UNA tarjeta blanca (384×1057, rounded-30, padding 20)
  // ══════════════════════════════════════════════════════════════════════════

  /// Tarjeta única que agrupa TODOS los bloques del flujo móvil:
  /// banner → toggle → números → línea → apuestas avanzadas → resumen → CTA
  Widget _buildMobileUnifiedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ① Banner Baloto Revancha (344×93)
          _buildBanner(),
          const SizedBox(height: 18),

          // ② Geo bloqueada (E6)
          if (_geoEstado == _GeoEstado.bloqueada) ...[
            _buildGeoBloqueadaBanner(),
            const SizedBox(height: 12),
          ],

          // ③ Toggle MANUAL / AUTOMÁTICO (264×27, centrado)
          _buildModoToggle(),
          const SizedBox(height: 18),

          // ④ Sección de números (layout vertical móvil)
          if (_modoAutomatico)
            _buildSeccionAutomaticaMobile()
          else
            _buildSeccionManualMobile(),

          // ⑤ "Apuestas Avanzadas" — Inter Bold 19.5px, #0C2577
          Text(
            'Apuestas Avanzadas',
            style: GoogleFonts.inter(
              fontSize: 19.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0C2577),
              height: 28 / 19.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // ⑥ Selector Revancha (compacto móvil 336px)
          _buildRevanchaMobile(),
          const SizedBox(height: 10),

          // ⑦ Descripción — Inter Regular 16px, #0D2677
          Text(
            '¡Adelanta tus apuestas hasta en 9 sorteos y ahorra tiempo!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF0D2677),
              height: 24 / 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // ⑧ Dropdown sorteos (364×48, border #0C2577, rounded-30)
          _buildSorteosDropdown(),
          const SizedBox(height: 20),

          // ⑨ "Resumen de la apuesta" — Inter SemiBold 19.5px
          SizedBox(
            width: double.infinity,
            child: Text(
              'Resumen de la apuesta',
              style: GoogleFonts.inter(
                fontSize: 19.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0C2577),
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),

          // ⑩ Filas de resumen (362×35 c/u, rounded-30)
          _buildResumenRow(
            'Total apuestas',
            _fmtCop(_kPrecioBaloto * _cantidadSorteos),
            bg: const Color(0xFFF0F0F0),
          ),
          const SizedBox(height: 4),
          _buildResumenRow(
            'Total a pagar',
            _fmtCop(_totalPagar),
            bg: const Color(0xFFF7F7F7),
            isBold: true,
          ),
          const SizedBox(height: 20),

          // ⑪ CTA "AÑADIR AL CARRITO" (209×41, #43B75D, rounded-26)
          SizedBox(
            width: 209,
            height: 41,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43B75D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
                padding: EdgeInsets.zero,
              ),
              onPressed: _irAlCarrito,
              child: Text(
                'AÑADIR AL CARRITO',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 24 / 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Cancelar
          TextButton(
            onPressed: () => _cancelar(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sección manual móvil — números en vertical (Figma node 1282:5699) ────
  // Layout: título → grid 43 balotas (24px) → título → grid 16 superbalota → LÍNEA

  Widget _buildSeccionManualMobile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Error balotas
        if (_errorBalotas != null) ...[
          Center(child: _ErrorText(_errorBalotas!)),
          const SizedBox(height: 10),
        ],

        // "Selecciona 5 números" — Inter Bold 19.5px (Figma: h=33, centrado en 344)
        Text(
          'Selecciona 5 números',
          style: GoogleFonts.inter(
            fontSize: 19.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0C2577),
            height: 28 / 19.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Grid balotas 1-43 (10 cols, 24px, gap=9) — Figma 344×171
        Center(child: _buildBalotasGridMobile()),
        const SizedBox(height: 8),

        // "Selecciona la superbalota" — Inter Bold 19.5px
        Text(
          'Selecciona la superbalota',
          style: GoogleFonts.inter(
            fontSize: 19.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0C2577),
            height: 28 / 19.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Error superbalota
        if (_errorSuperbalota != null) ...[
          Center(child: _ErrorText(_errorSuperbalota!)),
          const SizedBox(height: 10),
        ],

        // Grid superbalota 1-16 (flex-wrap, 24px, gap-x=9 gap-y=8) — Figma 321×56
        Center(child: _buildSuperbalotaGridMobile()),
        const SizedBox(height: 12),

        // Barra LÍNEA (45px, mobile sizing)
        _buildNumerosMostradosMobile(),
        const SizedBox(height: 18),
      ],
    );
  }

  // ── Sección automática móvil ──────────────────────────────────────────────
  // Reutiliza _buildBalotera() + botones Figma (191×37 AGREGAR, 37×37 refresh)

  Widget _buildSeccionAutomaticaMobile() {
    final tieneNumeros = _balotas.isNotEmpty && _superbalota != null;
    return Column(
      children: [
        _buildBalotera(),
        const SizedBox(height: 8),
        Center(
          child: tieneNumeros
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // AGREGAR — 191×37, amarillo #FFE30C (Figma "Botonnnnn")
                    GestureDetector(
                      onTap: _agregarLinea,
                      child: Container(
                        width: 191,
                        height: 37,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE30C),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'AGREGAR',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D1B3E),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Refresh — 37×37 círculo gris (Figma "Agregar eliminar")
                    GestureDetector(
                      onTap: _generarAutomatico,
                      child: Container(
                        width: 37,
                        height: 37,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE5E7EB),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF374151),
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _generarAutomatico,
                  child: Container(
                    width: 191,
                    height: 37,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53E3E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'JUGAR',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        _buildNumerosMostradosMobile(),
        const SizedBox(height: 18),
      ],
    );
  }

  // ── Grid balotas móvil — Figma: 24×24px, gap=9, 10 cols ─────────────────
  // 43 bolas, 10 por fila → 5 filas, total: 321×156px (ajusta a 344 contenedor)

  Widget _buildBalotasGridMobile() {
    const double ballSize = 24;
    const double gap = 9;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: List.generate(_kBalotaMax, (i) {
        final n = i + 1;
        return _BalotaCell(
          numero: n,
          isSelected: _balotas.contains(n),
          isSuperbalota: false,
          size: ballSize,
          onTap: () => _toggleBalota(n),
        );
      }),
    );
  }

  // ── Grid superbalota móvil — Figma: 24×24px, gap-x=9 gap-y=8, 10 cols ──
  // 16 bolas → fila1: 10, fila2: 6, total: 321×56px

  Widget _buildSuperbalotaGridMobile() {
    return Wrap(
      spacing: 9,    // column gap (Figma gap-[8px_9px] → col-gap=9)
      runSpacing: 8, // row gap (Figma gap-[8px_9px] → row-gap=8)
      children: List.generate(_kSuperbalotaMax, (i) {
        final n = i + 1;
        return _BalotaCell(
          numero: n,
          isSelected: _superbalota == n,
          isSuperbalota: true,
          size: 24,
          onTap: () => _toggleSuperbalota(n),
        );
      }),
    );
  }

  // ── Números mostrados móvil (barras LÍNEA con sizing mobile) ─────────────

  Widget _buildNumerosMostradosMobile() {
    final balotasSorted = _balotas.toList()..sort();
    final lineaNum = _lineasGuardadas.length + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._lineasGuardadas.asMap().entries.map((e) {
          final idx = e.key;
          final linea = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildLineaBar(
              numero: linea.numero,
              balotas: linea.balotas,
              superbalota: linea.superbalota,
              onDelete: () => _eliminarLinea(idx),
              isEditing: false,
              isMobile: true,
            ),
          );
        }),
        _buildLineaBar(
          numero: lineaNum,
          balotas: balotasSorted,
          superbalota: _superbalota,
          onAdd: _agregarLinea,
          onDelete: _limpiar,
          isEditing: true,
          isMobile: true,
        ),
      ],
    );
  }

  // ── Revancha móvil — Figma: 336×61, SI/NO radio compacto ─────────────────
  // Frame 2085663289: "¿Deseas Jugar con Revancha?" + marcadores SI/NO

  Widget _buildRevanchaMobile() {
    return SizedBox(
      width: 336,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "¿Deseas Jugar con Revancha?" — Inter Medium 15px, #0D2677
          Text(
            '¿Deseas Jugar con Revancha?',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF0D2677),
              height: 24 / 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }
} // end _BalotoRevanchaScreenState

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
            fontSize: size * 0.57,
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
    this.fontSize,
  });
  final int    numero;
  final bool   isSuper;
  final double size;
  final double? fontSize; // si null, se calcula desde size

  @override
  Widget build(BuildContext context) {
    final double fs = fontSize ?? (size * 0.38);
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
          fontSize: fs,
          fontWeight: FontWeight.w800,
          color: isSuper ? Colors.white : const Color(0xFF0C2577),
          height: 1.0,
        ),
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
                color: const Color(0xFFFECA0C),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cancel_outlined,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFDC2626),
                height: 1.4,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
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

class _LineaData {
  const _LineaData({
    required this.numero,
    required this.balotas,
    required this.superbalota,
  });
  final int numero;
  final List<int> balotas;
  final int superbalota;
}

class _BalotaCircle extends StatelessWidget {
  const _BalotaCircle({
    required this.numero,
    required this.isSuper,
    this.detenida = true,
    this.size = 36,
    this.fontSize = 12,
  });
  final int numero;
  final bool isSuper;
  final bool detenida;
  final double size;
  final double fontSize; // false = girando (gris), true = detenida (color final)

  @override
  Widget build(BuildContext context) {
    final tieneNumero = numero != 0;

    // Colores según estado — extraídos del Figma node 1284-9405
    final Color bgColor;
    final Color textColor;

    if (!tieneNumero || !detenida) {
      // Vacío o girando: gris con texto oscuro
      bgColor = const Color(0xFFB5B5B5);
      textColor = const Color(0xFF4B5563);
    } else if (isSuper) {
      // Superbalota detenida: rojo con texto blanco
      bgColor = const Color(0xFFD6002C);
      textColor = Colors.white;
    } else {
      // Balota detenida: amarillo con texto azul oscuro
      bgColor = const Color(0xFFFFE30C);
      textColor = const Color(0xFF071647);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      alignment: Alignment.center,
      child: Text(
        numero == 0 ? '00' : numero.toString().padLeft(2, '0'),
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1,
        ),
      ),
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

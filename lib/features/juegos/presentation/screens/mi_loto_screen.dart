// HU-ML001 – Mi Loto
// Producto: Mi Loto (by Baloto)
// Módulo: GANE Web / Aplicación Responsive
// Versión: 1.1.0 – 10/06/2026
//
// Figma: plataforma-Gane-Web · node 1057-9804
// Página principal Manual: 728:789
// Página Automática:       827:1464 / 834:2871 / 834:5070
// Carrito / Cuenta:        813:1343
//
// Reglas de negocio:
//   • Seleccionar exactamente 5 números del 1 al 39
//   • Precio por línea: $4.000
//   • Sorteos disponibles: 1–9
//   • Días de sorteo: lunes (1), martes (2), jueves (4), viernes (5)
//   • Modalidad: Manual (grid 39 nums) | Automática (balotera animada)
//   • Acumulado arranca en $120.000.000 y crece sin ganador de 5 aciertos

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
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../carrito/presentation/screens/carrito_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';

// ── Constantes de negocio HU-ML001 ───────────────────────────────────────────

const int _kPrecioMiLoto      = 4000;
const int _kNumerosRequeridos = 5;
const int _kNumeroMin         = 1;
const int _kNumeroMax         = 39;
const int _kMaxSorteos        = 9;

// Días de sorteo ISO weekday: 1=lun, 2=mar, 4=jue, 5=vie
const List<int> _kDiasSorteo = [1, 2, 4, 5];

// Plan de premios HU-ML001 (porcentajes exactos pendientes de ops — RN7)
const _kPlanPremios = <({String aciertos, String descripcion, String premio})>[
  (aciertos: '5', descripcion: '5 aciertos',  premio: 'Acumulado'),
  (aciertos: '4', descripcion: '4 aciertos',  premio: 'Variable'),
  (aciertos: '3', descripcion: '3 aciertos',  premio: 'Variable'),
  (aciertos: '2', descripcion: '2 aciertos',  premio: 'Variable'),
];

// ── Tokens de color Mi Loto (Figma) ──────────────────────────────────────────

// Figma tokens: nodo 1057-9804
const Color _kMiLotoBlue    = Color(0xFF4A9FDC);
const Color _kMiLotoNavy    = Color(0xFF0C2577);
const Color _kMiLotoMidBlue = Color(0xFF2C5F84);
const Color _kTotalRowGray  = Color(0xFFF0F0F0);
const Color _kTotalRowLight = Color(0xFFF7F7F7);
const Color _kGreen500      = Color(0xFF43B75D);
const Color _kSubtitleBlue  = Color(0xFF0D2677);

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtCop(int amount) {
  if (amount == 0) return '\$0';
  final s = amount.toString();
  final buf = StringBuffer('\$');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${buf.toString()},00';
}

// ── Modelo de línea ───────────────────────────────────────────────────────────

class _LineaMiLoto {
  final List<int> numeros;
  const _LineaMiLoto(this.numeros);
}

// ── Modo de juego ─────────────────────────────────────────────────────────────

enum _GameMode { manual, automatico }

// ── Modal de login (shared pattern) ──────────────────────────────────────────

void _showLoginModal(BuildContext ctx) {
  if (MediaQuery.sizeOf(ctx).width < 600) {
    LoginRedirectService.save(AppRoutes.miLoto);
    ctx.push(AppRoutes.login);
    return;
  }
  showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: LoginFormWidget(
          onClose: () => Navigator.pop(dialogCtx),
          onLoginSuccess: () => Navigator.pop(dialogCtx),
          onRegisterRequested: () => Navigator.pop(dialogCtx),
          onRecoveryRequested: (identifier) {
            Navigator.pop(dialogCtx);
            dialogCtx.push(
              AppRoutes.otpVerification,
              extra: {'destination': identifier, 'flow': OtpFlow.passwordRecovery},
            );
          },
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Screen
// ══════════════════════════════════════════════════════════════════════════════

class MiLotoScreen extends StatefulWidget {
  const MiLotoScreen({super.key});

  @override
  State<MiLotoScreen> createState() => _MiLotoScreenState();
}

class _MiLotoScreenState extends State<MiLotoScreen> {

  // ── Estado del juego ─────────────────────────────────────────────────────
  _GameMode              _mode          = _GameMode.manual;
  final List<int>        _seleccionados = [];
  final List<_LineaMiLoto> _lineas      = [];
  String?                _errorMsg;
  int                    _sorteos       = 1;

  // ── Balotera animada ─────────────────────────────────────────────────────
  bool         _animandoBalotera = false;
  List<int>    _numerosVisibles  = List.filled(_kNumerosRequeridos, 0);
  List<bool>   _balotasDetenidas = List.filled(_kNumerosRequeridos, false);
  Timer?       _timerRuleta;
  List<int>?   _autoPreview;      // números finales generados, antes de confirmar

  // ── Sorteos dropdown overlay ─────────────────────────────────────────────
  OverlayEntry? _dropdownEntry;
  final LayerLink _dropdownLink = LayerLink();

  // ── Computed ─────────────────────────────────────────────────────────────
  bool get _seleccionCompleta => _seleccionados.length == _kNumerosRequeridos;
  int  get _totalApuestas     => _lineas.length * _kPrecioMiLoto * _sorteos;
  bool get _noSorteoHoy       => !_kDiasSorteo.contains(DateTime.now().weekday);

  // ── Helpers navbar ───────────────────────────────────────────────────────
  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timerRuleta?.cancel();
    _closeDropdown();
    super.dispose();
  }

  // ── Lógica de negocio ─────────────────────────────────────────────────────

  void _toggleNumero(int n) {
    setState(() {
      _errorMsg = null;
      if (_seleccionados.contains(n)) {
        _seleccionados.remove(n);
      } else {
        if (_seleccionados.length >= _kNumerosRequeridos) {
          _errorMsg = 'Solo puedes seleccionar $_kNumerosRequeridos números.';
          return;
        }
        _seleccionados.add(n);
      }
    });
  }

  void _generarAutomatico() {
    _timerRuleta?.cancel();
    final rng = math.Random();
    final finales = <int>[];
    while (finales.length < _kNumerosRequeridos) {
      final n = rng.nextInt(_kNumeroMax) + _kNumeroMin;
      if (!finales.contains(n)) finales.add(n);
    }

    setState(() {
      _animandoBalotera = true;
      _numerosVisibles  = List.filled(_kNumerosRequeridos, 1);
      _balotasDetenidas = List.filled(_kNumerosRequeridos, false);
      _autoPreview      = null;
      _errorMsg         = null;
    });

    _timerRuleta = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        for (int i = 0; i < _kNumerosRequeridos; i++) {
          if (!_balotasDetenidas[i]) {
            _numerosVisibles[i] = rng.nextInt(_kNumeroMax) + _kNumeroMin;
          }
        }
      });
    });

    for (int i = 0; i < _kNumerosRequeridos; i++) {
      final idx = i;
      Future.delayed(Duration(milliseconds: 500 + idx * 220), () {
        if (!mounted) return;
        setState(() {
          _balotasDetenidas[idx] = true;
          _numerosVisibles[idx]  = finales[idx];
        });
        if (idx == _kNumerosRequeridos - 1) {
          _timerRuleta?.cancel();
          setState(() {
            _animandoBalotera = false;
            _autoPreview      = List.from(finales)..sort();
          });
        }
      });
    }
  }

  void _agregarAutoPreview() {
    if (_autoPreview == null) return;
    setState(() {
      _lineas.add(_LineaMiLoto(List.from(_autoPreview!)));
      _autoPreview = null;
    });
  }

  void _agregarLineaManual() {
    if (!_seleccionCompleta) {
      setState(() => _errorMsg =
          'Selecciona exactamente $_kNumerosRequeridos números para agregar la línea.');
      return;
    }
    setState(() {
      _lineas.add(_LineaMiLoto(List.from(_seleccionados)..sort()));
      _seleccionados.clear();
      _errorMsg = null;
    });
  }

  void _eliminarLinea(int idx) => setState(() => _lineas.removeAt(idx));

  void _addToCart(BuildContext ctx) {
    if (_lineas.isEmpty) {
      setState(() => _errorMsg = 'Agrega al menos una línea antes de continuar.');
      return;
    }
    final items = _lineas
        .map((l) => CarritoItem(
              balotas: l.numeros,
              superbalota: 0,
              conRevancha: false,
              cantidadSorteos: _sorteos,
              precioTotal: _kPrecioMiLoto * _sorteos,
              gameTipo: 'miloto',
            ))
        .toList();
    ctx.push(AppRoutes.carrito, extra: items);
  }

  // ── Sorteos dropdown ──────────────────────────────────────────────────────

  void _openDropdown(BuildContext ctx) {
    if (_dropdownEntry != null) { _closeDropdown(); return; }
    final renderBox = ctx.findRenderObject() as RenderBox?;
    final width = renderBox?.size.width ?? 624.0;
    _dropdownEntry = OverlayEntry(
      builder: (_) => _SorteosDropdown(
        layerLink: _dropdownLink,
        width: width,
        selected: _sorteos,
        onSelect: (v) { setState(() => _sorteos = v); _closeDropdown(); },
        onDismiss: _closeDropdown,
      ),
    );
    Overlay.of(ctx).insert(_dropdownEntry!);
    setState(() {});
  }

  void _closeDropdown() {
    _dropdownEntry?.remove();
    _dropdownEntry = null;
    if (mounted) setState(() {});
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (prev, curr) =>
          (prev.user == null) != (curr.user == null) ||
          prev.status != curr.status,
      builder: (context, authState) {
        final bool loggedIn =
            authState.user != null ||
            authState.status == AuthStatus.success ||
            authState.status == AuthStatus.registrationSuccess;

        final double sw      = MediaQuery.sizeOf(context).width;
        final bool   isMobile = sw < 720;
        final double navH    = _navH(sw, loggedIn);

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: navH),
                    if (loggedIn)
                      isMobile
                          ? _buildMobile(context)
                          : _buildDesktop(context)
                    else
                      _buildAuthRequired(context, isMobile),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: NavbarWidget(
                  isLoggedIn: loggedIn,
                  activeNavItem: 'Juegos',
                  onInicioTap: () => context.go(AppRoutes.home),
                  onJuegosTap: () => context.go(AppRoutes.juegos),
                  onResultadosTap: () => context.go(AppRoutes.resultados),
                  onLoginTap: loggedIn ? null : () => _showLoginModal(context),
                  onRegisterTap: loggedIn ? null : () => _showLoginModal(context),
                  onWalletTap: loggedIn ? () {} : null,
                  onCartTap: loggedIn
                      ? () => context.push(AppRoutes.carrito, extra: <CarritoItem>[])
                      : null,
                  onAvatarTap: loggedIn ? () {} : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUT DESKTOP — dos columnas (885 + 664px Figma)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktop(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 65, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1617),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 885, child: _buildCardPrincipal(context)),
                const SizedBox(width: 40),
                Expanded(
                  flex: 664,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 54),
                    child: _buildCardAvanzadas(context, showCta: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYOUT MÓVIL — tarjeta unificada
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 0, 9, 16),
      child: Column(
        children: [
          _buildCardPrincipal(context),
          const SizedBox(height: 12),
          _buildCardAvanzadas(context, showCta: true),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARD PRINCIPAL (panel izquierdo en desktop / primer card en móvil)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCardPrincipal(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          // Aviso no sorteo hoy (E6/A4 HU-ML001)
          if (_noSorteoHoy) ...[
            _buildNoSorteoHoyBanner(),
            const SizedBox(height: 12),
          ],
          Text(
            'Selecciona $_kNumerosRequeridos números',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _kMiLotoNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          _buildModeToggle(),
          const SizedBox(height: 16),
          if (_mode == _GameMode.manual)
            _buildSeccionManual()
          else
            _buildSeccionAutomatica(context),
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            _MiLotoError(_errorMsg!),
          ],
          const SizedBox(height: 12),
          _buildLineasSection(),
          const SizedBox(height: 16),
          _buildPlanPremios(),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.bannerMiLoto,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C2577), Color(0xFF4A9FDC)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'MI LOTO',
              style: GoogleFonts.inter(
                fontSize: 32, fontWeight: FontWeight.w900,
                color: Colors.white, letterSpacing: 4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Info del juego ────────────────────────────────────────────────────────

  // ── Banner no hay sorteo hoy (A4/E6) ─────────────────────────────────────

  Widget _buildNoSorteoHoyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFBBF24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Hoy no hay sorteo. Tu apuesta participará en el próximo sorteo disponible (Lun · Mar · Jue · Vie).',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF92400E), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toggle Manual / Automático ────────────────────────────────────────────
  // Figma: toggle bg OFF=#e5e7ea · ON=#2c2e6f (primary700), w=44 h=24
  // Texto: Inter SemiBold 16px #0c2577

  Widget _buildModeToggle() {
    final bool isAuto = _mode == _GameMode.automatico;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _mode = _GameMode.manual;
            _autoPreview = null;
            _errorMsg = null;
          }),
          child: Text('MANUAL',
            style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: _kMiLotoNavy,
            )),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() {
            _mode = isAuto ? _GameMode.manual : _GameMode.automatico;
            _autoPreview = null;
            _seleccionados.clear();
            _errorMsg = null;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 24,
            decoration: BoxDecoration(
              color: isAuto ? AppColors.primary700 : const Color(0xFFE5E7EA),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: isAuto ? Alignment.centerRight : Alignment.centerLeft,
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() {
            _mode = _GameMode.automatico;
            _seleccionados.clear();
            _errorMsg = null;
          }),
          child: Text('AUTOMÁTICO',
            style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600, color: _kMiLotoNavy,
            )),
        ),
      ],
    );
  }

  // ── Sección manual — grid 1-39 ────────────────────────────────────────────
  // Figma: grid 19 cols × 2 filas + 1 (39 total), gap 13×13px

  Widget _buildSeccionManual() {
    return Wrap(
      spacing: 13,
      runSpacing: 13,
      children: List.generate(_kNumeroMax, (i) {
        final n = i + 1;
        return _NumChip(
          numero: n,
          selected: _seleccionados.contains(n),
          onTap: () => _toggleNumero(n),
        );
      }),
    );
  }

  // ── Sección automática — balotera animada ─────────────────────────────────

  Widget _buildSeccionAutomatica(BuildContext context) {
    return Column(
      children: [
        _buildBalotera(),
        const SizedBox(height: 16),
        _buildBotonesAuto(context),
      ],
    );
  }

  // ── Balotera animada ──────────────────────────────────────────────────────

  Widget _buildBalotera() {
    List<int> displayNums;
    List<bool> detenidas;

    if (_animandoBalotera) {
      displayNums = _numerosVisibles;
      detenidas   = _balotasDetenidas;
    } else if (_autoPreview != null) {
      displayNums = _autoPreview!;
      detenidas   = List.filled(_kNumerosRequeridos, true);
    } else {
      displayNums = List.filled(_kNumerosRequeridos, 0);
      detenidas   = List.filled(_kNumerosRequeridos, false);
    }

    return GestureDetector(
      onTap: _animandoBalotera ? null : _generarAutomatico,
      child: MouseRegion(
        cursor: _animandoBalotera
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: LayoutBuilder(
          builder: (context, outer) {
            final tubeW = outer.maxWidth.clamp(200.0, 700.0);
            final tubeH = tubeW * (190 / 408);
            final innerW = tubeW * 0.58;
            const nBalls = _kNumerosRequeridos;
            const nGaps  = nBalls - 1;
            final gap    = tubeW * 0.012;
            final byW    = (innerW - nGaps * gap) / nBalls;
            final byH    = tubeH * 0.82;
            final ballSz = math.min(byW, byH).clamp(14.0, 72.0);
            final fontSz = (ballSz * 0.40).clamp(8.0, 24.0);
            final rowW   = ballSz * nBalls + nGaps * gap;

            return SizedBox(
              width: tubeW,
              height: tubeH,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      AppAssets.baloteraTube,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0C2577), Color(0xFF1372AE)],
                          ),
                          borderRadius: BorderRadius.circular(tubeH / 2),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: rowW,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_kNumerosRequeridos, (i) =>
                        _BalotaCircle(
                          numero: displayNums[i],
                          detenida: detenidas[i],
                          size: ballSz,
                          fontSize: fontSz,
                        ),
                      ),
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

  // Botones cuando hay preview / cuando está vacío
  Widget _buildBotonesAuto(BuildContext context) {
    if (_animandoBalotera) {
      return const SizedBox(height: 48);
    }

    if (_autoPreview == null) {
      return Center(
        child: GestureDetector(
          onTap: _generarAutomatico,
          // Figma Botonnn: bg=#ee443f (red), texto=#ffe200 (amarillo), w=190 h=46, rounded-30
          child: Container(
            width: 190, height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEE443F),
              borderRadius: BorderRadius.circular(30),
            ),
            alignment: Alignment.center,
            child: Text('JUGAR',
              style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: const Color(0xFFFFE200),
              )),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _agregarAutoPreview,
          child: Container(
            width: 194, height: 46,
            decoration: BoxDecoration(
              color: _kGreen500,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: Text('AGREGAR',
              style: GoogleFonts.inter(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
              )),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _generarAutomatico,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: _kMiLotoMidBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  // ── Sección de líneas confirmadas ─────────────────────────────────────────

  Widget _buildLineasSection() {
    if (_lineas.isEmpty) {
      // Línea 1 vacía o en construcción
      return _LineaBar(
        index: 0,
        numeros: _mode == _GameMode.manual ? _seleccionados : const [],
        onEliminar: null,
        onAgregarNuevaLinea: _mode == _GameMode.manual && _seleccionCompleta
            ? _agregarLineaManual
            : null,
      );
    }

    return Column(
      children: [
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 8),
        ..._lineas.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _LineaBar(
            index: e.key,
            numeros: e.value.numeros,
            onEliminar: () => _eliminarLinea(e.key),
            onAgregarNuevaLinea:
                _mode == _GameMode.manual && e.key == _lineas.length - 1
                    ? _agregarLineaManual
                    : null,
          ),
        )),
      ],
    );
  }

  // ── Botones Limpiar / Agregar línea / Cancelar ────────────────────────────

  // ── Plan de premios ───────────────────────────────────────────────────────

  Widget _buildPlanPremios() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _kMiLotoNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const ['Aciertos', 'Premio'].map((h) =>
                Expanded(
                  child: Text(
                    h,
                    style: TextStyle(
                      fontFamily: 'Inter', fontSize: 13,
                      fontWeight: FontWeight.w600, color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ).toList(),
            ),
          ),
          ..._kPlanPremios.asMap().entries.map((e) {
            final p  = e.value;
            final bg = e.key.isEven ? const Color(0xFFF8FAFF) : Colors.white;
            return Container(
              color: bg,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _kMiLotoBlue,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(p.aciertos,
                            style: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                            )),
                        ),
                        const SizedBox(width: 8),
                        Text(p.descripcion,
                          style: GoogleFonts.inter(fontSize: 13, color: _kMiLotoNavy)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(p.premio,
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: _kMiLotoNavy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F4FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Text(
              'Los premios por 4, 3 y 2 aciertos corresponden a un porcentaje de la venta del sorteo, dividido entre los ganadores de cada categoría.',
              style: GoogleFonts.inter(
                fontSize: 11, color: const Color(0xFF6B7280), height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CARD APUESTAS AVANZADAS (panel derecho en desktop / segundo card en móvil)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCardAvanzadas(BuildContext context, {required bool showCta}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Apuestas Avanzadas',
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700, color: _kMiLotoNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '¡Adelanta tus apuestas hasta en $_kMaxSorteos sorteos y ahorra tiempo!',
              style: GoogleFonts.inter(fontSize: 14, color: _kSubtitleBlue),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // Dropdown sorteos
          _buildSorteosDropdown(context),
          const SizedBox(height: 16),
          // Resumen
          Text('Resumen de la apuesta',
            style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w600, color: _kMiLotoNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          _buildResumenRow(
            label: 'Total apuestas',
            value: _lineas.isEmpty ? '' : _fmtCop(_lineas.length * _kPrecioMiLoto * _sorteos),
            bg: _kTotalRowGray,
          ),
          const SizedBox(height: 4),
          _buildResumenRow(
            label: 'Total a pagar',
            value: _lineas.isEmpty ? '' : _fmtCop(_totalApuestas),
            bg: _kTotalRowLight,
            bold: true,
          ),
          if (showCta) ...[
            const SizedBox(height: 20),
            _buildAddToCartBtn(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSorteosDropdown(BuildContext context) {
    final isOpen = _dropdownEntry != null;
    final label = _sorteos == 1 ? 'Jugada única' : '$_sorteos sorteos';
    return CompositedTransformTarget(
      link: _dropdownLink,
      child: GestureDetector(
        onTap: () => _openDropdown(context),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _kMiLotoNavy),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                style: GoogleFonts.inter(fontSize: 16, color: _kMiLotoNavy)),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: _kMiLotoNavy, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumenRow({
    required String label,
    required String value,
    required Color bg,
    bool bold = false,
  }) {
    return Container(
      height: 35,
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: GoogleFonts.inter(fontSize: 15, color: _kMiLotoNavy)),
          if (value.isNotEmpty)
            Text(value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: _kMiLotoNavy,
              )),
        ],
      ),
    );
  }

  Widget _buildAddToCartBtn(BuildContext context) {
    final enabled = _lineas.isNotEmpty;
    return Center(
      child: GestureDetector(
        onTap: enabled ? () => _addToCart(context) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 434, height: 47,
          decoration: BoxDecoration(
            color: enabled ? _kGreen500 : const Color(0xFFD7D7D7),
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text('AÑADIR AL CARRITO',
            style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white,
            )),
        ),
      ),
    );
  }

  // ── Auth required ─────────────────────────────────────────────────────────

  Widget _buildAuthRequired(BuildContext context, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  AppAssets.juegoMiloto,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.casino_outlined, size: 80, color: _kMiLotoNavy,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Inicia sesión para jugar Mi Loto',
                style: GoogleFonts.inter(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _kMiLotoNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Selecciona 5 números del 1 al 39 y gana el acumulado desde \$120.000.000.',
                style: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFF4B5563), height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kMiLotoBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => _showLoginModal(context),
                  child: Text('Iniciar sesión',
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white,
                    )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BalotaCircle — bola en la balotera animada
// ══════════════════════════════════════════════════════════════════════════════

class _BalotaCircle extends StatelessWidget {
  const _BalotaCircle({
    required this.numero,
    required this.detenida,
    required this.size,
    required this.fontSize,
  });
  final int    numero;
  final bool   detenida;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final bool vacia = numero == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: vacia
            ? const Color(0xFFD1D5DB)
            : (detenida ? const Color(0xFF4A9FDC) : const Color(0xFF2C5F84)),
        boxShadow: detenida && !vacia
            ? [BoxShadow(
                color: const Color(0xFF4A9FDC).withValues(alpha: 0.4),
                blurRadius: 8, offset: const Offset(0, 3))]
            : null,
      ),
      alignment: Alignment.center,
      child: vacia
          ? null
          : Text(
              numero.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.0,
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _NumChip — chip del grid 1-39
// Figma node 728:948: 32×31px, px=7 py=9, rounded-100px
//   Unselected: bg #D1D5DB, text #111827, Inter SemiBold 16px leading-18
//   Selected:   bg #4A9FDC, text white
// ══════════════════════════════════════════════════════════════════════════════

class _NumChip extends StatelessWidget {
  const _NumChip({
    required this.numero,
    required this.selected,
    required this.onTap,
  });
  final int          numero;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32, height: 31,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4A9FDC) : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: Text(
          numero.toString().padLeft(2, '0'),
          style: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w600, height: 18 / 16,
            color: selected ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _LineaBar — barra de línea confirmada o en construcción
// Figma node 765:1503 / 834:2806: bg #E3E9EE, h=68px (sin nums) / h=110px (con nums)
//   rounded-[30px] / rounded-[80px]
//   "LÍNEA N" Inter Bold 22px #0C2577 (Figma: leading-28)
//   "MI"      Inter Bold 22px #4AA1DF
//   Chips 32×31px azul #4A9FDC
//   Botón + (Agregar): #2C5F84 size=40 rounded-100
//   Botón trash: #2C5F84 size=40 rounded-20
// ══════════════════════════════════════════════════════════════════════════════

class _LineaBar extends StatelessWidget {
  const _LineaBar({
    required this.index,
    required this.numeros,
    required this.onEliminar,
    this.onAgregarNuevaLinea,
  });

  final int             index;
  final List<int>       numeros;
  final VoidCallback?   onEliminar;
  final VoidCallback?   onAgregarNuevaLinea;

  @override
  Widget build(BuildContext context) {
    final bool completa = numeros.length == _kNumerosRequeridos;

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFFE3E9EE),
        borderRadius: BorderRadius.circular(80),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text('LÍNEA ${index + 1}',
            style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w700,
              height: 28 / 22, color: const Color(0xFF0C2577),
            )),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: numeros.map((n) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 32, height: 31,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A9FDC),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: Text(n.toString().padLeft(2, '0'),
                      style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Colors.white, height: 1.0,
                      )),
                  ),
                )).toList(),
              ),
            ),
          ),
          // Label "MI" — Figma: Inter Bold 22px #4aa1df
          if (completa) ...[
            Text('MI',
              style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700,
                height: 28 / 22, color: const Color(0xFF4AA1DF),
              )),
            const SizedBox(width: 6),
          ],
          // Botón + (agregar nueva línea)
          if (completa && onAgregarNuevaLinea != null) ...[
            GestureDetector(
              onTap: onAgregarNuevaLinea,
              child: Container(
                width: 38, height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF2C5F84),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
          ],
          // Botón eliminar
          if (onEliminar != null)
            GestureDetector(
              onTap: onEliminar,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C5F84),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MiLotoError — mensaje de error inline
// ══════════════════════════════════════════════════════════════════════════════

class _MiLotoError extends StatelessWidget {
  const _MiLotoError(this.text);
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
          const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text,
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: const Color(0xFFDC2626), height: 1.4,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _SorteosDropdown — overlay de selección de sorteos
// ══════════════════════════════════════════════════════════════════════════════

class _SorteosDropdown extends StatelessWidget {
  const _SorteosDropdown({
    required this.layerLink,
    required this.width,
    required this.selected,
    required this.onSelect,
    required this.onDismiss,
  });

  final LayerLink         layerLink;
  final double            width;
  final int               selected;
  final ValueChanged<int> onSelect;
  final VoidCallback      onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            color: Colors.white,
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_kMaxSorteos, (i) {
                  final v     = i + 1;
                  final label = v == 1 ? 'Jugada única' : '$v sorteos';
                  final isSel = v == selected;
                  return InkWell(
                    onTap: () => onSelect(v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: isSel ? const Color(0xFFF0F4FF) : Colors.white,
                      width: double.infinity,
                      child: Text(label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          color: const Color(0xFF0C2577),
                        )),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

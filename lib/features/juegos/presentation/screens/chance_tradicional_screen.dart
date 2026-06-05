import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';

// ── Modelos ───────────────────────────────────────────────────────────────────

enum _Modalidad { unaC, dosC, tresC, cuatroC }

// Figma: columna intermedia de la sección 2 — radio "Directo" / "Combinado"
enum _ModalidadJuego { directo, combinado }

// Métodos de pago disponibles en el modal de confirmación (Figma 682:6498)
enum _MetodoPago { billetera, pse }

extension _ModalidadX on _Modalidad {
  int get digits => const [1, 2, 3, 4][index];
  // Multiplicadores HU-PD-003: 1C=5x, 2C=50x, 3C=400x, 4C=4500x
  int get multiplier => const [5, 50, 400, 4500][index];
  String get cifraTag => const ['1C', '2C', '3C', '4C'][index];
  String get label => const ['1 Cifra', '2 Cifras', '3 Cifras', '4 Cifras'][index];
}

class _BetLine {
  const _BetLine({
    required this.modalidad,
    required this.numero,
    required this.monto,
    required this.modalidadJuego,
    this.lotteryIndex, // null = sin lotería (no debería ocurrir en flujo normal)
  });
  final _Modalidad modalidad;
  final _ModalidadJuego modalidadJuego;
  final String numero;
  final int monto;
  final int? lotteryIndex; // índice en _kLoteriaData — único por línea

  // IVA = monto * 19/119 (monto incluye IVA — resolución G-000004)
  int get iva => (monto * 19 / 119).round();

  // Multiplicadores HU-CHA001: Combinado tiene plan distinto al Directo.
  // 1C/2C no tienen combinado — usan siempre el multiplicador base.
  int get _effectiveMultiplier {
    if (modalidadJuego == _ModalidadJuego.combinado) {
      if (modalidad == _Modalidad.tresC) return 83;
      if (modalidad == _Modalidad.cuatroC) return 208;
    }
    return modalidad.multiplier;
  }

  int get prize => ((monto - iva) * _effectiveMultiplier);
}

// ── Datos de loterías — orden y assets exactos de Figma ──────────────────────
// Fila 1: Risaralda, Meta, Quindío, Cauca, Medellín, Extra Medellín, Manizales
// Fila 2: Cundinamarca, Boyacá, Bogotá, Valle, Tolima, Huila, Santander

const _kLoteriaData = <({String name, String asset, String label, String shortName})>[
  (name: 'Lotería del\nRisaralda',      asset: AppAssets.logoRisaralda,           label: 'Lotería del\nRisaralda',      shortName: 'Risa'),
  (name: 'Lotería del\nMeta',           asset: AppAssets.logoLoteriaMeta,         label: 'Lotería del\nMeta',           shortName: 'Meta'),
  (name: 'Lotería del\nQuindío',        asset: AppAssets.logoLoteriaQuindio,      label: 'Lotería del\nQuindío',        shortName: 'Quin'),
  (name: 'Lotería del\nCauca',          asset: AppAssets.logoLoteriaCauca,        label: 'Lotería del\nCauca',          shortName: 'Cau'),
  (name: 'Lotería de\nMedellín',        asset: AppAssets.logoLoteriaMedellin,     label: 'Lotería de\nMedellín',        shortName: 'Med'),
  (name: 'Extra Lotería\nde Medellín',  asset: AppAssets.logoLoteriaExtraMedellin,label: 'Extra Lotería\nde Medellín',  shortName: 'ExMed'),
  (name: 'Lotería de\nManizales',       asset: AppAssets.logoLoteriaManizales,    label: 'Lotería de\nManizales',       shortName: 'Mani'),
  (name: 'Lotería de\nCundinamarca',    asset: AppAssets.logoLoteriaCundinamarca, label: 'Lotería de\nCundinamarca',    shortName: 'Cundi'),
  (name: 'Lotería de\nBoyacá',          asset: AppAssets.logoLoteriaBoyaca,       label: 'Lotería de\nBoyacá',          shortName: 'Boy'),
  (name: 'Lotería de\nBogotá',          asset: AppAssets.logoLoteriaBogota,       label: 'Lotería de\nBogotá',          shortName: 'Bog'),
  (name: 'Lotería del\nValle',          asset: AppAssets.logoValle,               label: 'Lotería del\nValle',          shortName: 'Valle'),
  (name: 'Lotería del\nTolima',         asset: AppAssets.logoLoteriaTolima,       label: 'Lotería del\nTolima',         shortName: 'Toli'),
  (name: 'Lotería del\nHuila',          asset: AppAssets.logoLoteriaHuila,        label: 'Lotería del\nHuila',          shortName: 'Hui'),
  (name: 'Lotería de\nSantander',       asset: AppAssets.logoLoteriaSantander,    label: 'Lotería de\nSantander',       shortName: 'Sant'),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class ChanceTradicionalScreen extends StatefulWidget {
  const ChanceTradicionalScreen({super.key});

  @override
  State<ChanceTradicionalScreen> createState() =>
      _ChanceTradicionalScreenState();
}

class _ChanceTradicionalScreenState extends State<ChanceTradicionalScreen> {
  late final List<DateTime> _days;
  int _selectedDay = 0;
  _Modalidad? _modalidad; // null = sin selección → muestra ?C
  // Figma sección 2 col intermedia — Directo por defecto
  _ModalidadJuego _modalidadJuego = _ModalidadJuego.directo;
  final _numeroCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  // Selección ÚNICA de lotería por línea (no Set — solo una a la vez)
  int? _selectedLoteria;
  final List<_BetLine> _lines = [];
  String? _fieldError;

  // ── Validación de número no disponible ──────────────────────────────────────
  // TODO(backend): reemplazar por llamada real al API cuando esté disponible.
  // Mock temporal: el número "111" simula un número cancelado/no disponible.
  static bool _isNumberUnavailable(String numero) => numero == '111';

  // ── Sugerencias mock ────────────────────────────────────────────────────────
  // TODO(backend): reemplazar por endpoint real cuando esté disponible.
  // Filtra automáticamente los números no disponibles del mock.
  static const _kSugerenciasMock = <int, List<String>>{
    1: ['7', '5', '6', '4', '9', '8', '3', '2', '0'],
    2: ['75', '65', '74', '59', '85', '76', '93', '13', '24', '15', '35', '25'],
    3: ['758', '658', '748', '759', '858', '769', '939', '139', '247', '158', '358', '258'],
    4: ['7582', '6582', '7482', '7592', '8582', '7692', '9392', '1392', '2472', '1582', '3582', '2582'],
  };

  List<String> _getSugerencias() {
    final digits = _modalidad?.digits ?? 3;
    final all = _kSugerenciasMock[digits] ?? [];
    // Excluir números no disponibles del mock
    return all.where((n) => !_isNumberUnavailable(n)).toList();
  }

  void _openSugerencias(BuildContext context) {
    final sugerencias = _getSugerencias();
    showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _SugerenciasModal(
        digits: _modalidad?.digits ?? 3,
        sugerencias: sugerencias,
      ),
    ).then((selected) {
      if (selected == null) return; // cerrado sin selección
      setState(() {
        _numeroCtrl.text = selected;
        _fieldError = null;
      });
    });
  }

  bool get _numeroNoDisponible =>
      _numeroCtrl.text.trim().isNotEmpty &&
      _isNumberUnavailable(_numeroCtrl.text.trim());

  // Monto ingresado pero por debajo del mínimo ($600) — activa error visual en el input
  bool get _montoInvalido =>
      _montoCtrl.text.trim().isNotEmpty && _montoValue < 600;

  @override
  void initState() {
    super.initState();
    _days = _calcDays();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  // Próximos 5 días hábiles para Chance (lunes–sábado)
  static List<DateTime> _calcDays() {
    final result = <DateTime>[];
    var d = DateTime.now();
    while (result.length < 5) {
      if (d.weekday != DateTime.sunday) result.add(d);
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  static const _dayNames = [
    '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  static const _monthNames = [
    '', 'ene', 'feb', 'mar', 'abr', 'mayo', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  void _autoNumero() {
    if (_modalidad == null) return;
    final max = math.pow(10, _modalidad!.digits).toInt() - 1;
    final rand = math.Random().nextInt(max + 1);
    _numeroCtrl.text = rand.toString().padLeft(_modalidad!.digits, '0');
    setState(() => _fieldError = null);
  }

  int get _montoValue {
    final raw = _montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  bool _validate() {
    if (_modalidad == null) {
      setState(() => _fieldError = 'Selecciona la cantidad de cifras');
      return false;
    }
    final n = _numeroCtrl.text.trim();
    if (n.isEmpty || n.length != _modalidad!.digits) {
      setState(() =>
          _fieldError = 'El número debe tener exactamente ${_modalidad!.digits} cifras',);
      return false;
    }
    if (_isNumberUnavailable(n)) {
      // El estado de error se muestra inline — no se permite agregar la línea
      return false;
    }
    if (_montoValue < 600) {
      setState(() => _fieldError = 'Apuesta mínima \$600');
      return false;
    }
    if (_selectedLoteria == null) {
      setState(() => _fieldError = 'Selecciona una lotería');
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  void _addLine() {
    if (!_validate()) return;
    setState(() {
      _lines.add(
        _BetLine(
          modalidad: _modalidad!,
          modalidadJuego: _modalidadJuego,
          numero: _numeroCtrl.text.trim(),
          monto: _montoValue,
          lotteryIndex: _selectedLoteria, // persiste la lotería en la línea
        ),
      );
      // Resetear campos de la línea actual para la siguiente
      _numeroCtrl.clear();
      _selectedLoteria = null;   // la nueva línea empieza sin lotería seleccionada
      _fieldError = null;
    });
  }

  // Agrega una línea 2C con las dos últimas cifras del número actual.
  // Requiere al menos 2 dígitos ingresados, monto ≥ $600 y lotería seleccionada.
  // No modifica el estado del formulario actual (la línea 3C/4C sigue en curso).
  void _addDosUltimasCifras() {
    final numero = _numeroCtrl.text.trim();
    if (numero.length < 2) {
      setState(
        () => _fieldError =
            'Ingresa al menos 2 dígitos para jugar las dos últimas cifras',
      );
      return;
    }
    if (_montoValue < 600) {
      setState(
        () => _fieldError =
            'Ingresa un monto válido (mínimo \$600) para jugar las dos últimas cifras',
      );
      return;
    }
    if (_selectedLoteria == null) {
      setState(
        () => _fieldError =
            'Selecciona una lotería para jugar las dos últimas cifras',
      );
      return;
    }
    final dosUltimas = numero.substring(numero.length - 2);
    setState(() {
      _lines.add(
        _BetLine(
          modalidad: _Modalidad.dosC,
          modalidadJuego: _ModalidadJuego.directo,
          numero: dosUltimas,
          monto: _montoValue,
          lotteryIndex: _selectedLoteria,
        ),
      );
      _fieldError = null;
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  void _openConfirmacion() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ConfirmacionModal(
        subtotal: _totalMonto - _totalIva,
        iva: _totalIva,
        total: _totalMonto,
      ),
    );
  }

  // Monto de la línea actual (preview) si ya es válido (≥ $600)
  int get _montoPreviewValido => _montoValue >= 600 ? _montoValue : 0;

  // IVA de la línea preview = monto * 19/119
  int get _ivaPreviewValido =>
      (_montoPreviewValido * 19 / 119).round();

  // Totales: líneas confirmadas + línea actual si su monto es válido
  int get _totalMonto => _lines.fold(0, (s, l) => s + l.monto) + _montoPreviewValido;
  int get _totalIva   => _lines.fold(0, (s, l) => s + l.iva)   + _ivaPreviewValido;

  int get _maxPrize   =>
      _lines.isEmpty ? 0 : _lines.map((l) => l.prize).reduce((a, b) => a > b ? a : b);

  // El formulario completo requiere un total mínimo de $3.000
  static const _kFormMinimo = 3000;
  bool get _formBajoMinimo =>
      (_lines.isNotEmpty || _montoPreviewValido > 0) && _totalMonto < _kFormMinimo;

  static String _fmt(int amount) {
    if (amount == 0) return '\$0';
    final s = amount.toString();
    final buf = StringBuffer('\$');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

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

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: navH),
                    if (!loggedIn)
                      _buildAuthRequired(context)
                    else
                      _buildContent(sw),
                    const SizedBox(height: 40),
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

  // ── Auth required ─────────────────────────────────────────────────────────

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
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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

  Widget _buildAuthRequired(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
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
                  AppAssets.frameChanceTradicional,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.lock_outline_rounded,
                    size: 80,
                    color: Color(0xFF2C2E6F),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicia sesión para jugar',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2E6F),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en Chance Tradicional.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
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
                    backgroundColor: const Color(0xFF1372AE),
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

  Widget _buildContent(double screenW) {
    final isDesktop = screenW >= 1024;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: _buildLeftCard(isDesktop),
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 779),
                child: _buildRightCard(),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          _buildLeftCard(isDesktop),
          const SizedBox(height: 24),
          _buildRightCard(),
        ],
      ),
    );
  }

  // ── Left card ─────────────────────────────────────────────────────────────

  Widget _buildLeftCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      // Figma left card: 779px wide, padding 20px — inner content 739px
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 16),
          _buildStep1(),
          const SizedBox(height: 16),
          _buildStep2(isDesktop),
          const SizedBox(height: 16),
          _buildStep3(),
        ],
      ),
    );
  }

  // Banner — Figma 762:3908, 746×150, border-radius 16
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.frameChanceTradicional,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D3880), Color(0xFF1E7B3B)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'ChanCe',
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Center(
      child: Text(
        'Sigue los pasos para realizar tu chance',
        // Figma: Inter Bold 22px (#2C2E6F)
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C2E6F),
          height: 28 / 22,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Paso 1 — selección de día
  // Figma: chips 122×65px, gap 13px, 5 chips en fila centrada
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '1. Escoge el día en que juega tu apuesta',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _days.length; i++) ...[
                  _DayChip(
                    day: _days[i],
                    isToday: i == 0,
                    isTomorrow: i == 1,
                    isSelected: i == _selectedDay,
                    dayNames: _dayNames,
                    monthNames: _monthNames,
                    onTap: () => setState(() => _selectedDay = i),
                  ),
                  if (i < _days.length - 1) const SizedBox(width: 13),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Paso 2 — cifras + Directo/Combinado + monto
  // Figma node I1201:9228: col izq 144px | col media 177px | col der 240px
  //
  // Regla HU: Directo/Combinado solo aplica para 3 y 4 cifras.
  // Para 1C y 2C se oculta la columna intermedia y se resetea la selección.
  Widget _buildStep2(bool isDesktop) {
    // ¿La modalidad seleccionada requiere Directo/Combinado?
    final showDirecto = _modalidad == _Modalidad.tresC ||
        _modalidad == _Modalidad.cuatroC;

    final cifrasCol = _CifrasButtons(
      selected: _modalidad,
      onSelect: (m) => setState(() {
        _modalidad = m;
        _fieldError = null;
        _numeroCtrl.clear();
        // Al cambiar a 1C o 2C, limpiar la selección de modalidad de juego
        if (m == _Modalidad.unaC || m == _Modalidad.dosC) {
          _modalidadJuego = _ModalidadJuego.directo;
        }
      }),
    );

    // Figma: Directo alinea con "2 Cifras" (fila 2 → offset 46px = 36+10)
    //        Combinado alinea con "3 Cifras" (fila 3 → offset 92px = 46+46)
    // Se logra con paddingTop = 46 en el wrapper de la columna intermedia.
    const kBtnH = 36.0;
    const kBtnGap = 10.0;
    const kDirectoTopOffset = kBtnH + kBtnGap; // 46px

    final directoCol = showDirecto
        ? Padding(
            padding: const EdgeInsets.only(top: kDirectoTopOffset),
            child: _DirectoCombinadoColumn(
              selected: _modalidadJuego,
              onSelect: (v) => setState(() => _modalidadJuego = v),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '2. Escoge la cantidad de cifras',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 12),
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cifrasCol,
                  if (directoCol != null) ...[
                    const SizedBox(width: 24),
                    directoCol,
                  ],
                  const Spacer(),
                  _buildMontoField(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cifrasCol,
                  if (directoCol != null) ...[
                    const SizedBox(height: 12),
                    directoCol,
                  ],
                  const SizedBox(height: 16),
                  _buildMontoField(),
                ],
              ),
      ],
    );
  }

  // Monto de la apuesta — Figma: 240px wide, 45px tall, radius 14, shadow
  // Error visual: borde rojo + texto rojo + mensaje "Apuesta mínima $600"
  //               cuando el monto está ingresado pero es < $600.
  Widget _buildMontoField() {
    final isError = _montoInvalido;
    final borderColor =
        isError ? const Color(0xFFEE443F) : const Color(0xFFD1D5DB);
    final textColor =
        isError ? const Color(0xFFEE443F) : const Color(0xFF4B5563);

    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Monto de la apuesta',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
              height: 28 / 22,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            width: 240,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(1, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: TextField(
              controller: _montoCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '\$0',
                hintStyle: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9CA3AF),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Mensaje de error inline — solo cuando monto ingresado < $600
          if (isError) ...[
            const SizedBox(height: 4),
            Text(
              'Apuesta mínima \$600',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFEE443F),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // Paso 3 — selección de loterías
  // Figma: 7 columnas, celdas 87×87, gap ~18px, padding 10px
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. Selecciona las loterías',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 12),
        _buildLoteriaGrid(),
      ],
    );
  }

  Widget _buildLoteriaGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        // Figma: padding 10px each side + 6 gaps of ~18px between 87px cells
        const sidePadding = 10.0;
        const gap = 18.0;
        final available = constraints.maxWidth - 2 * sidePadding;
        final cellW = (available - gap * (cols - 1)) / cols;
        // Cells are square in Figma (87×87)
        final cellH = cellW;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (int i = 0; i < _kLoteriaData.length; i++)
                SizedBox(
                  width: cellW,
                  height: cellH,
                  child: _LoteriaCell(
                    name: _kLoteriaData[i].label,
                    asset: _kLoteriaData[i].asset,
                    isSelected: _selectedLoteria == i,
                    // Selección ÚNICA: deselecciona si ya estaba, o cambia
                    onTap: () => setState(() {
                      _selectedLoteria = _selectedLoteria == i ? null : i;
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Right card ────────────────────────────────────────────────────────────

  Widget _buildRightCard() {
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
          // Título centrado — Figma: Inter Bold 22px #2C2E6F
          Center(
            child: Text(
              'Así va tu juego',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
                height: 28 / 22,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // "4. Elige tu número" — alineado izquierda dentro del card completo
          Text(
            '4. Elige tu número',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 10),

          // Botón Automático — alineado izquierda dentro del card completo
          Align(
            alignment: Alignment.centerLeft,
            child: _AutomaticoBtn(onTap: _autoNumero),
          ),
          const SizedBox(height: 12),

          // ── Bloque de número — Figma node 664:2705: 421px centrado ────────
          // Dentro de este wrapper: input, barra gris y botón "Agregar".
          // double.infinity solo es válido DENTRO de este SizedBox, no en el card.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 421),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'ingresa tu número',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildNumberInput(),
                  const SizedBox(height: 8),
                  _buildNumeroDisplay(),

                  // Link "Jugar dos últimas cifras" — solo para 3C y 4C (Figma node I664:2705;762:3854)
                  if (_modalidad == _Modalidad.tresC ||
                      _modalidad == _Modalidad.cuatroC) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: GestureDetector(
                        onTap: _addDosUltimasCifras,
                        child: Text(
                          'Jugar dos últimas cifras',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1372AE),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF1372AE),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  Center(
                    child: GestureDetector(
                      onTap: _addLine,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFECA0C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: Color(0xFF1372AE),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Agregar otra línea de apuesta',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1372AE),
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
          ),
          const SizedBox(height: 16),

          // ── Bloque inferior — Figma node 664:2707: 492px centrado ────────────
          // - Botón "Confirmar y pagar": 371px  (centrado dentro del wrapper)
          // - Bloque azul premio:        492px  (define el maxWidth del wrapper)
          // double.infinity solo es válido DENTRO de este ConstrainedBox.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 492),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_fieldError != null) ...[
                    Text(
                      _fieldError!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Text(
                    'Tu apuesta',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Líneas confirmadas (si las hay)
                  for (int i = 0; i < _lines.length; i++)
                    _buildBetLineRow(i),

                  // Fila preview — SIEMPRE visible: muestra la línea actual en construcción.
                  // Se actualiza en tiempo real con cada cambio de modalidad/número/monto/lotería.
                  _buildPreviewLineRow(),

                  const SizedBox(height: 8),

                  _buildSummaryRow('IVA', _fmt(_totalIva)),
                  _buildSummaryRow('Valor apuesta', _fmt(_totalMonto)),

                  // Mensaje: total del formulario < $3.000
                  if (_formBajoMinimo) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Recuerda que el valor mínimo del formulario es de \$3.000',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEE443F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Botón Confirmar: 371px centrado — Figma node I664:2707;638:5990
                  Center(child: _buildConfirmButton()),

                  const SizedBox(height: 20),

                  // "Podrías ganar hasta" centrado
                  Center(
                    child: Text(
                      'Podrías ganar hasta',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1372AE),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Bloque azul premio ocupa el ancho completo del wrapper (492px)
                  _buildPrizeButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput() {
    final noDisponible = _numeroNoDisponible;
    final hasOtherError = _fieldError != null;
    // Borde rojo: número no disponible O error de validación
    final isErrorState = noDisponible || hasOtherError;
    final borderColor = isErrorState
        ? const Color(0xFFEE443F) // red-500 (Figma)
        : const Color(0xFFD1D5DB);
    final textColor = noDisponible
        ? const Color(0xFFEE443F) // red-500 cuando no disponible
        : const Color(0xFF4B5563);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(1, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: TextField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _modalidad?.digits ?? 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '?',
              hintStyle: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (_) => setState(() => _fieldError = null),
          ),
        ),

        // Mensaje de número no disponible — Figma: red-300 #F4827E + link azul
        if (noDisponible) ...[
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Te invitamos a elegir otro número   ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF4827E), // red-300
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Builder(
                    builder: (ctx) => GestureDetector(
                    onTap: () => _openSugerencias(ctx),
                    child: Text(
                      'Sugerencias',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1372AE),
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFF1372AE),
                      ),
                    ),
                  ),
                ),
                  ),   // Builder
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Barra gris bajo el input — refleja el estado real de la línea actual.
  //
  // Estado 1 — sin modalidad:            ?C  $0
  // Estado 2 — modalidad, sin número:    NC  [placeholders]  $0
  // Estado 3 — modalidad + número:       NC  [círculos amarillos]  $monto
  // Estado 4 — número no disponible:     NC  [círculos rojo *]  $monto  🗑
  //
  // IMPORTANTE: cuando noDisponible es true con modalidad seleccionada,
  // la barra debe mostrar cifrasTag + asteriscos + monto real, nunca "?C $0".
  Widget _buildNumeroDisplay() {
    final hasModalidad = _modalidad != null;
    final tag          = hasModalidad ? _modalidad!.cifraTag : '?C';
    final digits       = hasModalidad ? _modalidad!.digits : 0;
    final numero       = _numeroCtrl.text.trim();
    final monto        = _montoValue;
    // noDisponible solo aplica cuando hay modalidad Y número escrito
    final noDisponible = hasModalidad && _numeroNoDisponible;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x20000000), offset: Offset(0, 2), blurRadius: 2),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            tag,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
            ),
          ),

          if (hasModalidad) ...[
            const SizedBox(width: 8),
            for (int i = 0; i < digits; i++) ...[
              if (noDisponible)
                const _ErrorCircle()
              else if (i < numero.length)
                _NumberCircle(digit: numero[i])
              else
                const _PlaceholderCircle(),
              if (i < digits - 1) const SizedBox(width: 4),
            ],
          ],

          const SizedBox(width: 10),

          Text(
            monto > 0 ? _fmt(monto) : '\$0',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: monto > 0
                  ? const Color(0xFF1372AE)
                  : const Color(0xFF9CA3AF),
            ),
          ),

          // Ícono eliminar — visible cuando hay número escrito (disponible o no)
          if (numero.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() {
                _numeroCtrl.clear();
                _fieldError = null;
              }),
              child: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Fila de preview — línea actual en construcción ────────────────────────
  //
  // Siempre visible en "Tu apuesta".  Refleja el estado en tiempo real de:
  //   _modalidad · _numeroCtrl · _selectedLoterias · _montoValue
  //
  // Cuando el usuario presiona "Agregar otra línea de apuesta", la línea se
  // consolida en _lines y la preview resetea para la siguiente línea.
  // ── Estilos compartidos para todas las filas de la tabla ──────────────────
  TextStyle get _rowBase => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      );

  // ── Fila de preview — línea actual en construcción ────────────────────────
  //
  // Siempre visible en "Tu apuesta". Refleja el estado en tiempo real de:
  //   _modalidad · _numeroCtrl · _selectedLoterias · _montoValue
  Widget _buildPreviewLineRow() {
    final lineNum  = _lines.length + 1;
    final cifraTag = _modalidad?.cifraTag ?? '?C';
    final digits   = _modalidad?.digits ?? 3; // 3 placeholders por defecto (Figma)
    final numero   = _numeroCtrl.text.trim();
    final monto    = _montoValue;

    // Dígitos ingresados + '?' por cada posición faltante
    final numDisplay = StringBuffer();
    for (int i = 0; i < digits; i++) {
      numDisplay.write(i < numero.length ? numero[i] : '?');
    }

    // Lotería seleccionada (única) o placeholder
    final loteriaShort = _selectedLoteria != null
        ? _kLoteriaData[_selectedLoteria!].shortName
        : '****';

    return _BetTableRow(
      isPreview: true,
      lineLabel: 'Línea $lineNum',
      cifraWidget: RichText(
        text: TextSpan(
          style: _rowBase,
          children: [
            TextSpan(text: '${cifraTag.toLowerCase()} '),
            TextSpan(
              text: numDisplay.toString(),
              style: const TextStyle(color: Color(0xFFFFCC00)),
            ),
          ],
        ),
      ),
      loteriaWidget: RichText(
        text: TextSpan(
          style: _rowBase,
          children: [
            const TextSpan(text: 'Lotería '),
            TextSpan(
              text: loteriaShort,
              style: const TextStyle(color: Color(0xFFFFCC00)),
            ),
          ],
        ),
      ),
      montoText: monto > 0 ? _fmt(monto) : '\$0',
      rowBase: _rowBase,
    );
  }

  // ── Fila confirmada (ya agregada a _lines) ─────────────────────────────────
  Widget _buildBetLineRow(int i) {
    final line = _lines[i];

    // Lotería propia de la línea confirmada — persiste independiente de la selección actual
    final loteriaShort = line.lotteryIndex != null
        ? _kLoteriaData[line.lotteryIndex!].shortName
        : '****';

    return _BetTableRow(
      isPreview: false,
      lineLabel: 'Línea ${i + 1}',
      cifraWidget: RichText(
        text: TextSpan(
          style: _rowBase,
          children: [
            TextSpan(text: '${line.modalidad.cifraTag.toLowerCase()} '),
            TextSpan(
              text: line.numero,
              style: const TextStyle(color: Color(0xFFFFCC00)),
            ),
          ],
        ),
      ),
      loteriaWidget: RichText(
        text: TextSpan(
          style: _rowBase,
          children: [
            const TextSpan(text: 'Lotería '),
            TextSpan(
              text: loteriaShort,
              style: const TextStyle(color: Color(0xFFFFCC00)),
            ),
          ],
        ),
      ),
      montoText: _fmt(line.monto),
      rowBase: _rowBase,
      onDelete: () => _removeLine(i),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    // Deshabilitado si: no hay líneas confirmadas O el número actual no está disponible
    // Figma node I664:2707;638:5990: w=371px, h=57px, radius=26
    // Habilitar solo si:
    //   • hay al menos una línea confirmada
    //   • la línea actual no tiene número cancelado
    //   • el monto del input actual no está bajo el mínimo por línea
    //   • el total del formulario >= $3.000
    final canConfirm = _lines.isNotEmpty &&
        !_numeroNoDisponible &&
        !_montoInvalido &&
        !_formBajoMinimo;
    return SizedBox(
      width: 371,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canConfirm ? const Color(0xFF43B75D) : const Color(0xFFBDD7EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: canConfirm ? _openConfirmacion : null,
        child: Text(
          'Confirmar y pagar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: canConfirm ? Colors.white : const Color(0xFF6B99B9),
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeButton() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1450EF),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        _maxPrize == 0 ? '\$ 0' : _fmt(_maxPrize),
        style: GoogleFonts.inter(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFE30C),
          shadows: const [
            Shadow(color: Color(0xFFCEFFD8), blurRadius: 4),
            Shadow(
              color: Color(0xFFFFCC00),
              offset: Offset(0, -3),
              blurRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de sugerencias ──────────────────────────────────────────────────────
//
// Figma node 1244:38577 — popup compacto centrado, máx 380px de ancho.
// Retorna un String (número seleccionado) vía Navigator.pop(context, numero),
// o null si el usuario cierra sin seleccionar.
class _SugerenciasModal extends StatelessWidget {
  const _SugerenciasModal({
    required this.digits,
    required this.sugerencias,
  });

  final int digits;
  final List<String> sugerencias;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      // Fondo transparente: el Container interior define el look del popup.
      backgroundColor: Colors.transparent,
      // insetPadding mínimo — el ConstrainedBox limita el ancho real.
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              // min: el popup sólo ocupa lo que necesita — nunca full-screen.
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: título + botón cerrar ───────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Puedes elegir estas opciones de número:',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1372AE),
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF9CA3AF)),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'También puedes elegir un número automático',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Grid 3 col × 4 filas — altura fija por celda ────────
                // mainAxisExtent fijo evita que el GridView intente
                // crecer indefinidamente dentro del Column min.
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 46,
                  ),
                  itemCount: sugerencias.length,
                  itemBuilder: (_, i) => _SugerenciaItem(
                    numero: sugerencias[i],
                    onTap: () => Navigator.of(context).pop(sugerencias[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Celda de sugerencia — dígitos en círculos amarillos + línea azul debajo.
// Usa LayoutBuilder para calcular el tamaño de los círculos de forma adaptativa
// según el ancho disponible en la celda del grid (maneja 1–4 dígitos sin overflow).
class _SugerenciaItem extends StatelessWidget {
  const _SugerenciaItem({required this.numero, required this.onTap});

  final String numero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final n = numero.length;
          const gap = 3.0;
          // Calcula el tamaño máximo de círculo que cabe en la celda.
          final circleSize = ((constraints.maxWidth - gap * (n - 1)) / n)
              .clamp(16.0, 28.0);
          final fontSize = (circleSize * 0.56).clamp(9.0, 15.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < n; i++) ...[
                    _DigitCircle(
                      digit: numero[i],
                      size: circleSize,
                      fontSize: fontSize,
                    ),
                    if (i < n - 1) const SizedBox(width: gap),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF1372AE),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Dígito en círculo amarillo — tamaño configurable para adaptarse al grid.
class _DigitCircle extends StatelessWidget {
  const _DigitCircle({
    required this.digit,
    this.size = 28,
    this.fontSize = 14,
  });
  final String digit;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFECA0C),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1372AE),
        ),
      ),
    );
  }
}

// ── Fila de tabla de apuesta ──────────────────────────────────────────────────
//
// Distribuye 4 columnas con flex fijo para que el layout sea consistente
// en preview y en líneas confirmadas:
//
//   flex 2 │ flex 3           │ flex 4             │ flex 2 + 20px delete
//   Línea N │ ?c ??? / 3c 748 │ Lotería **** / Risa │ $0 / $1.500  [×]
//
class _BetTableRow extends StatelessWidget {
  const _BetTableRow({
    required this.isPreview,
    required this.lineLabel,
    required this.cifraWidget,
    required this.loteriaWidget,
    required this.montoText,
    required this.rowBase,
    this.onDelete,
  });

  final bool     isPreview;
  final String   lineLabel;
  final Widget   cifraWidget;
  final Widget   loteriaWidget;
  final String   montoText;
  final TextStyle rowBase;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0xFFFFCC00)),
          // La preview (última fila) cierra con borde inferior.
          // Las confirmadas no: la siguiente fila aporta su borde superior.
          bottom: isPreview
              ? const BorderSide(color: Color(0xFFFFCC00))
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Col 1 — "Línea N"
          Expanded(
            flex: 2,
            child: Text(
              lineLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1372AE),
              ),
            ),
          ),
          // Col 2 — cifras + número
          Expanded(
            flex: 3,
            child: cifraWidget,
          ),
          // Col 3 — lotería
          Expanded(
            flex: 4,
            child: loteriaWidget,
          ),
          // Col 4 — monto alineado a la derecha
          Expanded(
            flex: 2,
            child: Text(
              montoText,
              textAlign: TextAlign.right,
              style: rowBase,
            ),
          ),
          // Botón eliminar — solo en líneas confirmadas
          if (onDelete != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF4B5563),
                ),
              ),
            )
          else
            // Mismo espacio reservado para que el monto no se desplace
            const SizedBox(width: 22),
        ],
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

// Figma: "selección de fechas" — 122×65px, radius 16, amarillo-gane=#FFCC00
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isToday,
    required this.isTomorrow,
    required this.isSelected,
    required this.dayNames,
    required this.monthNames,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isTomorrow;
  final bool isSelected;
  final List<String> dayNames;
  final List<String> monthNames;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayName = dayNames[day.weekday];
    final String mainLabel;
    final String subLabel;

    if (isToday) {
      mainLabel = 'Hoy';
      subLabel = '${day.day} de ${monthNames[day.month]}';
    } else if (isTomorrow) {
      mainLabel = 'Mañana';
      subLabel = '${day.day} de ${monthNames[day.month]}';
    } else {
      mainLabel = '${day.day}';
      subLabel = monthNames[day.month];
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        height: 65,
        decoration: BoxDecoration(
          // Figma: #FFCC00 selected, #4B5563 unselected
          color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F131927),
              offset: Offset(0, 2),
              blurRadius: 4,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Color(0x14131927),
              offset: Offset(0, 4),
              blurRadius: 4,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day name — Inter Bold 12px
            Text(
              dayName,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                height: 24 / 12,
              ),
            ),
            // Hoy/Mañana/number — Inter Bold 24px
            Text(
              mainLabel,
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.24,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                height: 24 / 24,
              ),
            ),
            // Date — Inter Medium 10px
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.1,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                height: 17 / 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Figma: botones cifras 144×36px, radius 14, font Inter Bold 20px
// Seleccionado: #FECA0C / texto #1372AE — No seleccionado: #4B5563 / blanco
class _CifrasButtons extends StatelessWidget {
  const _CifrasButtons({required this.selected, required this.onSelect});

  final _Modalidad? selected; // null = ninguna cifra seleccionada aún
  final ValueChanged<_Modalidad> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in _Modalidad.values) ...[
          _CifraBtn(
            label: m.label,
            isSelected: selected != null && selected == m,
            onTap: () => onSelect(m),
          ),
          if (m != _Modalidad.cuatroC) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// Figma hover: amarillo pálido #FEF3C7 (amarillo-50) — distinto del seleccionado #FECA0C
class _CifraBtn extends StatefulWidget {
  const _CifraBtn({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CifraBtn> createState() => _CifraBtnState();
}

class _CifraBtnState extends State<_CifraBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (widget.isSelected) {
      bg = const Color(0xFFFECA0C); // amarillo fuerte — seleccionado
      fg = const Color(0xFF1372AE);
    } else if (_hovered) {
      bg = const Color(0xFFFEF3C7); // amarillo pálido — hover
      fg = const Color(0xFF1372AE);
    } else {
      bg = const Color(0xFF4B5563); // gris oscuro — normal
      fg = Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 144,
          height: 36,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: fg,
              height: 24 / 20,
            ),
          ),
        ),
      ),
    );
  }
}

// Figma node I1201:9228;622:8439 — columna intermedia sección 2
// w=177px, dos filas: Radio + texto "Directo" / "Combinado"
// Inter Bold 22px #4B5563 — círculo con borde amarillo
class _DirectoCombinadoColumn extends StatelessWidget {
  const _DirectoCombinadoColumn({
    required this.selected,
    required this.onSelect,
  });

  final _ModalidadJuego selected;
  final ValueChanged<_ModalidadJuego> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 177,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioRow(
            label: 'Directo',
            isSelected: selected == _ModalidadJuego.directo,
            onTap: () => onSelect(_ModalidadJuego.directo),
          ),
          const SizedBox(height: 7),
          _RadioRow(
            label: 'Combinado',
            isSelected: selected == _ModalidadJuego.combinado,
            onTap: () => onSelect(_ModalidadJuego.combinado),
          ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo radio — Figma: 24×24, borde amarillo, relleno blanco/amarillo
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? const Color(0xFFFECA0C)
                  : Colors.white,
              border: Border.all(
                color: const Color(0xFFFECA0C), // borde siempre amarillo
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.circle,
                    size: 10,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
              height: 28 / 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomaticoBtn extends StatelessWidget {
  const _AutomaticoBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.refreshCircular,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(Color(0xFF1372AE), BlendMode.srcIn),
            ),
            const SizedBox(width: 6),
            Text(
              'Automático',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1372AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Celda de lotería — Figma: 87×87 (cuadrado)
// Normal:    borde azul #0F5886 1px  — Seleccionada: borde amarillo #FFCC00 2px + sombra
// Texto: Inter SemiBold 11px, color #0F5886 (secondary-p)
// Selección única: solo una lotería puede estar seleccionada por línea.
class _LoteriaCell extends StatelessWidget {
  const _LoteriaCell({
    required this.name,
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          // Normal: borde azul oscuro (Figma secondary-p #0F5886)
          // Seleccionado: borde amarillo fuerte
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFCC00)
                : const Color(0xFF0F5886),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Logo ocupa ~65% de la altura, texto el resto
            final logoH = constraints.maxHeight * 0.63;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: logoH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F5886),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Círculo rojo — número no disponible/cancelado (Figma: bg #FAC5C3, texto #EE443F, símbolo *)
class _ErrorCircle extends StatelessWidget {
  const _ErrorCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFFAC5C3), // red-100
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '*',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFEE443F), // red-500
        ),
      ),
    );
  }
}

/// Círculo amarillo relleno con dígito — estado digitado
class _NumberCircle extends StatelessWidget {
  const _NumberCircle({required this.digit});
  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFFECA0C),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1372AE),
        ),
      ),
    );
  }
}

/// Círculo gris placeholder — dígito no ingresado aún
class _PlaceholderCircle extends StatelessWidget {
  const _PlaceholderCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFD1D5DB),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '?',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

// ── Modal de confirmación de transacción ──────────────────────────────────────
//
// Figma node 682:6498 — muestra subtotal, IVA, total y selección de método
// de pago antes de procesar el pago. El botón "Confirmar y pagar" queda
// pendiente de integración con la pasarela (TODO).
class _ConfirmacionModal extends StatefulWidget {
  const _ConfirmacionModal({
    required this.subtotal,
    required this.iva,
    required this.total,
  });

  final int subtotal;
  final int iva;
  final int total;

  @override
  State<_ConfirmacionModal> createState() => _ConfirmacionModalState();
}

class _ConfirmacionModalState extends State<_ConfirmacionModal> {
  _MetodoPago _metodoPago = _MetodoPago.billetera;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botón cerrar — arriba a la derecha
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF9CA3AF)),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),

                // Título — Inter Bold 24px #1372AE centrado
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Resumen de transacción',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Subtítulo — mensaje ñapa (Figma 829:4134)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '¡Gracias por hacer tu apuesta en nuestra plataforma! '
                    'con cada apuesta recibes una ñapa automática que '
                    'aumenta el valor de tu premio.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF4B5563),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Bloque resumen de pago (Figma 682:6447) ─────────────
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtotal — alineado a la derecha
                      _buildResumenRow(
                        label: 'Subtotal',
                        value: _ChanceTradicionalScreenState._fmt(
                          widget.subtotal,
                        ),
                        isTotal: false,
                      ),
                      // IVA — alineado a la derecha
                      _buildResumenRow(
                        label: 'IVA',
                        value: _ChanceTradicionalScreenState._fmt(widget.iva),
                        isTotal: false,
                      ),
                      // Total a pagar — centrado, valor en azul
                      _buildResumenRow(
                        label: 'Total a pagar',
                        value: _ChanceTradicionalScreenState._fmt(widget.total),
                        isTotal: true,
                      ),

                      // Separador amarillo
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          color: Color(0xFFFFCC00),
                          thickness: 1,
                          height: 1,
                        ),
                      ),

                      // "Elige un método de pago"
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Elige un método de pago',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF4B5563),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      // Opción 1 — Saldo en billetera
                      _buildPaymentOption(
                        value: _MetodoPago.billetera,
                        content: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Saldo en billetera',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                            // Chip saldo "$0"
                            Container(
                              height: 33,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.attach_money,
                                    size: 16,
                                    color: Color(0xFF111827),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '\$ 0',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Botón recarga billetera — #C7B322 (accent-500)
                            Container(
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7B322),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                AppAssets.iconWallet,
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Opción 2 — PSE + tarjetas de crédito
                      _buildPaymentOption(
                        value: _MetodoPago.pse,
                        content: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PseLogoWidget(),
                            SizedBox(width: 8),
                            _MastercardLogoWidget(),
                            SizedBox(width: 8),
                            _VisaLogoWidget(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón "Confirmar y pagar" — Figma I682:6447;664:10025
                      // verde #43B75D, 371×57, radius 26
                      Center(
                        child: SizedBox(
                          width: 371,
                          height: 57,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF43B75D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              // TODO(pasarela): conectar método de pago seleccionado
                            },
                            child: Text(
                              'Confirmar y pagar',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Separador amarillo
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Color(0xFFFFCC00),
                          thickness: 1,
                          height: 1,
                        ),
                      ),

                      // Link "Agregar otra apuesta" — cierra el modal y vuelve al formulario
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          'Agregar otra apuesta',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1372AE),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF1372AE),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Fila de resumen: Subtotal/IVA alineados a la derecha; Total centrado.
  Widget _buildResumenRow({
    required String label,
    required String value,
    required bool isTotal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        mainAxisAlignment:
            isTotal ? MainAxisAlignment.center : MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: isTotal
                ? GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1372AE),
                  )
                : GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
          ),
        ],
      ),
    );
  }

  // Fila de método de pago con radio animado y borde amarillo cuando está seleccionado.
  Widget _buildPaymentOption({
    required _MetodoPago value,
    required Widget content,
  }) {
    final selected = _metodoPago == value;
    return GestureDetector(
      onTap: () => setState(() => _metodoPago = value),
      child: Center(
        child: Container(
          width: 336,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? Border.all(color: const Color(0xFFFFCC00), width: 2)
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? const Color(0xFFFECA0C) : Colors.white,
                  border: Border.all(
                    color: const Color(0xFFFECA0C),
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.circle, size: 10, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 18),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logos de métodos de pago ──────────────────────────────────────────────────
// Placeholders visuales fieles a los colores de cada marca.
// Se reemplazan con Image.asset cuando se integren los assets oficiales.

class _PseLogoWidget extends StatelessWidget {
  const _PseLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF003087),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        'PSE',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MastercardLogoWidget extends StatelessWidget {
  const _MastercardLogoWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 24,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEB001B),
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF79E1B).withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisaLogoWidget extends StatelessWidget {
  const _VisaLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F71),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'VISA',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          fontStyle: FontStyle.italic,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

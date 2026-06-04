import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS  (HU-PM001)
// ─────────────────────────────────────────────────────────────────────────────

/// Valores cerrados habilitados por normativa (HU-PM001 §REGLAS).
/// La distribución 25%/75% es interna — no visible ni configurable por el usuario.
enum _ValorFormulario {
  mil(1000),
  dosMil(2000),
  tresMil(3000);

  const _ValorFormulario(this.amount);
  final int amount;

  /// Apuesta Principal = 25 % del formulario.
  int get apuestaPrincipal => (amount * 0.25).round();

  /// Incentivo con Cobro = 75 % del formulario.
  int get incentivoCobro => (amount * 0.75).round();

  String get label {
    if (amount < 1000) return '\$$amount';
    return '\$${(amount ~/ 1000)}.000';
  }
}

/// Datos de una lotería habilitada.
/// En producción esta lista se consultará dinámicamente desde el back-end
/// (HU-PM001 §REGLAS: «no debe estar embebida en código fijo»).
/// El asset se mantiene aquí como fallback local mientras no exista el endpoint.
class _Loteria {
  const _Loteria({required this.name, required this.asset});
  final String name;
  final String asset;
}

/// Datos estáticos de loterías — fuente: Figma nodo 830-13574 / AppAssets.
/// TODO: reemplazar con llamada al back-end cuando esté disponible.
const _kLoteriaData = <_Loteria>[
  _Loteria(name: 'Risaralda',      asset: AppAssets.logoRisaralda),
  _Loteria(name: 'Meta',           asset: AppAssets.logoLoteriaMeta),
  _Loteria(name: 'Quindío',        asset: AppAssets.logoLoteriaQuindio),
  _Loteria(name: 'Cauca',          asset: AppAssets.logoLoteriaCauca),
  _Loteria(name: 'Medellín',       asset: AppAssets.logoLoteriaMedellin),
  _Loteria(name: 'Extra Medellín', asset: AppAssets.logoLoteriaExtraMedellin),
  _Loteria(name: 'Manizales',      asset: AppAssets.logoLoteriaManizales),
  _Loteria(name: 'Cundinamarca',   asset: AppAssets.logoLoteriaCundinamarca),
  _Loteria(name: 'Boyacá',         asset: AppAssets.logoLoteriaBoyaca),
  _Loteria(name: 'Bogotá',         asset: AppAssets.logoLoteriaBogota),
  _Loteria(name: 'Valle',          asset: AppAssets.logoValle),
  _Loteria(name: 'Tolima',         asset: AppAssets.logoLoteriaTolima),
  _Loteria(name: 'Huila',          asset: AppAssets.logoLoteriaHuila),
  _Loteria(name: 'Santander',      asset: AppAssets.logoLoteriaSantander),
];

/// Apuesta registrada (actualmente solo 1 por formulario — HU-PM001 §REGLAS).
/// Los campos APT1–APT4 existen en el ticket impreso para expansión futura.
class _Apuesta {
  const _Apuesta({
    required this.valor,
    required this.numeroAP,
    required this.loteriaAPIdx,
    required this.numeroIC,
    required this.loteriaICIdx,
    required this.fecha,
  });

  final _ValorFormulario valor;
  final String numeroAP;     // 2 cifras — Apuesta Principal
  final int loteriaAPIdx;
  final String numeroIC;     // 3 cifras — Incentivo con Cobro
  final int loteriaICIdx;
  final DateTime fecha;

  int get apuestaPrincipal => valor.apuestaPrincipal;
  int get incentivoCobro   => valor.incentivoCobro;

  // IVA: el precio incluye IVA → base = valor / 1.19
  // Premio 1 (solo 2C): AP × 50 / 1.19
  int get premioOportunidad1 => (apuestaPrincipal * 50 / 1.19).round();

  // Premio 2 (solo 3C): IC × 250 / 1.19
  int get premioOportunidad2 => (incentivoCobro * 250 / 1.19).round();

  // Premio Mayor (2C + 3C): IC × 18.500 / 1.19
  int get premioMayor => (incentivoCobro * 18500 / 1.19).round();

  // IVA implícito sobre el total del formulario
  int get iva => (valor.amount - valor.amount / 1.19).round();
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class PataMillonariaScreen extends StatefulWidget {
  const PataMillonariaScreen({super.key});

  @override
  State<PataMillonariaScreen> createState() => _PataMillonariaScreenState();
}

class _PataMillonariaScreenState extends State<PataMillonariaScreen> {
  // ── Paso 1: fecha ──────────────────────────────────────────────────────────
  late final List<DateTime> _days;
  int _selectedDay = 0;

  // ── Paso 2: valor cerrado ──────────────────────────────────────────────────
  _ValorFormulario _valor = _ValorFormulario.tresMil;

  // ── Paso 2: Apuesta Principal ──────────────────────────────────────────────
  int? _loteriaAPIdx;
  final TextEditingController _numeroAPCtrl = TextEditingController();
  String? _errorAP;

  // ── Paso 3: Incentivo con Cobro ────────────────────────────────────────────
  int? _loteriaICIdx;
  final TextEditingController _numeroICCtrl = TextEditingController();
  String? _errorIC;

  // ── Estado general ─────────────────────────────────────────────────────────
  /// Actualmente solo 1 apuesta por formulario (HU-PM001 §REGLAS).
  /// La arquitectura soporta una lista para expansión futura (APT1–APT4).
  final List<_Apuesta> _apuestas = [];
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _days = _calcDays();
  }

  @override
  void dispose() {
    _numeroAPCtrl.dispose();
    _numeroICCtrl.dispose();
    super.dispose();
  }

  // Próximos 6 días corridos (chance se juega todos los días)
  static List<DateTime> _calcDays() {
    final result = <DateTime>[];
    var d = DateTime.now();
    while (result.length < 6) {
      result.add(d);
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

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  void _autoAP() {
    final rand = math.Random().nextInt(100);
    _numeroAPCtrl.text = rand.toString().padLeft(2, '0');
    setState(() => _errorAP = null);
  }

  void _autoIC() {
    final rand = math.Random().nextInt(1000);
    _numeroICCtrl.text = rand.toString().padLeft(3, '0');
    setState(() => _errorIC = null);
  }

  /// Valida y agrega la apuesta.
  /// HU-PM001: solo 1 apuesta por formulario actualmente.
  bool _validate() {
    String? errorAP;
    String? errorIC;

    final ap = _numeroAPCtrl.text.trim();
    if (_loteriaAPIdx == null) {
      errorAP = 'Selecciona una lotería para la Apuesta Principal';
    } else if (ap.isEmpty || ap.length != 2) {
      errorAP = 'El número debe tener exactamente 2 cifras';
    }

    final ic = _numeroICCtrl.text.trim();
    if (_loteriaICIdx == null) {
      errorIC = 'Selecciona una lotería para el Incentivo con Cobro';
    } else if (ic.isEmpty || ic.length != 3) {
      errorIC = 'El número debe tener exactamente 3 cifras';
    } else if (_loteriaICIdx == _loteriaAPIdx) {
      // HU-PM001: loterías deben ser diferentes
      errorIC = 'La lotería del Incentivo debe ser diferente a la Apuesta Principal';
    }

    setState(() {
      _errorAP = errorAP;
      _errorIC = errorIC;
    });

    return errorAP == null && errorIC == null;
  }

  void _addApuesta() {
    if (!_validate()) return;
    setState(() {
      _apuestas.add(
        _Apuesta(
          valor: _valor,
          numeroAP: _numeroAPCtrl.text.trim(),
          loteriaAPIdx: _loteriaAPIdx!,
          numeroIC: _numeroICCtrl.text.trim(),
          loteriaICIdx: _loteriaICIdx!,
          fecha: _days[_selectedDay],
        ),
      );
    });
  }

  void _removeApuesta(int i) => setState(() => _apuestas.removeAt(i));

  int get _totalValor => _apuestas.fold(0, (s, a) => s + a.valor.amount);
  int get _totalIva   => _apuestas.fold(0, (s, a) => s + a.iva);

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

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
                      _AuthRequired(onLoginTap: () => _showLoginModal(context))
                    else
                      _buildContent(sw),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
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

  // ── Auth modal ─────────────────────────────────────────────────────────────

  void _popDialog(BuildContext dialogContext) {
    if (!dialogContext.mounted) return;
    final navigator = Navigator.of(dialogContext);
    if (navigator.canPop()) navigator.pop();
  }

  void _showLoginModal(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: LoginFormWidget(
            onClose: () => _popDialog(dialogContext),
            onLoginSuccess: () => _popDialog(dialogContext),
            onRegisterRequested: () => _popDialog(dialogContext),
            onRecoveryRequested: (identifier) {
              _popDialog(dialogContext);
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

  // ── Layout principal ───────────────────────────────────────────────────────

  Widget _buildContent(double sw) {
    final isDesktop = sw >= 1024;

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
                constraints: const BoxConstraints(maxWidth: 780),
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

  // ─────────────────────────────────────────────────────────────────────────
  // COLUMNA IZQUIERDA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLeftCard(bool isDesktop) {
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
          const SizedBox(height: 16),
          _buildCardTitle('Sigue los pasos para realizar tu apuesta'),
          const SizedBox(height: 16),
          _buildStep1(),
          const SizedBox(height: 20),
          _buildStep2(),
          const SizedBox(height: 20),
          _buildApuestaPrincipal(isDesktop),
        ],
      ),
    );
  }

  // Banner — assets/images/banner_pata_millonaria.png (1492×300)
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: AppAssets.bannerPataMillonariaAspectRatio,
        child: Image.asset(
          AppAssets.bannerPataMillonaria,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _buildCardTitle(String text) {
    return Center(
      child: Text(
        text,
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

  // ── Paso 1: fecha ──────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepLabel(text: '1. Escoge el día en que juega tu apuesta'),
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

  // ── Paso 2: valor del formulario ───────────────────────────────────────────
  // HU-PM001: botones de opción, NO campo de texto libre.

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepLabel(text: '2. Elige el valor de tu formulario'),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final v in _ValorFormulario.values) ...[
              Expanded(
                child: _ValorChip(
                  label: v.label,
                  isSelected: _valor == v,
                  onTap: () => setState(() => _valor = v),
                ),
              ),
              if (v != _ValorFormulario.tresMil) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Desglose informativo (HU-PM001: puede mostrarse en el resumen)
        Text(
          'Apuesta Principal: ${_fmt(_valor.apuestaPrincipal)}  ·  '
          'Incentivo con Cobro: ${_fmt(_valor.incentivoCobro)}',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  // ── Paso 3a: Apuesta Principal (2 cifras + lotería) ───────────────────────

  Widget _buildApuestaPrincipal(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepLabel(text: '3. Apuesta Principal — elige tu número de 2 cifras y su lotería'),
        const SizedBox(height: 12),
        // Grilla de loterías
        _LoteriaGrid(
          selectedIdx: _loteriaAPIdx,
          disabledIdx: _loteriaICIdx, // misma lotería bloqueada
          onSelect: (i) => setState(() {
            _loteriaAPIdx = i;
            _errorAP = null;
          }),
        ),
        const SizedBox(height: 12),
        // Botón automático + campo número
        _AutomaticoBtn(onTap: _autoAP),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu número de 2 cifras',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 6),
        _NumeroInput(
          controller: _numeroAPCtrl,
          maxLength: 2,
          hasError: _errorAP != null,
          onChanged: (_) => setState(() => _errorAP = null),
        ),
        const SizedBox(height: 8),
        // Display resumen AP: [2C][?][?][$750]
        _BetDisplay(
          tag: '2C',
          digits: 2,
          numero: _numeroAPCtrl.text.trim(),
          monto: _valor.apuestaPrincipal,
          fmtMonto: _fmt,
        ),
        if (_errorAP != null) ...[
          const SizedBox(height: 6),
          _ErrorText(text: _errorAP!),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLUMNA DERECHA
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRightCard() {
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
          _buildCardTitle('Combina tu incentivo'),
          const SizedBox(height: 16),
          _buildIncentivoSection(),
          const SizedBox(height: 20),
          _buildAddApuestaBtn(),
          if (_errorIC != null) ...[
            const SizedBox(height: 8),
            _ErrorText(text: _errorIC!),
          ],
          const SizedBox(height: 20),
          _buildApuestasTable(),
          const SizedBox(height: 16),
          _buildResumenPago(),
          const SizedBox(height: 16),
          _confirmed ? _buildSuccessState() : _buildConfirmBtn(),
          const SizedBox(height: 20),
          _buildPlanPremios(),
        ],
      ),
    );
  }

  // ── Paso 3b: Incentivo con Cobro ───────────────────────────────────────────

  Widget _buildIncentivoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepLabel(text: '4. Incentivo con Cobro — elige tu número de 3 cifras y otra lotería'),
        const SizedBox(height: 12),
        _LoteriaGrid(
          selectedIdx: _loteriaICIdx,
          disabledIdx: _loteriaAPIdx, // misma lotería bloqueada
          onSelect: (i) => setState(() {
            _loteriaICIdx = i;
            _errorIC = null;
          }),
        ),
        const SizedBox(height: 12),
        _AutomaticoBtn(onTap: _autoIC),
        const SizedBox(height: 8),
        Text(
          'Ingresa tu número de 3 cifras',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 6),
        _NumeroInput(
          controller: _numeroICCtrl,
          maxLength: 3,
          hasError: _errorIC != null,
          onChanged: (_) => setState(() => _errorIC = null),
        ),
        const SizedBox(height: 8),
        // Display resumen IC: [3C][?][?][?][$2.250]
        _BetDisplay(
          tag: '3C',
          digits: 3,
          numero: _numeroICCtrl.text.trim(),
          monto: _valor.incentivoCobro,
          fmtMonto: _fmt,
        ),
      ],
    );
  }

  // ── Botón agregar apuesta ──────────────────────────────────────────────────

  Widget _buildAddApuestaBtn() {
    // HU-PM001: actualmente 1 apuesta. Botón deshabilitado si ya existe una.
    final canAdd = _apuestas.isEmpty;
    return GestureDetector(
      onTap: canAdd ? _addApuesta : null,
      child: AnimatedOpacity(
        opacity: canAdd ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 180),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFECA0C),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF1372AE)),
              const SizedBox(width: 8),
              Text(
                'Agregar otra línea de apuesta',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1372AE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tabla de apuestas ──────────────────────────────────────────────────────

  Widget _buildApuestasTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu apuesta',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        // Cabecera
        _TableHeader(),
        // Filas
        if (_apuestas.isEmpty)
          _buildEmptyRow()
        else
          for (int i = 0; i < _apuestas.length; i++)
            _buildApuestaRow(i),
      ],
    );
  }

  Widget _buildEmptyRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00)),
          bottom: BorderSide(color: Color(0xFFFFCC00)),
        ),
      ),
      child: Row(
        children: [
          _TableCell(text: 'Línea 1', isBlue: true),
          const Spacer(),
          _TableCell(text: '2C ??'),
          const Spacer(),
          _TableCell(text: '–'),
          const Spacer(),
          _TableCell(text: '3C ???'),
          const Spacer(),
          _TableCell(text: '–'),
          const Spacer(),
          _TableCell(text: _fmt(_valor.amount)),
        ],
      ),
    );
  }

  Widget _buildApuestaRow(int i) {
    final a = _apuestas[i];
    final lotAP = _kLoteriaData[a.loteriaAPIdx].name;
    final lotIC = _kLoteriaData[a.loteriaICIdx].name;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0xFFFFCC00)),
          bottom: i == _apuestas.length - 1
              ? const BorderSide(color: Color(0xFFFFCC00))
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          _TableCell(text: 'L${i + 1}', isBlue: true),
          const SizedBox(width: 4),
          Flexible(child: _TableCell(text: '2C ${a.numeroAP}', isYellow: true)),
          const SizedBox(width: 4),
          Flexible(child: _TableCell(text: lotAP)),
          const SizedBox(width: 4),
          Flexible(child: _TableCell(text: '3C ${a.numeroIC}', isYellow: true)),
          const SizedBox(width: 4),
          Flexible(child: _TableCell(text: lotIC)),
          const SizedBox(width: 4),
          _TableCell(text: _fmt(a.valor.amount)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeApuesta(i),
            child: const Icon(Icons.close, size: 16, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  // ── Resumen de pago ────────────────────────────────────────────────────────

  Widget _buildResumenPago() {
    return Column(
      children: [
        _SummaryRow(label: 'IVA', value: _fmt(_totalIva)),
        const SizedBox(height: 4),
        _SummaryRow(label: 'Valor apuesta', value: _fmt(_totalValor)),
      ],
    );
  }

  // ── Botón confirmar ────────────────────────────────────────────────────────

  Widget _buildConfirmBtn() {
    final hasApuestas = _apuestas.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasApuestas
              ? const Color(0xFF43B75D)
              : const Color(0xFFBDD7EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: hasApuestas
            ? () => setState(() => _confirmed = true)
            : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Confirmar y pagar',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: hasApuestas ? Colors.white : const Color(0xFF6B99B9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    final d = _days[_selectedDay];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF43B75D)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF43B75D), size: 32),
          const SizedBox(height: 8),
          Text(
            '¡Apuesta registrada exitosamente!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Pata Millonaria · ${_dayNames[d.weekday]} ${d.day} de ${_monthNames[d.month]}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF2E7D32),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _confirmed = false;
              _apuestas.clear();
              _loteriaAPIdx = null;
              _loteriaICIdx = null;
              _numeroAPCtrl.clear();
              _numeroICCtrl.clear();
            }),
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
    );
  }

  // ── Plan de premios ────────────────────────────────────────────────────────
  // HU-PM001: valores dinámicos según el formulario actual.

  Widget _buildPlanPremios() {
    final ap  = _valor.apuestaPrincipal;
    final ic  = _valor.incentivoCobro;
    final p1  = (ap  * 50   / 1.19).round();
    final p2  = (ic  * 250  / 1.19).round();
    final pm  = (ic  * 18500 / 1.19).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan de premios',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C2E6F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Para un formulario de ${_valor.label}',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 12),
        _PremioRow(
          numero: '1',
          titulo: 'Solo 2 cifras (Apuesta Principal)',
          formula: '${_fmt(ap)} × 50 / 1,19',
          premio: _fmt(p1),
        ),
        const SizedBox(height: 8),
        _PremioRow(
          numero: '2',
          titulo: 'Solo 3 cifras (Incentivo con Cobro)',
          formula: '${_fmt(ic)} × 250 / 1,19',
          premio: _fmt(p2),
        ),
        const SizedBox(height: 8),
        _PremioRow(
          numero: '★',
          titulo: 'Premio Mayor (2C + 3C)',
          formula: '${_fmt(ic)} × 18.500 / 1,19',
          premio: _fmt(pm),
          isMayor: true,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFCC00)),
          ),
          child: Text(
            'Los premios NO son incluyentes: si ganas más de una oportunidad '
            'simultáneamente, solo se paga el Premio Mayor.',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF7B5E00),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

/// Widget que solicita autenticación cuando el usuario no está logueado.
class _AuthRequired extends StatelessWidget {
  const _AuthRequired({required this.onLoginTap});
  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
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
                  AppAssets.bannerPataMillonaria,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.center,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicia sesión para jugar',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2E6F),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en La Pata Millonaria.',
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
                  onPressed: onLoginTap,
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
}

// ── Chip de día ────────────────────────────────────────────────────────────────

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
    final mainLabel = isToday
        ? 'Hoy'
        : isTomorrow
            ? 'Mañana'
            : '${day.day}';
    final subLabel  = '${day.day} de ${monthNames[day.month]}';
    final dayName   = dayNames[day.weekday];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        height: 65,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F131927),
              offset: Offset(0, 2),
              blurRadius: 4,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? const Color(0xFF1372AE) : Colors.white,
              ),
            ),
            Text(
              mainLabel,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: isSelected ? const Color(0xFF1372AE) : Colors.white,
                height: 1.1,
              ),
            ),
            Text(
              subLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF1372AE) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de valor cerrado ──────────────────────────────────────────────────────

class _ValorChip extends StatelessWidget {
  const _ValorChip({
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
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFECA0C) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14),
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
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1372AE) : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Grilla de loterías ─────────────────────────────────────────────────────────

class _LoteriaGrid extends StatelessWidget {
  const _LoteriaGrid({
    required this.selectedIdx,
    required this.disabledIdx,
    required this.onSelect,
  });

  final int? selectedIdx;
  final int? disabledIdx;
  final ValueChanged<int> onSelect;

  // Columnas responsivas — objetivo: 7 cols para las 14 loterías (7×2 filas completas).
  // targetCell=60 garantiza 7 cols en cards ≥ 480px y evita la fila incompleta de 2.
  static int _cols(double available) {
    const gap = 10.0;
    const targetCell = 60.0;
    final cols = ((available + gap) / (targetCell + gap)).floor();
    return cols.clamp(3, 7);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final cols = _cols(constraints.maxWidth);
        final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < _kLoteriaData.length; i++)
              SizedBox(
                width: cellW,
                height: cellW,
                child: _LoteriaCell(
                  name: _kLoteriaData[i].name,
                  asset: _kLoteriaData[i].asset,
                  isSelected: selectedIdx == i,
                  isDisabled: disabledIdx == i,
                  onTap: () => onSelect(i),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoteriaCell extends StatelessWidget {
  const _LoteriaCell({
    required this.name,
    required this.asset,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final String name;
  final String asset;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.35 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFFE5E7EB),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final logoH = constraints.maxHeight * 0.68;
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
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
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
                        fontSize: 9,
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
      ),
    );
  }
}

// ── Botón Automático ───────────────────────────────────────────────────────────

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
            const Icon(Icons.refresh, size: 16, color: Color(0xFF1372AE)),
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

// ── Campo de número ────────────────────────────────────────────────────────────

class _NumeroInput extends StatelessWidget {
  const _NumeroInput({
    required this.controller,
    required this.maxLength,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: hasError ? AppColors.error : const Color(0xFFD1D5DB),
        ),
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
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: maxLength,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: List.filled(maxLength, '?').join(' '),
          hintStyle: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Display de apuesta (resumen visual) ───────────────────────────────────────

class _BetDisplay extends StatelessWidget {
  const _BetDisplay({
    required this.tag,
    required this.digits,
    required this.numero,
    required this.monto,
    required this.fmtMonto,
  });

  final String tag;
  final int digits;
  final String numero;
  final int monto;
  final String Function(int) fmtMonto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            offset: Offset(0, 2),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _DisplayCell(text: tag),
          const SizedBox(width: 6),
          for (int i = 0; i < digits; i++) ...[
            _DisplayCell(
              text: i < numero.length ? numero[i] : '?',
              isHighlight: i < numero.length,
            ),
            if (i < digits - 1) const SizedBox(width: 4),
          ],
          const SizedBox(width: 6),
          _DisplayCell(text: fmtMonto(monto)),
        ],
      ),
    );
  }
}

class _DisplayCell extends StatelessWidget {
  const _DisplayCell({required this.text, this.isHighlight = false});

  final String text;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFFFFCC00).withValues(alpha: 0.25)
            : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isHighlight ? const Color(0xFFFFCC00) : const Color(0xFFD1D5DB),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

// ── Tabla header ───────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF2C2E6F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: const [
          Expanded(flex: 1, child: _HeaderCell(text: 'Línea')),
          Expanded(flex: 2, child: _HeaderCell(text: 'Apuesta')),
          Expanded(flex: 2, child: _HeaderCell(text: 'Lotería AP')),
          Expanded(flex: 2, child: _HeaderCell(text: 'Incentivo')),
          Expanded(flex: 2, child: _HeaderCell(text: 'Lotería IC')),
          Expanded(flex: 2, child: _HeaderCell(text: 'Valor')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Celda de tabla ─────────────────────────────────────────────────────────────

class _TableCell extends StatelessWidget {
  const _TableCell({required this.text, this.isBlue = false, this.isYellow = false});

  final String text;
  final bool isBlue;
  final bool isYellow;

  @override
  Widget build(BuildContext context) {
    Color color = const Color(0xFF4B5563);
    if (isBlue)   color = const Color(0xFF1372AE);
    if (isYellow) color = const Color(0xFFB8860B);

    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Fila de resumen ────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
}

// ── Fila de plan de premios ────────────────────────────────────────────────────

class _PremioRow extends StatelessWidget {
  const _PremioRow({
    required this.numero,
    required this.titulo,
    required this.formula,
    required this.premio,
    this.isMayor = false,
  });

  final String numero;
  final String titulo;
  final String formula;
  final String premio;
  final bool isMayor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMayor ? const Color(0xFF2C2E6F) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMayor ? const Color(0xFFFFCC00) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isMayor ? const Color(0xFFFFCC00) : const Color(0xFF1372AE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              numero,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isMayor ? const Color(0xFF2C2E6F) : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMayor ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
                Text(
                  formula,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isMayor
                        ? const Color(0xFFFFCC00).withValues(alpha: 0.85)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Text(
            premio,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isMayor ? const Color(0xFFFFCC00) : const Color(0xFF2C2E6F),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Label de paso ──────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF4B5563),
        height: 1.4,
      ),
    );
  }
}

// ── Texto de error ─────────────────────────────────────────────────────────────

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 14, color: AppColors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }
}

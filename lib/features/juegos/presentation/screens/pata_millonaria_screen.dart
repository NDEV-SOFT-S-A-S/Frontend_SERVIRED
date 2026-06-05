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

// ── Negocio HU-PM001 ─────────────────────────────────────────────────────────

const _kLoteriaData = <({String name, String asset})>[
  (name: 'Lotería del\nRisaralda',      asset: AppAssets.logoRisaralda),
  (name: 'Lotería del\nMeta',           asset: AppAssets.logoLoteriaMeta),
  (name: 'Lotería del\nQuindío',        asset: AppAssets.logoLoteriaQuindio),
  (name: 'Lotería del\nCauca',          asset: AppAssets.logoLoteriaCauca),
  (name: 'Lotería de\nMedellín',        asset: AppAssets.logoLoteriaMedellin),
  (name: 'Extra Lotería\nde Medellín',  asset: AppAssets.logoLoteriaExtraMedellin),
  (name: 'Lotería de\nManizales',       asset: AppAssets.logoLoteriaManizales),
  (name: 'Lotería de\nCundinamarca',    asset: AppAssets.logoLoteriaCundinamarca),
  (name: 'Lotería de\nBoyacá',          asset: AppAssets.logoLoteriaBoyaca),
  (name: 'Lotería de\nBogotá',          asset: AppAssets.logoLoteriaBogota),
  (name: 'Lotería del\nValle',          asset: AppAssets.logoValle),
  (name: 'Lotería del\nTolima',         asset: AppAssets.logoLoteriaTolima),
  (name: 'Lotería del\nHuila',          asset: AppAssets.logoLoteriaHuila),
  (name: 'Lotería de\nSantander',       asset: AppAssets.logoLoteriaSantander),
];

// Distribución del valor cerrado (IVA incluido)
// AP = 25 %, IC = 75 % (HU-PM001 RN-2)
enum _ValorApuesta {
  mil(1000),
  dosMil(2000),
  tresMil(3000);

  const _ValorApuesta(this.amount);
  final int amount;

  int get apValor => (amount * 0.25).round(); // Apuesta Principal
  int get icValor => (amount * 0.75).round(); // Incentivo con Cobro
  // IVA = monto × 19 / 119 (resolución G-000004)
  int get iva => (amount * 19 / 119).round();
}

// Premio Oportunidad 1 (solo 2C): AP × 50 / 1.19
int _premioOp1(int apValor) => (apValor * 50 / 1.19).round();
// Premio Oportunidad 2 (solo 3C): IC × 250 / 1.19
int _premioOp2(int icValor) => (icValor * 250 / 1.19).round();
// Premio Mayor (2C + 3C): IC × 18.500 / 1.19
int _premioMayor(int icValor) => (icValor * 18500 / 1.19).round();

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

// ── Modelo de línea de apuesta ────────────────────────────────────────────────

class _BetLine {
  const _BetLine({
    required this.fechaIdx,
    required this.valor,
    required this.loteriaAPIdx,
    required this.numeroAP,
    required this.loteriaICIdx,
    required this.numeroIC,
  });

  final int fechaIdx;
  final _ValorApuesta valor;
  final int loteriaAPIdx;
  final String numeroAP; // 2 cifras exactas
  final int loteriaICIdx;
  final String numeroIC; // 3 cifras exactas
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PataMillonariaScreen extends StatefulWidget {
  const PataMillonariaScreen({super.key});

  @override
  State<PataMillonariaScreen> createState() => _PataMillonariaScreenState();
}

class _PataMillonariaScreenState extends State<PataMillonariaScreen> {
  // 6 días corridos desde hoy (HU-PM001)
  late final List<DateTime> _fechas;
  int _selectedFechaIdx = 0;

  _ValorApuesta? _valor;
  int? _loteriaAPIdx;
  int? _loteriaICIdx;

  final TextEditingController _apCtrl = TextEditingController();
  final TextEditingController _icCtrl = TextEditingController();

  // Errores de validación del formulario actual
  String? _errorValor;
  String? _errorLoteriaAP;
  String? _errorNumeroAP;
  String? _errorLoteriaIC;
  String? _errorNumeroIC;
  String? _errorMismaLoteria;

  // Líneas de apuesta confirmadas
  final List<_BetLine> _betLines = [];

  bool _finalConfirmed = false;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _fechas = List.generate(6, (i) => hoy.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _apCtrl.dispose();
    _icCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  static String _labelFecha(DateTime d, int idx) {
    if (idx == 0) return 'Hoy';
    if (idx == 1) return 'Mañana';
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return '${dias[d.weekday - 1]} ${d.day}';
  }

  void _autoNumeroAP() {
    final n = math.Random().nextInt(100).toString().padLeft(2, '0');
    setState(() {
      _apCtrl.text = n;
      _errorNumeroAP = null;
    });
  }

  void _autoNumeroIC() {
    final n = math.Random().nextInt(1000).toString().padLeft(3, '0');
    setState(() {
      _icCtrl.text = n;
      _errorNumeroIC = null;
    });
  }

  bool _validateCurrentLine() {
    bool ok = true;
    setState(() {
      _errorValor = _valor == null ? 'Selecciona el valor de la apuesta' : null;
      _errorLoteriaAP = _loteriaAPIdx == null ? 'Selecciona una lotería para tu apuesta principal' : null;
      final ap = _apCtrl.text.trim();
      _errorNumeroAP = ap.isEmpty || ap.length != 2 ? 'El número debe tener exactamente 2 cifras' : null;
      _errorLoteriaIC = _loteriaICIdx == null ? 'Selecciona una lotería para el incentivo' : null;
      final ic = _icCtrl.text.trim();
      _errorNumeroIC = ic.isEmpty || ic.length != 3 ? 'El número debe tener exactamente 3 cifras' : null;
      if (_loteriaAPIdx != null && _loteriaICIdx != null && _loteriaAPIdx == _loteriaICIdx) {
        _errorMismaLoteria = 'La lotería del incentivo debe ser diferente a la de la apuesta principal';
      } else {
        _errorMismaLoteria = null;
      }
      ok = _errorValor == null &&
          _errorLoteriaAP == null &&
          _errorNumeroAP == null &&
          _errorLoteriaIC == null &&
          _errorNumeroIC == null &&
          _errorMismaLoteria == null;
    });
    return ok;
  }

  void _agregarLinea() {
    if (!_validateCurrentLine()) return;
    setState(() {
      _betLines.add(_BetLine(
        fechaIdx: _selectedFechaIdx,
        valor: _valor!,
        loteriaAPIdx: _loteriaAPIdx!,
        numeroAP: _apCtrl.text.trim(),
        loteriaICIdx: _loteriaICIdx!,
        numeroIC: _icCtrl.text.trim(),
      ),);
      // Limpia formulario para nueva línea, preservando fecha y valor
      _loteriaAPIdx = null;
      _loteriaICIdx = null;
      _apCtrl.clear();
      _icCtrl.clear();
      _errorValor = null;
      _errorLoteriaAP = null;
      _errorNumeroAP = null;
      _errorLoteriaIC = null;
      _errorNumeroIC = null;
      _errorMismaLoteria = null;
    });
  }

  void _confirmarYPagar() {
    if (_betLines.isEmpty) {
      if (!_validateCurrentLine()) return;
      _agregarLinea();
    }
    setState(() => _finalConfirmed = true);
  }

  void _resetearFormulario() {
    setState(() {
      _selectedFechaIdx = 0;
      _valor = null;
      _loteriaAPIdx = null;
      _loteriaICIdx = null;
      _apCtrl.clear();
      _icCtrl.clear();
      _betLines.clear();
      _finalConfirmed = false;
      _errorValor = null;
      _errorLoteriaAP = null;
      _errorNumeroAP = null;
      _errorLoteriaIC = null;
      _errorNumeroIC = null;
      _errorMismaLoteria = null;
    });
  }

  bool get _lineaActualValida =>
      _valor != null &&
      _loteriaAPIdx != null &&
      _apCtrl.text.trim().length == 2 &&
      _loteriaICIdx != null &&
      _icCtrl.text.trim().length == 3 &&
      _loteriaAPIdx != _loteriaICIdx;

  // ── Bottom nav bar móvil (Figma Frame 3) ─────────────────────────────────

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
          _NavIcon(icon: Icons.home_outlined, label: 'Inicio',
              onTap: () => context.go(AppRoutes.home)),
          _NavIcon(icon: Icons.sports_esports_outlined, label: 'Juegos',
              isActive: true, onTap: () => context.go(AppRoutes.juegos)),
          _NavIcon(icon: Icons.shopping_cart_outlined, label: 'Carrito',
              onTap: () {}),
          _NavIcon(icon: Icons.person_outline, label: 'Perfil',
              onTap: () {}),
        ],
      ),
    );
  }

  // ── Auth modal ────────────────────────────────────────────────────────────

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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                      _buildContent(isMobile),
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
                  AppAssets.juegoPataMillonaria,
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
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en Pata Millonaria.',
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

    if (_finalConfirmed) {
      return Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildConfirmacionFinal(),
          ),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _buildFormCard(),
              if (_betLines.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildResumenCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Card principal del formulario ─────────────────────────────────────────

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
          _buildTituloForm(),
          const SizedBox(height: 20),
          _buildStep1Fecha(),
          const SizedBox(height: 20),
          const _Divider(),
          const SizedBox(height: 16),
          _buildStep2AP(),
          const SizedBox(height: 16),
          const _Divider(),
          const SizedBox(height: 16),
          _buildStep3IC(),
          const SizedBox(height: 24),
          _buildBotonesAccion(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.bannerPataMillonaria,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => Container(
          height: 140,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2C2E6F), Color(0xFFC7B322)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'PATA\nMILLONARIA',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTituloForm() {
    return Center(
      child: Text(
        'Sigue los pasos para realizar tu chance',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C2E6F),
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Paso 1: Fecha ─────────────────────────────────────────────────────────

  Widget _buildStep1Fecha() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepLabel(numero: '1', texto: 'Elige el día en que juegas tu apuesta'),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < _fechas.length; i++) ...[
                _FechaChip(
                  label: _labelFecha(_fechas[i], i),
                  isSelected: _selectedFechaIdx == i,
                  onTap: () => setState(() => _selectedFechaIdx = i),
                ),
                if (i < _fechas.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Paso 2: Apuesta Principal ─────────────────────────────────────────────

  Widget _buildStep2AP() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepLabel(numero: '2', texto: 'Combina tu apuesta principal'),
        const SizedBox(height: 14),

        // Valor de la apuesta
        Text(
          'Valor de la apuesta',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _ValorApuesta.values.map((v) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ValorChip(
              label: _fmtCop(v.amount),
              isSelected: _valor == v,
              onTap: () => setState(() {
                _valor = v;
                _errorValor = null;
              }),
            ),
          ),).toList(),
        ),
        if (_errorValor != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorValor!),
        ],
        const SizedBox(height: 16),

        // Lotería AP
        Text(
          'Selecciona la lotería de tu apuesta',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        _LoteriaGrid(
          selectedIdx: _loteriaAPIdx,
          disabledIdx: null,
          onSelect: (i) => setState(() {
            _loteriaAPIdx = i;
            _errorLoteriaAP = null;
            _errorMismaLoteria = null;
          }),
        ),
        if (_errorLoteriaAP != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorLoteriaAP!),
        ],
        const SizedBox(height: 14),

        // Número AP (2 cifras)
        Row(
          children: [
            Expanded(
              child: _NumeroInput(
                controller: _apCtrl,
                maxLength: 2,
                hint: '??',
                error: _errorNumeroAP,
                onChanged: (_) => setState(() => _errorNumeroAP = null),
              ),
            ),
            const SizedBox(width: 10),
            _AutoBtn(onTap: _autoNumeroAP),
          ],
        ),
        if (_errorNumeroAP != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorNumeroAP!),
        ],
        const SizedBox(height: 10),

        // Badge 2C + valor AP
        if (_valor != null)
          _CifrasBadge(
            cifras: '2C',
            valor: _fmtCop(_valor!.apValor),
            numero: _apCtrl.text.trim(),
          ),
      ],
    );
  }

  // ── Paso 3: Incentivo con Cobro ───────────────────────────────────────────

  Widget _buildStep3IC() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepLabel(numero: '3', texto: 'Combinación de incentivo'),
        const SizedBox(height: 14),

        // Lotería IC
        Text(
          'Selecciona la lotería del incentivo',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 8),
        _LoteriaGrid(
          selectedIdx: _loteriaICIdx,
          disabledIdx: _loteriaAPIdx,
          onSelect: (i) => setState(() {
            _loteriaICIdx = i;
            _errorLoteriaIC = null;
            _errorMismaLoteria = null;
          }),
        ),
        if (_errorLoteriaIC != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorLoteriaIC!),
        ],
        if (_errorMismaLoteria != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorMismaLoteria!),
        ],
        const SizedBox(height: 14),

        // Número IC (3 cifras)
        Row(
          children: [
            Expanded(
              child: _NumeroInput(
                controller: _icCtrl,
                maxLength: 3,
                hint: '???',
                error: _errorNumeroIC,
                onChanged: (_) => setState(() => _errorNumeroIC = null),
              ),
            ),
            const SizedBox(width: 10),
            _AutoBtn(onTap: _autoNumeroIC),
          ],
        ),
        if (_errorNumeroIC != null) ...[
          const SizedBox(height: 4),
          _ErrorText(_errorNumeroIC!),
        ],
        const SizedBox(height: 10),

        // Badge 3C + valor IC
        if (_valor != null)
          _CifrasBadge(
            cifras: '3C',
            valor: _fmtCop(_valor!.icValor),
            numero: _icCtrl.text.trim(),
          ),
      ],
    );
  }

  // ── Botones de acción ─────────────────────────────────────────────────────

  Widget _buildBotonesAccion() {
    return Column(
      children: [
        // Agregar otra línea
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1372AE), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: _agregarLinea,
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1372AE), size: 20),
            label: Text(
              'Agregar otra línea de apuesta',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1372AE),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Confirmar y pagar
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _lineaActualValida || _betLines.isNotEmpty
                  ? const Color(0xFF43B75D)
                  : const Color(0xFFBDD7EE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 0,
            ),
            onPressed: _confirmarYPagar,
            child: Text(
              'Confirmar y pagar',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _lineaActualValida || _betLines.isNotEmpty
                    ? Colors.white
                    : const Color(0xFF6B99B9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Resumen de apuestas (tabla) ────────────────────────────────────────────

  Widget _buildResumenCard() {
    final totalAmount = _betLines.fold(0, (s, l) => s + l.valor.amount);
    final totalIva = _betLines.fold(0, (s, l) => s + l.valor.iva);

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
          Center(
            child: Text(
              'Tu apuesta',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTablaApuestas(),
          const SizedBox(height: 16),
          _buildFilaResumen('IVA incluido', _fmtCop(totalIva)),
          _buildFilaResumen('Valor apuesta', _fmtCop(totalAmount)),
          const Divider(color: Color(0xFFE5E7EB), height: 20),
          _buildFilaResumen('Total', _fmtCop(totalAmount), isBold: true),
        ],
      ),
    );
  }

  // Tabla compacta estilo Figma: cabecera No. | Lotería, filas con AP e IC
  Widget _buildTablaApuestas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFFFCC00), width: 2)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('No.',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF2C2E6F))),
              ),
              Expanded(
                child: Text('Lotería',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: const Color(0xFF2C2E6F))),
              ),
              Text('Valor apuesta',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F))),
            ],
          ),
        ),
        // Filas
        for (int i = 0; i < _betLines.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: i.isOdd ? const Color(0xFFF9FAFB) : Colors.white,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C2E6F))),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12,
                              color: const Color(0xFF374151)),
                          children: [
                            const TextSpan(text: 'AP '),
                            TextSpan(
                              text: _betLines[i].numeroAP,
                              style: const TextStyle(
                                  color: Color(0xFFFFCC00),
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: '  ${_kLoteriaData[_betLines[i].loteriaAPIdx].name.replaceAll('\n', ' ')}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12,
                              color: const Color(0xFF374151)),
                          children: [
                            const TextSpan(text: 'IC '),
                            TextSpan(
                              text: _betLines[i].numeroIC,
                              style: const TextStyle(
                                  color: Color(0xFFFFCC00),
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: '  ${_kLoteriaData[_betLines[i].loteriaICIdx].name.replaceAll('\n', ' ')}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtCop(_betLines[i].valor.amount),
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilaResumen(String label, String value, {bool isBold = false}) {
    final style = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      color: isBold ? const Color(0xFF2C2E6F) : const Color(0xFF4B5563),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  // ── Confirmación final ────────────────────────────────────────────────────

  Widget _buildConfirmacionFinal() {
    final lines = _betLines;
    final totalAmount = lines.fold(0, (s, l) => s + l.valor.amount);
    final totalIva = lines.fold(0, (s, l) => s + l.valor.iva);
    final primerValor = lines.isNotEmpty ? lines.first.valor : null;

    return Column(
      children: [
        // Card "Así va tu juego"
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
                  'Así va tu juego',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C2E6F),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tabla de apuestas
              _buildTablaApuestas(),
              const SizedBox(height: 16),

              // Resumen de pago
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFilaResumen('IVA incluido', _fmtCop(totalIva)),
                    _buildFilaResumen('Valor apuesta', _fmtCop(totalAmount)),
                    const Divider(height: 16, color: Color(0xFFE5E7EB)),
                    _buildFilaResumen('Total a pagar', _fmtCop(totalAmount), isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Botón confirmar (éxito)
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
                    const Icon(Icons.check_circle, color: Color(0xFF43B75D), size: 36),
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
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resetearFormulario,
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

        // Plan de premios
        if (primerValor != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildPlanPremios(primerValor),
          ),
      ],
    );
  }

  // ── Plan de premios — tabla horizontal azul (Figma Frame 3) ─────────────

  Widget _buildPlanPremios(_ValorApuesta valor) {
    final premios = [
      (titulo: 'Premio\noportunidad 1', valor: _fmtCop(_premioOp1(valor.apValor))),
      (titulo: 'Premio\noportunidad 2', valor: _fmtCop(_premioOp2(valor.icValor))),
      (titulo: 'Premio\nmayor', valor: _fmtCop(_premioMayor(valor.icValor))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Plan de premios',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C2E6F),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1A2E6E),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // Cabecera
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF3A4E8E), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    for (final p in premios)
                      Expanded(
                        child: Text(
                          p.titulo,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Valores
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    for (int i = 0; i < premios.length; i++) ...[
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            premios[i].valor,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFFE30C),
                            ),
                          ),
                        ),
                      ),
                      if (i < premios.length - 1)
                        Container(
                          width: 1,
                          height: 30,
                          color: const Color(0xFF3A4E8E),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '* Premios calculados sin IVA (× 19/119).',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF9CA3AF),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Divider(
    color: Color(0xFFE5E7EB),
    height: 1,
    thickness: 1,
  );
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.numero, required this.texto});
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
            color: Color(0xFF1372AE),
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
              color: const Color(0xFF2C2E6F),
            ),
          ),
        ),
      ],
    );
  }
}

class _FechaChip extends StatelessWidget {
  const _FechaChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFECA0C) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFECA0C) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [const BoxShadow(color: Color(0x30FECA0C), blurRadius: 6, offset: Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1372AE) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFECA0C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFECA0C) : const Color(0xFFD1D5DB),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x30FECA0C),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1372AE) : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _LoteriaGrid extends StatelessWidget {
  const _LoteriaGrid({
    required this.selectedIdx,
    required this.disabledIdx,
    required this.onSelect,
  });
  final int? selectedIdx;
  final int? disabledIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        const gap = 6.0;
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
                  onTap: disabledIdx == i ? null : () => onSelect(i),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.35 : 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
                        color: const Color(0xFFFFCC00).withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 1),
                  child: Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported_outlined,
                      color: Color(0xFFD1D5DB),
                      size: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F5886),
                      height: 1.1,
                    ),
                  ),
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

class _NumeroInput extends StatelessWidget {
  const _NumeroInput({
    required this.controller,
    required this.maxLength,
    required this.hint,
    required this.error,
    required this.onChanged,
  });
  final TextEditingController controller;
  final int maxLength;
  final String hint;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: error != null ? AppColors.error : const Color(0xFFD1D5DB),
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            offset: Offset(0, 2),
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
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C2E6F),
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 24,
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

class _AutoBtn extends StatelessWidget {
  const _AutoBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, size: 18, color: Color(0xFF1372AE)),
            const SizedBox(width: 6),
            Text(
              'Auto',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1372AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CifrasBadge extends StatelessWidget {
  const _CifrasBadge({
    required this.cifras,
    required this.valor,
    required this.numero,
  });
  final String cifras;
  final String valor;
  final String numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFECA0C),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cifras,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1372AE),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            numero.isEmpty ? '?' * cifras.length : numero,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF374151),
            ),
          ),
          const Spacer(),
          Text(
            valor,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1372AE),
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
      style: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.error,
      ),
    );
  }
}

class _PremioCard extends StatelessWidget {
  const _PremioCard({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.color,
    this.isDestacado = false,
  });
  final String titulo;
  final String subtitulo;
  final String valor;
  final Color color;
  final bool isDestacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDestacado ? 18 : 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDestacado
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            titulo,
            style: GoogleFonts.inter(
              fontSize: isDestacado ? 14 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: GoogleFonts.inter(
                fontSize: isDestacado ? 28 : 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFE30C),
                shadows: const [
                  Shadow(
                    color: Color(0x60FFCC00),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
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

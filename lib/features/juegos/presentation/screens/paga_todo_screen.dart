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

// ── Modelos ───────────────────────────────────────────────────────────────────

enum _Modalidad { tresC, cuatroC }

extension _ModalidadX on _Modalidad {
  int get digits => this == _Modalidad.tresC ? 3 : 4;
  String get cifraTag => this == _Modalidad.tresC ? '3C' : '4C';
}

// Valores fijos habilitados según levantamiento funcional (HU-PAG001 §Reglas)
// Valores de resolución: $1.600, $2.000, $2.500, $3.000, $4.000 y $5.000
// Levantamiento actual: $2.500, $3.000, $4.000 y $5.000
const _kValoresHabilitados = <int>[2500, 3000, 4000, 5000];

// ── Datos de loterías — mismas que Chance Tradicional (Figma: 14 loterías) ───
// Fila 1: Risaralda, Meta, Quindío, Cauca, Medellín, Extra Medellín, Manizales
// Fila 2: Cundinamarca, Boyacá, Bogotá, Valle, Tolima, Huila, Santander

const _kLoteriaData = <({String name, String asset})>[
  (name: 'Lotería del\nRisaralda',     asset: AppAssets.logoRisaralda),
  (name: 'Lotería del\nMeta',          asset: AppAssets.logoLoteriaMeta),
  (name: 'Lotería del\nQuindío',       asset: AppAssets.logoLoteriaQuindio),
  (name: 'Lotería del\nCauca',         asset: AppAssets.logoLoteriaCauca),
  (name: 'Lotería de\nMedellín',       asset: AppAssets.logoLoteriaMedellin),
  (name: 'Extra Lotería\nde Medellín', asset: AppAssets.logoLoteriaExtraMedellin),
  (name: 'Lotería de\nManizales',      asset: AppAssets.logoLoteriaManizales),
  (name: 'Lotería de\nCundinamarca',   asset: AppAssets.logoLoteriaCundinamarca),
  (name: 'Lotería de\nBoyacá',         asset: AppAssets.logoLoteriaBoyaca),
  (name: 'Lotería de\nBogotá',         asset: AppAssets.logoLoteriaBogota),
  (name: 'Lotería del\nValle',         asset: AppAssets.logoValle),
  (name: 'Lotería del\nTolima',        asset: AppAssets.logoLoteriaTolima),
  (name: 'Lotería del\nHuila',         asset: AppAssets.logoLoteriaHuila),
  (name: 'Lotería de\nSantander',      asset: AppAssets.logoLoteriaSantander),
];

class _BetLine {
  const _BetLine({
    required this.modalidad,
    required this.numero,
    required this.loteria,
    required this.valor,
  });
  final _Modalidad modalidad;
  final String numero;
  final int loteria; // índice en _kLoteriaData
  final int valor;

  // IVA incluido en el valor — IVA = valor * 19/119
  int get iva => (valor * 19 / 119).round();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PagaTodoScreen extends StatefulWidget {
  const PagaTodoScreen({super.key});

  @override
  State<PagaTodoScreen> createState() => _PagaTodoScreenState();
}

class _PagaTodoScreenState extends State<PagaTodoScreen> {
  _Modalidad _modalidad = _Modalidad.cuatroC;
  final _numeroCtrl = TextEditingController();
  int? _selectedValor;
  final Set<int> _selectedLoterias = {};
  final List<_BetLine> _lines = [];
  String? _fieldError;
  bool _confirmed = false;

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  void _autoNumero() {
    final max = math.pow(10, _modalidad.digits).toInt() - 1;
    final rand = math.Random().nextInt(max + 1);
    _numeroCtrl.text = rand.toString().padLeft(_modalidad.digits, '0');
    setState(() => _fieldError = null);
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    if (n.isEmpty || n.length != _modalidad.digits) {
      setState(() =>
          _fieldError = 'El número debe tener exactamente ${_modalidad.digits} cifras');
      return false;
    }
    if (_selectedValor == null) {
      setState(() => _fieldError = 'Selecciona un valor para la apuesta');
      return false;
    }
    if (_selectedLoterias.isEmpty) {
      setState(() => _fieldError = 'Selecciona al menos una lotería');
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  void _addLine() {
    if (!_validate()) return;
    setState(() {
      for (final idx in _selectedLoterias) {
        _lines.add(_BetLine(
          modalidad: _modalidad,
          numero: _numeroCtrl.text.trim(),
          loteria: idx,
          valor: _selectedValor!,
        ));
      }
      _numeroCtrl.clear();
      _selectedLoterias.clear();
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  int get _totalValor => _lines.fold(0, (s, l) => s + l.valor);
  int get _totalIva => _lines.fold(0, (s, l) => s + l.iva);

  // Premio máximo potencial — parametrizable (reemplazar por tabla backend)
  // Aproximación para display: 4C × 3000x, 3C × 650x valor neto
  int _maxPrize(int valor, _Modalidad m) {
    final neto = valor - (valor * 19 / 119).round();
    return m == _Modalidad.cuatroC ? (neto * 3000) : (neto * 650);
  }

  int get _maxPrizeDisplay {
    if (_lines.isEmpty) return 0;
    return _lines
        .map((l) => _maxPrize(l.valor, l.modalidad))
        .reduce((a, b) => a > b ? a : b);
  }

  // Si hay valor seleccionado pero aún no se agregaron líneas, mostrar preview
  int get _previewPrize {
    if (_selectedValor == null) return 0;
    return _maxPrize(_selectedValor!, _modalidad);
  }

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

  static String _fmtValor(int v) {
    final s = v.toString();
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

  // ── Auth required ──────────────────────────────────────────────────────────

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
                  AppAssets.juegoImg3,
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
                'Debes estar autenticado para realizar apuestas en Paga Todo.',
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

  // ── Contenido principal ────────────────────────────────────────────────────

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
                constraints: const BoxConstraints(maxWidth: 779),
                child: _buildLeftCard(isDesktop),
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 779),
                child: _buildRightCard(isDesktop),
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
          _buildRightCard(isDesktop),
        ],
      ),
    );
  }

  // ── Left card ──────────────────────────────────────────────────────────────

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

          Center(
            child: Text(
              'Sigue los pasos para realizar tu apuesta',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
                height: 28 / 22,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          _buildStep1(isDesktop),
          const SizedBox(height: 16),

          _buildStep2(),
          const SizedBox(height: 16),

          _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.juegoImg3,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1372AE), Color(0xFFFFCC00)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'PAGA TODO',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Paso 1: modalidad + número
  Widget _buildStep1(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '1. Elige la cantidad de cifras e ingresa tu número.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
              height: 24 / 16,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Automático chip
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _AutomaticoBtn(onTap: _autoNumero),
        ),
        const SizedBox(height: 12),

        // Layout: botones de cifras + input
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModalidadButtons(
                    selected: _modalidad,
                    onSelect: (m) => setState(() {
                      _modalidad = m;
                      _fieldError = null;
                      _numeroCtrl.clear();
                    }),
                  ),
                  const SizedBox(width: 24),
                  Expanded(child: _buildNumberInput()),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModalidadButtons(
                    selected: _modalidad,
                    onSelect: (m) => setState(() {
                      _modalidad = m;
                      _fieldError = null;
                      _numeroCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildNumberInput(),
                ],
              ),
      ],
    );
  }

  Widget _buildNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            'Ingresa tu número',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
              height: 24 / 14,
            ),
          ),
        ),
        const SizedBox(height: 8),

        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _fieldError != null
                  ? AppColors.error
                  : const Color(0xFFD1D5DB),
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
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _modalidad.digits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
            ),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '?',
              hintStyle: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4B5563),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (_) => setState(() => _fieldError = null),
          ),
        ),

        if (_fieldError != null) ...[
          const SizedBox(height: 4),
          Text(
            _fieldError!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ],
        const SizedBox(height: 8),

        // Balotas display bar
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, 4),
                blurRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                _modalidad.cifraTag,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B5563),
                  height: 38 / 20,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(_modalidad.digits, (i) {
                final digit = _numeroCtrl.text.length > i
                    ? _numeroCtrl.text[i]
                    : '?';
                return Container(
                  width: 32,
                  height: 29,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Paso 2: selección de monto
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '2. Selecciona un monto para la apuesta.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
              height: 24 / 16,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildMontoDropdown(),
      ],
    );
  }

  Widget _buildMontoDropdown() {
    return GestureDetector(
      onTap: _showMontoSheet,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          border: Border.all(color: const Color(0xFFCFCFD1)),
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedValor != null
                    ? _fmtValor(_selectedValor!)
                    : 'Selecciona un monto',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: _selectedValor != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: _selectedValor != null
                      ? const Color(0xFF09101D)
                      : const Color(0xFF09101D).withValues(alpha: 0.5),
                  height: 24 / 16,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 24,
              color: Color(0xFF4B5563),
            ),
          ],
        ),
      ),
    );
  }

  void _showMontoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Selecciona un monto',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C2E6F),
                  ),
                ),
              ),
              const Divider(),
              for (final v in _kValoresHabilitados)
                ListTile(
                  title: Text(
                    _fmtValor(v),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _selectedValor == v
                          ? const Color(0xFF1372AE)
                          : const Color(0xFF09101D),
                    ),
                  ),
                  trailing: _selectedValor == v
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF1372AE))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedValor = v;
                      _fieldError = null;
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Paso 3: loterías
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '3. Selecciona las loterías.',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
              height: 24 / 16,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Fila 1 (índices 0–6)
        _buildLoteriaRow(0, 7),
        const SizedBox(height: 8),
        // Fila 2 (índices 7–13)
        _buildLoteriaRow(7, 14),
      ],
    );
  }

  Widget _buildLoteriaRow(int from, int to) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int i = from; i < to; i++)
          _LoteriaCard(
            name: _kLoteriaData[i].name,
            asset: _kLoteriaData[i].asset,
            isSelected: _selectedLoterias.contains(i),
            onTap: () => setState(() {
              if (_selectedLoterias.contains(i)) {
                _selectedLoterias.remove(i);
              } else {
                _selectedLoterias.add(i);
              }
              _fieldError = null;
            }),
          ),
      ],
    );
  }

  // ── Right card ─────────────────────────────────────────────────────────────

  Widget _buildRightCard(bool isDesktop) {
    final showPrize = _lines.isNotEmpty
        ? _maxPrizeDisplay
        : _previewPrize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Así va tu juego',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C2E6F),
              height: 28 / 22,
            ),
          ),
          const SizedBox(height: 16),

          // Agregar apuesta button
          GestureDetector(
            onTap: _addLine,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFECA0C),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    size: 20,
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
          const SizedBox(height: 16),

          // Resumen
          Container(
            constraints: const BoxConstraints(maxWidth: 508),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Tu apuesta',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                if (_lines.isEmpty)
                  _buildEmptyLine()
                else
                  for (int i = 0; i < _lines.length; i++)
                    _buildBetLineRow(i),

                const SizedBox(height: 8),

                _buildSummaryRow('IVA', _fmt(_totalIva)),
                _buildSummaryRow('Valor apuesta', _fmt(_totalValor)),

                const SizedBox(height: 16),

                if (_confirmed)
                  _buildConfirmSuccess()
                else
                  _buildConfirmButton(),

                const SizedBox(height: 20),

                Center(
                  child: Text(
                    'Podrías ganar hasta',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                      height: 28 / 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                _buildPrizeButton(showPrize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLine() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00)),
          bottom: BorderSide(color: Color(0xFFFFCC00)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Paga Todo',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1372AE),
            ),
          ),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              children: [
                TextSpan(
                    text: '${_modalidad.cifraTag} '),
                const TextSpan(
                  text: '????',
                  style: TextStyle(color: Color(0xFFFFCC00)),
                ),
              ],
            ),
          ),
          Text(
            '\$0',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetLineRow(int i) {
    final line = _lines[i];
    final isLast = i == _lines.length - 1;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0xFFFFCC00)),
          bottom: isLast
              ? const BorderSide(color: Color(0xFFFFCC00))
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paga Todo',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1372AE),
                  ),
                ),
                Text(
                  _kLoteriaData[line.loteria].name.replaceAll('\n', ' '),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              children: [
                TextSpan(text: '${line.modalidad.cifraTag} '),
                TextSpan(
                  text: line.numero,
                  style: const TextStyle(color: Color(0xFFFFCC00)),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                _fmtValor(line.valor),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeLine(i),
                child: const Icon(Icons.close_rounded,
                    size: 16, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final hasLines = _lines.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasLines ? const Color(0xFF43B75D) : const Color(0xFFBDD7EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: hasLines ? () => setState(() => _confirmed = true) : null,
        child: Text(
          'Confirmar y pagar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: hasLines ? Colors.white : const Color(0xFF6B99B9),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmSuccess() {
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
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF43B75D), size: 32),
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
            onPressed: () => setState(() {
              _confirmed = false;
              _lines.clear();
              _selectedLoterias.clear();
              _selectedValor = null;
              _numeroCtrl.clear();
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

  Widget _buildPrizeButton(int prize) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF155CFA),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        prize == 0 ? '\$ 0 COP' : '${_fmt(prize)} COP',
        style: GoogleFonts.inter(
          fontSize: 36,
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

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _ModalidadButtons extends StatelessWidget {
  const _ModalidadButtons({
    required this.selected,
    required this.onSelect,
  });

  final _Modalidad selected;
  final ValueChanged<_Modalidad> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ModalidadBtn(
          label: '3 Cifras',
          isSelected: selected == _Modalidad.tresC,
          onTap: () => onSelect(_Modalidad.tresC),
        ),
        const SizedBox(height: 10),
        _ModalidadBtn(
          label: '4 Cifras',
          isSelected: selected == _Modalidad.cuatroC,
          onTap: () => onSelect(_Modalidad.cuatroC),
        ),
      ],
    );
  }
}

class _ModalidadBtn extends StatelessWidget {
  const _ModalidadBtn({
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
        width: 144,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFCC00)
              : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 24 / 20,
          ),
        ),
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
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF1372AE)),
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

class _LoteriaCard extends StatelessWidget {
  const _LoteriaCard({
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
      child: Container(
        width: 87,
        height: 87,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFCC00).withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFCC00)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name.split('\n').last.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F5886),
                height: 1.1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

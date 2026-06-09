import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/login_redirect_service.dart';
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
  String get label => this == _Modalidad.tresC ? '3 Cifras' : '4 Cifras';
}

// Valores fijos habilitados según levantamiento funcional (HU-PAG001 §Reglas)
// Resolución G-000324 autoriza: $1.600, $2.000, $2.500, $3.000, $4.000, $5.000
// Levantamiento actual operativo: $2.500, $3.000, $4.000, $5.000
const _kValoresHabilitados = <int>[2500, 3000, 4000, 5000];

// Premio máximo preview cuando no hay selección (Figma: $7.250.000 COP con 4C/$5.000)
// Multiplicador: $5.000 × 1.450 = $7.250.000 — tabla oficial se recibe del backend
const _kMultiplier4C = 1450;
const _kMultiplier3C = 310;

// Logos de loterías — Figma "Loterias Juego" nodo pagatodo (87×87 c/u)
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
          _fieldError = 'Ingrese un número válido para la modalidad seleccionada');
      return false;
    }
    // Número bloqueado — el error se muestra visualmente en _buildNumberInput
    if (_isNumeroError) {
      return false;
    }
    if (_selectedValor == null) {
      setState(() => _fieldError = 'Selecciona un valor para la apuesta');
      return false;
    }
    if (_selectedLoterias.isEmpty) {
      setState(() =>
          _fieldError = 'Seleccione una lotería o sorteo para continuar');
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

  void _limpiar() {
    setState(() {
      _lines.clear();
      _numeroCtrl.clear();
      _selectedLoterias.clear();
      _selectedValor = null;
      _fieldError = null;
      _confirmed = false;
    });
  }

  int get _totalValor => _lines.fold(0, (s, l) => s + l.valor);
  int get _totalIva => _lines.fold(0, (s, l) => s + l.iva);

  // Números bloqueados (quemados) por modalidad — mostrar estado de error visual
  bool get _isNumeroError {
    final n = _numeroCtrl.text;
    if (n.isEmpty) return false;
    if (_modalidad == _Modalidad.cuatroC) return n == '7896';
    return n == '789';
  }

  // Premio por cifra y valor — tabla oficial viene del backend (parametrizable)
  int _maxPrize(int valor, _Modalidad m) {
    return m == _Modalidad.cuatroC
        ? (valor * _kMultiplier4C)
        : (valor * _kMultiplier3C);
  }

  int get _maxPrizeDisplay {
    if (_lines.isEmpty) return 0;
    return _lines
        .map((l) => _maxPrize(l.valor, l.modalidad))
        .reduce((a, b) => a > b ? a : b);
  }

  // Preview: si hay líneas usar su máximo; si no, mostrar el máximo posible
  // para la modalidad activa (Figma muestra $7.250.000 = 4C × $5.000 × 1450)
  int get _prizeForDisplay {
    if (_lines.isNotEmpty) return _maxPrizeDisplay;
    return _maxPrize(_kValoresHabilitados.last, _modalidad);
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

  // ── Diálogo de confirmación (HU paso 20 / flujo A5) ───────────────────────

  void _showConfirmDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Está seguro de que desea realizar la compra?',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C2E6F),
          ),
        ),
        content: Text(
          'Total: ${_fmt(_totalValor)}\n${_lines.length} apuesta${_lines.length == 1 ? '' : 's'} Paga Todo',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: const Color(0xFF4B5563),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43B75D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Aceptar',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) setState(() => _confirmed = true);
    });
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
      LoginRedirectService.save(AppRoutes.pagaTodo);
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
                  AppAssets.juegoPagaTodo,
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
    final hasData = _lines.isNotEmpty ||
        _numeroCtrl.text.isNotEmpty ||
        _selectedValor != null ||
        _selectedLoterias.isNotEmpty;

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
          const SizedBox(height: 20),

          // Botón Limpiar (HU flujo alterno A1)
          if (hasData)
            Center(
              child: TextButton.icon(
                onPressed: _limpiar,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: Color(0xFF4B5563)),
                label: Text(
                  'Limpiar',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ),
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
          AppAssets.bannerPagaTodo,
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

        // Layout: botones de cifras (izq) + input + automático + balotas (der)
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
    final bool isError = _isNumeroError;
    final bool hasText = _numeroCtrl.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Label centrado (Figma: Poppins SemiBold 14px, #4B5563)
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'ingresa tu número',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563),
                height: 24 / 12,
              ),
            ),
          ),
        ),

        // Campo de entrada — borde rojo si número bloqueado
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: isError
                  ? const Color(0xFFDA1414)
                  : (_fieldError != null
                      ? AppColors.error
                      : const Color(0xFFD1D5DB)),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                offset: Offset(0, 2),
                blurRadius: 8,
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
              // Texto rojo cuando el número está bloqueado
              color: isError
                  ? const Color(0xFFDA1414)
                  : const Color(0xFF4B5563),
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

        // Mensaje de número bloqueado (Figma nodo 905:28673 — estado error)
        if (isError) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Te invitamos a elegir otro número',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFDA1414),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {/* TODO: mostrar panel de sugerencias */},
                child: Text(
                  'Sugerencias',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1372AE),
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF1372AE),
                  ),
                ),
              ),
            ],
          ),
        ],

        // Error de validación HU (solo cuando no es número bloqueado)
        if (!isError && _fieldError != null) ...[
          const SizedBox(height: 4),
          Text(
            _fieldError!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.error,
            ),
          ),
        ],

        // Botón Automático — entre el input y las balotas (Figma)
        const SizedBox(height: 8),
        Center(child: _AutomaticoBtn(onTap: _autoNumero)),
        const SizedBox(height: 8),

        // Balotas display bar — normal o estado de error
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
              // Tag de modalidad — rojo en error, gris en normal
              Text(
                _modalidad.cifraTag,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isError
                      ? const Color(0xFFDA1414)
                      : const Color(0xFF4B5563),
                  height: 38 / 16,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(_modalidad.digits, (i) {
                if (isError) {
                  // Estado bloqueado: balotas salmon con asterisco (Figma)
                  return Container(
                    width: 32,
                    height: 28,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCA5A5),
                      borderRadius: BorderRadius.circular(80),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '*',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDA1414),
                      ),
                    ),
                  );
                }
                // Estado normal: ? cuando vacío, dígito real cuando hay texto
                final digit =
                    hasText && i < _numeroCtrl.text.length
                        ? _numeroCtrl.text[i]
                        : '?';
                return Container(
                  width: 32,
                  height: 28,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(80),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    digit,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasText
                          ? const Color(0xFF4B5563)
                          : const Color(0xFF9CA3AF),
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

          // Botón "Agregar otra línea de apuesta"
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

                _buildPrizeButton(_prizeForDisplay),
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
                TextSpan(text: '${_modalidad.cifraTag} '),
                const TextSpan(
                  text: '????',
                  style: TextStyle(color: Color(0xFFFFCC00)),
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
                const TextSpan(text: 'Lotería '),
                const TextSpan(
                  text: '****',
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
        onPressed: hasLines ? _showConfirmDialog : null,
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
        '${_fmt(prize)} COP',
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
          label: _Modalidad.tresC.label,
          isSelected: selected == _Modalidad.tresC,
          onTap: () => onSelect(_Modalidad.tresC),
        ),
        const SizedBox(height: 10),
        _ModalidadBtn(
          label: _Modalidad.cuatroC.label,
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 24 / 14,
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
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.refreshCircular,
              width: 18,
              height: 18,
              colorFilter: const ColorFilter.mode(
                Color(0xFF1372AE),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Automático',
              style: GoogleFonts.inter(
                fontSize: 13,
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

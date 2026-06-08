import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';

// ── Modelo ──────────────────────────────────────────────────────────────────
// HU-SUP001 + Resolución G-000004:
//   Valor fijo $3.000 IVA incluido.
//   IVA = $3.000 × 19/119 = $478,99 ≈ $479  (base apostado $2.521,01 — tabla resolución).
//   Premio = $2.521,01 × $5.206,25 = $13.125.000 (tabla resolución).
//   La resolución es fuente definitiva; el Figma muestra $460/$10.005 como placeholders.

class _BetLine {
  const _BetLine({required this.numero, required this.sorteo});

  final String numero;
  final String sorteo; // nombre del sorteo asociado a esta línea (HU paso 7)

  static const int betValue   = 3000;
  static const int ivaValue   = 479;
  static const int prizeValue = 13125000;
  static const int maxDigits  = 4;
}

// Sorteo activo para Superwin en esta campaña (Resolución G-000004 / Figma node "image 1").
// En producción vendría del backend; la HU permite cualquier lotería/sorteo activo del día.
const _kSorteoActivo     = 'Chontico Día';
const _kSorteoCorto      = 'Chont.día';

// TODO(backend): reemplazar por endpoint real cuando esté disponible.
// Mock temporal: '1111' simula un número cancelado/no disponible en Superwin.
const _kNumerosBloqueadosSW = {'1111'};
// Sugerencias de 4 cifras — se excluyen automáticamente los bloqueados.
const _kSugerencias4 = <String>[
  '7582', '6582', '7482', '7592', '8582', '7692',
  '9392', '1392', '2472', '1582', '3582', '2582',
];

// Métodos de pago disponibles en el resumen de transacción (Figma node 844:12490)
enum _MetodoPagoSW { billetera, pse }

// Formateador de moneda compartido en el archivo (antes static en el State).
String _fmtSW(int amount) {
  final s = amount.toString();
  final buf = StringBuffer(r'$');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ── Screen ──────────────────────────────────────────────────────────────────

class SuperwinScreen extends StatefulWidget {
  const SuperwinScreen({super.key});

  @override
  State<SuperwinScreen> createState() => _SuperwinScreenState();
}

class _SuperwinScreenState extends State<SuperwinScreen> {
  final _numeroCtrl = TextEditingController();
  final List<_BetLine> _lines = [];
  String? _fieldError;
  bool _confirmed = false;

  // TODO(backend): reemplazar por llamada real al API cuando esté disponible.
  static bool _isNumberUnavailable(String n) =>
      _kNumerosBloqueadosSW.contains(n);

  bool get _currentIsBlocked {
    final n = _numeroCtrl.text.trim();
    return n.length == _BetLine.maxDigits && _isNumberUnavailable(n);
  }

  bool get _currentIsValid {
    final n = _numeroCtrl.text.trim();
    return n.length == _BetLine.maxDigits && !_isNumberUnavailable(n);
  }

  int get _effectiveLinesCount => _lines.length + (_currentIsValid ? 1 : 0);

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  // ── Lógica ──────────────────────────────────────────────────────────────

  void _autoNumero() {
    String n;
    do {
      n = math.Random().nextInt(10000).toString().padLeft(4, '0');
    } while (_isNumberUnavailable(n));
    _numeroCtrl.text = n;
    setState(() => _fieldError = null);
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    // E1: número incompleto o inválido (HU excepción E1)
    if (n.length != _BetLine.maxDigits) {
      setState(() => _fieldError = 'Ingrese un número válido de cuatro cifras');
      return false;
    }
    // TODO(backend): reemplazar por llamada real al API cuando esté disponible.
    if (_isNumberUnavailable(n)) {
      setState(() => _fieldError = null); // el estado visual se maneja via _currentIsBlocked
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
          numero: _numeroCtrl.text.trim(),
          sorteo: _kSorteoActivo,
        ),
      );
      _numeroCtrl.clear();
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  // A1: limpiar todos los datos y apuestas no confirmadas (HU flujo alterno A1)
  void _limpiar() {
    setState(() {
      _numeroCtrl.clear();
      _lines.clear();
      _fieldError = null;
      _confirmed = false;
    });
  }

  void _openSugerencias(BuildContext context) {
    final sug = _kSugerencias4.where((n) => !_isNumberUnavailable(n)).toList();
    showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _SugerenciasModal(digits: 4, sugerencias: sug),
    ).then((selected) {
      if (selected == null) return;
      setState(() {
        _numeroCtrl.text = selected;
        _fieldError = null;
      });
    });
  }

  int get _totalBet  => _effectiveLinesCount * _BetLine.betValue;
  int get _totalIva  => _effectiveLinesCount * _BetLine.ivaValue;
  // Premio = igual para todas las líneas (mismo valor fijo); se muestra el mayor
  int get _maxPrize  => _effectiveLinesCount > 0 ? _BetLine.prizeValue : 0;

  static String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer(r'$');
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

  // ── Auth guard ─────────────────────────────────────────────────────────
  // HU precondición: el cliente debe estar autenticado.

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
                child: SizedBox(
                  height: 80,
                  width: 220,
                  child: Image.asset(
                    AppAssets.frameSuperwin,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Chance\nSUPERWIN',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFFFD700),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicia sesión para jugar',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary700,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en Superwin.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.grey600,
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

  // ── Build ──────────────────────────────────────────────────────────────

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

  // ── Left card ──────────────────────────────────────────────────────────
  // Figma node 844:11903 — bg white, rounded-30, gap-16, p-20

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
          // Banner — Figma node 867:16081, 736×148, object-contain
          _buildBanner(),
          const SizedBox(height: 16),

          // Título — Figma: Inter Bold 22px #2C2E6F, centrado
          Center(
            child: Text(
              'Sigue los pasos para realizar tu tiraje',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.primary700,
                height: 28 / 22,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Descripción — Figma node 844:11907, Inter Regular 16px #4B5563
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Superwin juega 1 número de 4 cifras por solo \$3.000 e incluye 1 tiraje, se jugará con:',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.grey600,
                height: 24 / 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Imagen del sorteo activo — Figma node 867:16215, 150×81, object-cover
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 150,
                height: 81,
                child: Image.asset(
                  AppAssets.imagenSuperwin,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1372AE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Chontico\nDía',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Paso 2 — Figma: ordered list start=2 (paso 1 implícito = sorteo mostrado arriba)
          _buildStep2(isDesktop),
        ],
      ),
    );
  }

  // Banner — Figma node 867:16081: h=148px, object-contain, radius 16
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 148,
        child: Image.asset(
          AppAssets.frameSuperwin,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            height: 148,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Chance\nSUPERWIN',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFD700),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // Paso 2 — Figma: "2. Ingresa un número de 4 cifras" + Automático + input + barra + botones
  Widget _buildStep2(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '2. Ingresa un número de 4 cifras',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.grey600,
            ),
          ),
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _AutomaticoBtn(onTap: _autoNumero),
        ),
        const SizedBox(height: 12),

        Center(child: _buildNumberSection()),
      ],
    );
  }

  // Bloque de número — Figma node 867:20315, maxWidth 421px
  Widget _buildNumberSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 421),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "ingresa tu número" — Figma: Poppins SemiBold 14px #4B5563
          Text(
            'ingresa tu número',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.grey600,
              height: 24 / 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Input — Figma: 421×45, radius 14, borde #D1D5DB, sombra
          Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: (_fieldError != null || _currentIsBlocked)
                    ? AppColors.error
                    : AppColors.inputBorder,
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
              maxLength: _BetLine.maxDigits,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _currentIsBlocked ? AppColors.error : AppColors.grey600,
              ),
              decoration: InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '?',
                hintStyle: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.grey600,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: (_) => setState(() {
                if (!_currentIsBlocked) _fieldError = null;
              }),
            ),
          ),

          if (_currentIsBlocked) ...[
            const SizedBox(height: 4),
            Builder(
              builder: (ctx) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Te invitamos a elegir otro número  ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _openSugerencias(ctx),
                    child: Text(
                      'Sugerencias',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary500,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.secondary500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_fieldError != null) ...[
            const SizedBox(height: 4),
            Text(
              _fieldError!,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),

          // Barra gris — Figma node I867:20315;867:16232: 421×44, bg #F0F0F0, radius 8
          _buildDigitDisplayRow(),
          const SizedBox(height: 12),

          // Botones agregar / limpiar
          _buildLineActions(),
        ],
      ),
    );
  }

  // "4C [?][?][?][?] $3.000" — Figma node I867:20315;867:16232
  Widget _buildDigitDisplayRow() {
    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '4C',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.grey600,
              height: 38 / 20,
            ),
          ),
          const SizedBox(width: 8),
          for (int i = 0; i < 4; i++) ...[
            _DigitBall(
              digit: _currentIsBlocked
                  ? '*'
                  : (i < _numeroCtrl.text.length ? _numeroCtrl.text[i] : '?'),
              isError: _currentIsBlocked,
            ),
            if (i < 3) const SizedBox(width: 5),
          ],
          const SizedBox(width: 8),
          Text(
            '\$3.000',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.grey600,
              height: 38 / 20,
            ),
          ),
        ],
      ),
    );
  }

  // Botón "Agregar otra línea de apuesta" — Figma node 1207:15655
  // El botón "Limpiar" no aparece en Figma; se omite visualmente.
  // La función _limpiar() permanece para el flujo de éxito ("Realizar otra apuesta").
  Widget _buildLineActions() {
    return GestureDetector(
      onTap: _addLine,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(4),
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
                color: AppColors.secondary500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Right card ─────────────────────────────────────────────────────────
  // Figma node 844:11920 — bg white, rounded-30, p-20

  Widget _buildRightCard() {
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
          // Título — Figma: Inter Bold 22px #2C2E6F
          Text(
            'Así va tu juego',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.primary700,
              height: 28 / 22,
            ),
          ),
          const SizedBox(height: 16),

          // ResumenDeApuesta — Figma node 867:20426
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Tu apuesta" — Figma node 867:20408, Poppins SemiBold 14px #4B5563
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Tu apuesta',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Filas de apuesta — muestra preview automático cuando número es válido
                if (_lines.isEmpty && !_currentIsValid)
                  _buildEmptyLine()
                else ...[
                  for (int i = 0; i < _lines.length; i++)
                    _buildBetLineRow(i),
                  if (_currentIsValid)
                    _buildPreviewLine(_lines.length),
                ],

                const SizedBox(height: 8),

                // IVA y valor apuesta — Figma nodes 867:20414-20419
                _buildSummaryRow('IVA', _fmt(_totalIva)),
                _buildSummaryRow('Valor apuesta', _fmt(_totalBet)),

                const SizedBox(height: 16),

                // Botón confirmar o estado éxito
                if (_confirmed)
                  _buildConfirmSuccess()
                else
                  _buildConfirmButton(),

                const SizedBox(height: 20),

                // "Podrías ganar hasta" — Figma: Inter Bold 22px #1372AE
                Center(
                  child: Text(
                    'Podrías ganar hasta',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondary500,
                      height: 28 / 22,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Bloque azul del premio — Figma node 867:20423, 492×80, bg #1450EF
                _buildPrizeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fila vacía placeholder — Figma node 867:20409: borde amarillo top+bottom
  Widget _buildEmptyLine() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
            'Línea 1',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary500,
            ),
          ),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              children: const [
                TextSpan(text: '4c  '),
                TextSpan(
                  text: '????',
                  style: TextStyle(color: Color(0xFFFFCC00)),
                ),
                TextSpan(text: '  Lotería '),
                TextSpan(
                  text: _kSorteoCorto,
                  style: TextStyle(color: Color(0xFFFFCC00)),
                ),
              ],
            ),
          ),
          Text(
            '\$3.000',
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

  // Fila de apuesta confirmada — muestra sorteo real de la línea (HU paso 14)
  Widget _buildBetLineRow(int i) {
    final line = _lines[i];
    // Abreviatura del sorteo de la línea
    final sorteoCorto = line.sorteo == _kSorteoActivo
        ? _kSorteoCorto
        : line.sorteo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0xFFFFCC00)),
          bottom: i == _lines.length - 1
              ? const BorderSide(color: Color(0xFFFFCC00))
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Línea ${i + 1}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary500,
            ),
          ),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                children: [
                  const TextSpan(text: '4c  '),
                  TextSpan(
                    text: line.numero,
                    style: const TextStyle(color: Color(0xFFFFCC00)),
                  ),
                  const TextSpan(text: '  Lotería '),
                  TextSpan(
                    text: sorteoCorto,
                    style: const TextStyle(color: Color(0xFFFFCC00)),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\$3.000',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              // A4: el usuario puede eliminar apuestas antes de confirmar (HU alterno A4)
              GestureDetector(
                onTap: () => _removeLine(i),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Línea preview — aparece automáticamente cuando el número es válido (4 cifras, no bloqueado)
  Widget _buildPreviewLine(int index) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          top: const BorderSide(color: Color(0xFFFFCC00)),
          bottom: index == _lines.length
              ? const BorderSide(color: Color(0xFFFFCC00))
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Línea ${index + 1}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary500,
            ),
          ),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                children: [
                  const TextSpan(text: '4c  '),
                  TextSpan(
                    text: _numeroCtrl.text.trim(),
                    style: const TextStyle(color: Color(0xFFFFCC00)),
                  ),
                  const TextSpan(text: '  Lotería '),
                  const TextSpan(
                    text: _kSorteoCorto,
                    style: TextStyle(color: Color(0xFFFFCC00)),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '\$3.000',
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

  // Fila IVA / Valor apuesta — Figma nodes 867:20414-20419
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.grey600,
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

  // Botón "Confirmar y pagar" — Figma node 867:20421: 371×57, radius 26
  // Habilitado solo si hay al menos 1 línea confirmada (HU: "Continuar se habilita cuando
  // existe al menos una apuesta válida en el resumen")
  Widget _buildConfirmButton() {
    final enabled = _lines.isNotEmpty || _currentIsValid;
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF43B75D) : AppColors.buttonDisabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: enabled ? _openConfirmacionModal : null,
        child: Text(
          'Confirmar y pagar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : AppColors.buttonDisabledText,
          ),
        ),
      ),
    );
  }

  // Resumen de transacción — Figma node 844:12490
  // HU pasos 15-17: muestra resumen de compra con subtotal, IVA, total
  // y selección de método de pago antes de procesar el cobro.
  void _openConfirmacionModal() {
    // Commit la línea preview si existe (con setState para rebuild inmediato)
    if (_currentIsValid) {
      setState(() {
        _lines.add(
          _BetLine(
            numero: _numeroCtrl.text.trim(),
            sorteo: _kSorteoActivo,
          ),
        );
        _numeroCtrl.clear();
      });
    }
    // Resolución G-000004: $3.000 IVA incluido → base = $2.521, IVA = $479 por línea
    final subtotal = _lines.length * (_BetLine.betValue - _BetLine.ivaValue);
    final iva      = _lines.length * _BetLine.ivaValue;
    final total    = _lines.length * _BetLine.betValue;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ConfirmacionModalSW(
        subtotal: subtotal,
        iva: iva,
        total: total,
        // A5: cancelar cierra el modal sin registrar ni cobrar (HU alterno A5).
        // "Confirmar y pagar" llama onPagado → muestra estado de éxito en el panel.
        onPagado: () => setState(() => _confirmed = true),
      ),
    );
  }

  // Estado de éxito — HU paso 22: "La apuesta se registró con éxito"
  Widget _buildConfirmSuccess() {
    final sorteo = _lines.isNotEmpty ? _lines.first.sorteo : _kSorteoActivo;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF43B75D)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF43B75D), size: 32),
          const SizedBox(height: 8),
          Text(
            '¡La apuesta se registró con éxito!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Producto: Superwin · Lotería: $sorteo',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF2E7D32),
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

  // Bloque azul "Podrías ganar hasta" — Figma node 867:20423: 492×80, bg #1450EF
  // Muestra $13.125.000 (tabla resolución para $3.000 apostado)
  Widget _buildPrizeButton() {
    final label = _maxPrize == 0
        ? '\$ 13.125.000 COP'
        : '${_fmt(_maxPrize)} COP';
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1450EF),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
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
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

// Balotas/dígitos — Figma node 762:4670-4673: 32×29, bg #D1D5DB, radius 80
// isError=true → fondo rosa #FBCACA con texto rojo (número bloqueado)
class _DigitBall extends StatelessWidget {
  const _DigitBall({required this.digit, this.isError = false});

  final String digit;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 29,
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFBCACA) : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(80),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: isError ? AppColors.error : AppColors.grey600,
          height: 28 / 22,
        ),
      ),
    );
  }
}

// ── Sugerencias ─────────────────────────────────────────────────────────────
// Popup compacto de sugerencias de 4 cifras — mismo patrón que Chance Tradicional.
// Retorna el número seleccionado vía Navigator.pop(context, numero) o null si se cierra.

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
      backgroundColor: Colors.transparent,
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

// ── Modal Resumen de transacción ─────────────────────────────────────────────
// Figma node 844:12490 — Superwin.
// Recibe subtotal/IVA/total como ints ya calculados por el State.
// Callback onPagado: se llama cuando el usuario confirma el pago; el State
// actualiza _confirmed = true → muestra el panel de éxito en el formulario.
//
// Cálculos (HU + Resolución G-000004):
//   • subtotal = N × ($3.000 − $479) = N × $2.521  (base apostada sin IVA)
//   • iva      = N × $479             (IVA 19/119 sobre el precio IVA incluido)
//   • total    = N × $3.000           (precio final cobrado al cliente)

class _ConfirmacionModalSW extends StatefulWidget {
  const _ConfirmacionModalSW({
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.onPagado,
  });

  final int subtotal;
  final int iva;
  final int total;
  final VoidCallback onPagado;

  @override
  State<_ConfirmacionModalSW> createState() => _ConfirmacionModalSWState();
}

class _ConfirmacionModalSWState extends State<_ConfirmacionModalSW> {
  // Billetera pre-seleccionada por defecto (mismo patrón que Chance Tradicional)
  _MetodoPagoSW _metodoPago = _MetodoPagoSW.billetera;

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
                // ── Botón cerrar X — arriba a la derecha ──────────────────
                // A5 HU: cierra sin registrar ni cobrar
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

                // ── Título — Inter Bold 24px #1372AE ─────────────────────
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

                // ── Texto ñapa — Figma node 844:12498 ────────────────────
                // Texto literal de la Figma, confirmado en HU nota funcional
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

                // ── Bloque resumen de pago (Figma node 844:12499) ─────────
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Subtotal — Inter Medium 20px, Poppins SemiBold 16px negro
                      _buildResumenRow(
                        label: 'Subtotal',
                        value: _fmtSW(widget.subtotal),
                        isTotal: false,
                      ),
                      // IVA — mismo estilo que subtotal
                      _buildResumenRow(
                        label: 'IVA',
                        value: _fmtSW(widget.iva),
                        isTotal: false,
                      ),
                      // Total a pagar — centrado, Poppins Bold 16px azul #1372AE
                      _buildResumenRow(
                        label: 'Total a pagar',
                        value: _fmtSW(widget.total),
                        isTotal: true,
                      ),

                      // Separador amarillo — Figma amarillo-gane #FFCC00
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
                        value: _MetodoPagoSW.billetera,
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
                            // Chip saldo "$0" — placeholder hasta integración backend
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
                            // Botón recarga billetera — accent-500 #C7B322
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

                      // Opción 2 — PSE + Mastercard + Visa
                      _buildPaymentOption(
                        value: _MetodoPagoSW.pse,
                        content: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PseLogoWidgetSW(),
                            SizedBox(width: 8),
                            _MastercardLogoWidgetSW(),
                            SizedBox(width: 8),
                            _VisaLogoWidgetSW(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón "Confirmar y pagar" — verde #43B75D, 371×57, radius 26
                      // Habilitado cuando hay método de pago seleccionado (siempre,
                      // porque billetera es pre-selección por defecto).
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
                              // y procesar la transacción real.
                              Navigator.of(context).pop();
                              widget.onPagado();
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

                      // Separador amarillo inferior
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          color: Color(0xFFFFCC00),
                          thickness: 1,
                          height: 1,
                        ),
                      ),

                      // "Agregar otra apuesta" — cierra el modal; las líneas
                      // ya confirmadas permanecen en el resumen del formulario.
                      // HU alterno A4: el cliente puede editar/eliminar antes de pagar.
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

  // Fila de resumen: Subtotal/IVA alineados a la derecha; Total centrado en azul.
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

  // Opción de pago con radio amarillo animado y borde amarillo cuando está activa.
  Widget _buildPaymentOption({
    required _MetodoPagoSW value,
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

class _PseLogoWidgetSW extends StatelessWidget {
  const _PseLogoWidgetSW();

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

class _MastercardLogoWidgetSW extends StatelessWidget {
  const _MastercardLogoWidgetSW();

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

class _VisaLogoWidgetSW extends StatelessWidget {
  const _VisaLogoWidgetSW();

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

// Botón "Automático" — Figma node 844:11925: bg #FECA0C, h-22, radius 4
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
            SvgPicture.asset(AppAssets.refreshCircular, width: 16, height: 16),
            const SizedBox(width: 6),
            Text(
              'Automático',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

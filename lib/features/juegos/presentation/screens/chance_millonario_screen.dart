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

// ── Modelo ────────────────────────────────────────────────────────────────────
// HU-CM001: Chance Millonario — modalidad fija 4 cifras, 5 números, 2 loterías.
// Valor fijo: $6.000 IVA incluido. Acumulado mínimo: $1.000.000.000.

// Loterías disponibles — orden y assets exactos de Figma 1095:14179 y 1095:14187
// Fila 1: Risaralda, Meta, Quindío, Cauca, Medellín, Extra Medellín, Manizales
// Fila 2: Cundinamarca, Boyacá, Bogotá, Valle, Tolima, Huila, Santander
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

// HU-CM001 RN-1: valor fijo de la apuesta = $6.000 IVA incluido.
const int _kBetValue = 6000;

// IVA = monto × 19 / 119 — mismo patrón que Chance Tradicional (resolución G-000004).
// SUPUESTO: fórmula 19/119 aplicada al total de $6.000 → $958.
// El valor $579 que muestra el Figma es un placeholder estático de diseño.
const int _kIva = 958; // (6000 * 19 / 119).round()

// Acumulado vigente — parametrizable. Mínimo $1.000.000.000 (HU-CM001 RN-5).
// SUPUESTO: hardcodeado por ausencia de integración backend en este sprint.
const int _kAcumulado = 1000000000;

// ── Screen ────────────────────────────────────────────────────────────────────

class ChanceMillonarioScreen extends StatefulWidget {
  const ChanceMillonarioScreen({super.key});

  @override
  State<ChanceMillonarioScreen> createState() => _ChanceMillonarioScreenState();
}

class _ChanceMillonarioScreenState extends State<ChanceMillonarioScreen> {
  // 5 controladores para los 5 números de 4 cifras (HU-CM001 Entradas)
  final List<TextEditingController> _numCtrl =
      List.generate(5, (_) => TextEditingController());
  final List<String?> _numErrors = List.filled(5, null, growable: false);

  // Loterías seleccionadas — exactamente 2 distintas (HU-CM001 RN-2)
  final Set<int> _selectedLoterias = {};
  String? _loteriasError;

  bool _confirmed = false;

  @override
  void dispose() {
    for (final c in _numCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // Genera 5 números aleatorios de 4 cifras (Figma 1095:14172 — botón Automático)
  void _autoNumero() {
    final rand = math.Random();
    for (int i = 0; i < 5; i++) {
      _numCtrl[i].text = rand.nextInt(10000).toString().padLeft(4, '0');
    }
    setState(() {
      for (int i = 0; i < 5; i++) {
        _numErrors[i] = null;
      }
    });
  }

  // Selección de lotería — máximo 2 distintas (HU-CM001 E3)
  void _toggleLoteria(int index) {
    setState(() {
      _loteriasError = null;
      if (_selectedLoterias.contains(index)) {
        _selectedLoterias.remove(index);
      } else if (_selectedLoterias.length < 2) {
        _selectedLoterias.add(index);
      }
    });
  }

  bool _validate() {
    bool valid = true;
    for (int i = 0; i < 5; i++) {
      final n = _numCtrl[i].text.trim();
      if (n.isEmpty || n.length != 4) {
        _numErrors[i] = 'El número debe tener exactamente 4 cifras';
        valid = false;
      } else {
        _numErrors[i] = null;
      }
    }
    if (_selectedLoterias.length < 2) {
      _loteriasError =
          'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día';
      valid = false;
    } else {
      _loteriasError = null;
    }
    setState(() {});
    return valid;
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

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  bool get _canConfirm =>
      _numCtrl.every((c) => c.text.trim().length == 4) &&
      _selectedLoterias.length == 2;

  // ── Auth modal (mismo patrón que ChanceTradicionalScreen) ─────────────────

  void _showLoginModal(BuildContext ctx) {
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

  // ── Auth required (mismo patrón que ChanceTradicionalScreen) ──────────────

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
                  AppAssets.bannerChanceMillonario,
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
                'Debes estar autenticado para realizar apuestas en Chance Millonario.',
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
  // Figma 1095:14166 — 779px, white, rounded-30, padding-20

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
          _buildTitle(),
          const SizedBox(height: 16),
          _buildStep1(isDesktop),
        ],
      ),
    );
  }

  // Banner — 746×150, rounded=16, BoxFit.cover (Figma 1095:16829)
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.bannerChanceMillonario,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFFD4AF37)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'CHANCE\nMILLONARIO',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // "Sigue los pasos para realizar tu chance" — Inter Bold 22px, #2C2E6F
  Widget _buildTitle() {
    return Center(
      child: Text(
        'Sigue los pasos para realizar tu chance',
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

  // Paso 1 — selección de números (Figma 1095:14170 + 1095:16743)
  Widget _buildStep1(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "1. Elige tus número" — Inter Regular 16px, #4B5563 (Figma 1095:14171)
        Text(
          '1. Elige tus número',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 10),

        // Botón Automático — #FECA0C, h=28, rounded=4 (Figma 1095:14172)
        _AutomaticoBtn(onTap: _autoNumero),
        const SizedBox(height: 10),

        // Layout: izquierda "4 Cifras" + derecha 5 inputs
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCifrasLabel(),
                  const SizedBox(width: 40),
                  Expanded(child: _buildNumberInputsColumn()),
                ],
              )
            : Column(
                children: [
                  _buildCifrasLabel(),
                  const SizedBox(height: 12),
                  _buildNumberInputsColumn(),
                ],
              ),
      ],
    );
  }

  // Botón "4 Cifras" (estático) — 144×36, #FFCC00, rounded=14 (Figma 1095:16747)
  Widget _buildCifrasLabel() {
    return Container(
      width: 144,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFFECA0C),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '4 Cifras',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1372AE),
          height: 24 / 20,
        ),
      ),
    );
  }

  // Columna derecha — 5 pares (input + display 4C balotas) (Figma 1095:16748)
  Widget _buildNumberInputsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Ingresa 5 números de 4 cifras" — Poppins SemiBold 14px (Figma 1095:16750)
        Text(
          'Ingresa 5 números de 4 cifras',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4B5563),
            height: 24 / 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        for (int i = 0; i < 5; i++) ...[
          _buildNumberInput(i),
          if (_numErrors[i] != null) ...[
            const SizedBox(height: 2),
            Text(
              _numErrors[i]!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          _buildBalotas4C(i),
          if (i < 4) const SizedBox(height: 8),
        ],
      ],
    );
  }

  // Input field — 421×45, border grey-300, rounded=14, shadow (Figma 1095:16751)
  Widget _buildNumberInput(int index) {
    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _numErrors[index] != null
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
        controller: _numCtrl[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
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
            color: const Color(0xFF9CA3AF),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (_) => setState(() => _numErrors[index] = null),
      ),
    );
  }

  // Display "4C" + 4 balotas — 300×44, grey-100, rounded=8 (Figma 1095:16752)
  Widget _buildBalotas4C(int numIndex) {
    final text = _numCtrl[numIndex].text.trim();

    return Container(
      width: 300,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
          // "4C" — Inter Bold 20px, #4B5563 (Figma 1095:16753)
          Text(
            '4C',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 10),
          // 4 balotas — 32×29, grey-300, rounded=80 (Figma: Balotas "4c default")
          for (int d = 0; d < 4; d++) ...[
            _Balota(
              digit: d < text.length ? text[d] : '?',
              isHighlight: d < text.length,
            ),
            if (d < 3) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  // ── Right card ────────────────────────────────────────────────────────────
  // Figma 1095:14176 — 780px, white, rounded-30, padding-20

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
          // "2. Selecciona dos loterías" (Figma 1095:14178)
          Text(
            '2. Selecciona dos loterías',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),

          // Grid 7×2 de tarjetas de lotería (Figma 1095:14179 + 1095:14187)
          _buildLoteriaGrid(),

          if (_loteriasError != null) ...[
            const SizedBox(height: 6),
            Text(
              _loteriasError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // "Así va tu juego" (Figma 1095:14196)
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

          // Resumen (Figma 1095:14197)
          Container(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildResumen(),
          ),
        ],
      ),
    );
  }

  // Grid de loterías — 7 columnas, celdas 87×87, gap ~18px
  Widget _buildLoteriaGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        const sidePadding = 10.0;
        const gap = 14.0;
        final available = constraints.maxWidth - 2 * sidePadding;
        final cellW = (available - gap * (cols - 1)) / cols;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (int i = 0; i < _kLoteriaData.length; i++)
                SizedBox(
                  width: cellW,
                  height: cellW, // cuadrado, como en Figma (87×87)
                  child: _LoteriaCell(
                    name: _kLoteriaData[i].name,
                    asset: _kLoteriaData[i].asset,
                    isSelected: _selectedLoterias.contains(i),
                    onTap: () => _toggleLoteria(i),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Resumen de apuesta (Figma 1095:14197) ─────────────────────────────────

  Widget _buildResumen() {
    final lotList = _selectedLoterias.toList();
    final lot1Name = lotList.isNotEmpty
        ? _kLoteriaData[lotList[0]].name.replaceAll('\n', ' ')
        : null;
    final lot2Name = lotList.length > 1
        ? _kLoteriaData[lotList[1]].name.replaceAll('\n', ' ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Tu apuesta" — Poppins SemiBold 14px, #4B5563 (Figma I1095:14197;1035:16635)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
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

        // Fila de números — border-top #FFCC00 (Figma I1095:14197;1035:16636)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFFFCC00), width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Números',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 16),
                for (int i = 0; i < 5; i++) ...[
                  Text(
                    _numCtrl[i].text.trim().isEmpty
                        ? '????'
                        : _numCtrl[i].text.trim(),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFCC00),
                    ),
                  ),
                  if (i < 4) const SizedBox(width: 16),
                ],
              ],
            ),
          ),
        ),

        // Fila de loterías — border-bottom #FFCC00 (Figma I1095:14197;1035:16643)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFFFCC00), width: 1),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    children: [
                      const TextSpan(text: 'Lotería '),
                      TextSpan(
                        text: lot1Name ?? '****',
                        style: const TextStyle(color: Color(0xFFFFCC00)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                    children: [
                      const TextSpan(text: 'Lotería '),
                      TextSpan(
                        text: lot2Name ?? '****',
                        style: const TextStyle(color: Color(0xFFFFCC00)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _fmt(_kBetValue),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // IVA (Figma I1095:14197;1035:16647–16649)
        _buildSummaryRow('IVA', _fmt(_kIva)),

        // Valor apuesta (Figma I1095:14197;1035:16650–16652)
        _buildSummaryRow('Valor apuesta', _fmt(_kBetValue)),

        const SizedBox(height: 16),

        // Confirmar y pagar — verde #43b75d, h=57, rounded=26 (Figma)
        if (_confirmed)
          _buildConfirmSuccess(lot1Name, lot2Name)
        else
          _buildConfirmButton(),

        const SizedBox(height: 20),

        // "Acumulado pago para mutual*" (Figma I1095:14197;1035:16655)
        Center(
          child: Text(
            'Acumulado pago para mutual*',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1372AE),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Caja del acumulado — #155CFA, h=80, rounded=16 (Figma I1095:14197;1035:16657)
        _buildPrizeBox(),
      ],
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
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _canConfirm
              ? const Color(0xFF43B75D)
              : const Color(0xFFBDD7EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          elevation: 0,
        ),
        onPressed: () {
          if (_validate()) {
            setState(() => _confirmed = true);
          }
        },
        child: Text(
          'Confirmar y pagar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _canConfirm ? Colors.white : const Color(0xFF6B99B9),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmSuccess(String? lot1Name, String? lot2Name) {
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
          if (lot1Name != null && lot2Name != null)
            Text(
              'Chance Millonario · $lot1Name · $lot2Name',
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
              for (final c in _numCtrl) {
                c.clear();
              }
              _selectedLoterias.clear();
              _loteriasError = null;
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

  // Caja del acumulado — #155CFA, h=80, rounded=16 (Figma)
  Widget _buildPrizeBox() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF155CFA),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${_fmt(_kAcumulado)} COP',
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
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

// Botón Automático — h=28, #FECA0C, rounded=4 (Figma 1095:14172)
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

// Balota individual — 32×29, rounded=80, grey-300 (Figma: Balotas "4c default")
class _Balota extends StatelessWidget {
  const _Balota({required this.digit, this.isHighlight = false});

  final String digit;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 29,
      decoration: BoxDecoration(
        color: isHighlight
            ? const Color(0xFFFFCC00).withValues(alpha: 0.3)
            : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(80),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
          height: 1,
        ),
      ),
    );
  }
}

// Celda de lotería — 87×87 (mismo patrón que ChanceTradicionalScreen._LoteriaCell)
// Figma: fondo blanco, borde grey-300/amarillo, logo arriba 63%, nombre abajo
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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFCC00)
                : const Color(0xFFE5E7EB),
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

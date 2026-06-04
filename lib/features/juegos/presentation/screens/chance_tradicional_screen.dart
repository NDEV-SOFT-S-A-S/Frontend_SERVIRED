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

enum _Modalidad { unaC, dosC, tresC, cuatroC }

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
  });
  final _Modalidad modalidad;
  final String numero;
  final int monto;

  // IVA = monto * 19/119 (monto incluye IVA — resolución G-000004)
  int get iva => (monto * 19 / 119).round();
  int get prize => ((monto - iva) * modalidad.multiplier);
}

// ── Datos de loterías — orden y assets exactos de Figma ──────────────────────
// Fila 1: Risaralda, Meta, Quindío, Cauca, Medellín, Extra Medellín, Manizales
// Fila 2: Cundinamarca, Boyacá, Bogotá, Valle, Tolima, Huila, Santander

const _kLoteriaData = <({String name, String asset, String label})>[
  (name: 'Lotería del\nRisaralda',      asset: AppAssets.logoRisaralda,           label: 'Lotería del\nRisaralda'),
  (name: 'Lotería del\nMeta',           asset: AppAssets.logoLoteriaMeta,         label: 'Lotería del\nMeta'),
  (name: 'Lotería del\nQuindío',        asset: AppAssets.logoLoteriaQuindio,      label: 'Lotería del\nQuindío'),
  (name: 'Lotería del\nCauca',          asset: AppAssets.logoLoteriaCauca,        label: 'Lotería del\nCauca'),
  (name: 'Lotería de\nMedellín',        asset: AppAssets.logoLoteriaMedellin,     label: 'Lotería de\nMedellín'),
  (name: 'Extra Lotería\nde Medellín',  asset: AppAssets.logoLoteriaExtraMedellin,label: 'Extra Lotería\nde Medellín'),
  (name: 'Lotería de\nManizales',       asset: AppAssets.logoLoteriaManizales,    label: 'Lotería de\nManizales'),
  (name: 'Lotería de\nCundinamarca',    asset: AppAssets.logoLoteriaCundinamarca, label: 'Lotería de\nCundinamarca'),
  (name: 'Lotería de\nBoyacá',         asset: AppAssets.logoLoteriaBoyaca,       label: 'Lotería de\nBoyacá'),
  (name: 'Lotería de\nBogotá',         asset: AppAssets.logoLoteriaBogota,       label: 'Lotería de\nBogotá'),
  (name: 'Lotería del\nValle',          asset: AppAssets.logoValle,               label: 'Lotería del\nValle'),
  (name: 'Lotería del\nTolima',         asset: AppAssets.logoLoteriaTolima,       label: 'Lotería del\nTolima'),
  (name: 'Lotería del\nHuila',          asset: AppAssets.logoLoteriaHuila,        label: 'Lotería del\nHuila'),
  (name: 'Lotería de\nSantander',       asset: AppAssets.logoLoteriaSantander,    label: 'Lotería de\nSantander'),
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
  _Modalidad _modalidad = _Modalidad.dosC;
  final _numeroCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final Set<int> _selectedLoterias = {};
  final List<_BetLine> _lines = [];
  String? _fieldError;
  bool _confirmed = false;

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
    final max = math.pow(10, _modalidad.digits).toInt() - 1;
    final rand = math.Random().nextInt(max + 1);
    _numeroCtrl.text = rand.toString().padLeft(_modalidad.digits, '0');
    setState(() => _fieldError = null);
  }

  int get _montoValue {
    final raw = _montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(raw) ?? 0;
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    if (n.isEmpty || n.length != _modalidad.digits) {
      setState(() =>
          _fieldError = 'El número debe tener exactamente ${_modalidad.digits} cifras',);
      return false;
    }
    if (_montoValue < 3000) {
      setState(() => _fieldError = 'Monto mínimo \$3.000');
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
          modalidad: _modalidad,
          numero: _numeroCtrl.text.trim(),
          monto: _montoValue,
        ),
      );
      _numeroCtrl.clear();
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  int get _totalMonto => _lines.fold(0, (s, l) => s + l.monto);
  int get _totalIva => _lines.fold(0, (s, l) => s + l.iva);
  int get _maxPrize =>
      _lines.isEmpty ? 0 : _lines.map((l) => l.prize).reduce((a, b) => a > b ? a : b);

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

  // Paso 2 — cifras + monto
  // Figma: botones 144×36, font 20px; monto 240px; gap entre columnas 220px
  Widget _buildStep2(bool isDesktop) {
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
                  _CifrasButtons(
                    selected: _modalidad,
                    onSelect: (m) => setState(() {
                      _modalidad = m;
                      _fieldError = null;
                      _numeroCtrl.clear();
                    }),
                  ),
                  const SizedBox(width: 220),
                  _buildMontoField(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CifrasButtons(
                    selected: _modalidad,
                    onSelect: (m) => setState(() {
                      _modalidad = m;
                      _fieldError = null;
                      _numeroCtrl.clear();
                    }),
                  ),
                  const SizedBox(height: 16),
                  _buildMontoField(),
                ],
              ),
      ],
    );
  }

  // Monto de la apuesta — Figma: 240px wide, 45px tall, radius 14, shadow
  Widget _buildMontoField() {
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
              border: Border.all(color: const Color(0xFFD1D5DB)),
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
                color: const Color(0xFF4B5563),
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
                    isSelected: _selectedLoterias.contains(i),
                    onTap: () => setState(() {
                      if (_selectedLoterias.contains(i)) {
                        _selectedLoterias.remove(i);
                      } else {
                        _selectedLoterias.add(i);
                      }
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
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '4. Elige tu número',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 10),

                _AutomaticoBtn(onTap: _autoNumero),
                const SizedBox(height: 12),

                Text(
                  'ingresa tu número',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),

                _buildNumberInput(),
                const SizedBox(height: 8),

                _buildNumeroDisplay(),
                const SizedBox(height: 6),

                // "Jugar última cifra"
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'Jugar última cifra',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFCC00),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Agregar línea
                GestureDetector(
                  onTap: _addLine,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                            color: const Color(0xFF1372AE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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

                if (_lines.isEmpty)
                  _buildEmptyLine()
                else
                  for (int i = 0; i < _lines.length; i++)
                    _buildBetLineRow(i),

                const SizedBox(height: 8),

                _buildSummaryRow('IVA', _fmt(_totalIva)),
                _buildSummaryRow('Valor apuesta', _fmt(_totalMonto)),

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
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildPrizeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberInput() {
    return Container(
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
            color: const Color(0xFF9CA3AF),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (_) => setState(() => _fieldError = null),
      ),
    );
  }

  // Fila de display — Figma: [modTag][d1][d2...][monto] en contenedor gris
  Widget _buildNumeroDisplay() {
    final tag = _modalidad.cifraTag;
    final digits = _modalidad.digits;
    final numero = _numeroCtrl.text.trim();
    final monto = _montoValue;

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
          _DisplayCell(text: monto > 0 ? _fmt(monto) : '\$0'),
        ],
      ),
    );
  }

  Widget _buildEmptyLine() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1372AE),
            ),
          ),
          Text(
            '3c  ???',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            'Lotería  ****',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            '\$0',
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

  Widget _buildBetLineRow(int i) {
    final line = _lines[i];
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
        children: [
          Text(
            'Línea ${i + 1}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1372AE),
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              children: [
                TextSpan(text: '${line.modalidad.cifraTag}  '),
                TextSpan(
                  text: line.numero,
                  style: const TextStyle(color: Color(0xFFFFCC00)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _fmt(line.monto),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 6),
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
            'Chance Tradicional · ${_dayNames[d.weekday]} ${d.day} de ${_monthNames[d.month]}',
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
              _lines.clear();
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

  final _Modalidad selected;
  final ValueChanged<_Modalidad> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in _Modalidad.values) ...[
          _CifraBtn(
            label: m.label,
            isSelected: selected == m,
            onTap: () => onSelect(m),
          ),
          if (m != _Modalidad.cuatroC) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _CifraBtn extends StatelessWidget {
  const _CifraBtn({
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
          color: isSelected ? const Color(0xFFFECA0C) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isSelected ? const Color(0xFF1372AE) : Colors.white,
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

// Celda de lotería — Figma: 87×87 (cuadrado)
// Fondo: rounded-8 blanco con borde, logo arriba (~65%), nombre abajo (~27%)
// Texto: Inter SemiBold 11px, color #0F5886 (secondary-p)
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
          color: isHighlight
              ? const Color(0xFFFFCC00)
              : const Color(0xFFD1D5DB),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

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

enum _Modalidad { tresC, cuatroC }

extension _ModalidadX on _Modalidad {
  int get digits => this == _Modalidad.tresC ? 3 : 4;
  int get prize => this == _Modalidad.tresC ? 1000000 : 8000000;
  String get cifraTag => this == _Modalidad.tresC ? '3C' : '4C';
}

class _BetLine {
  const _BetLine({required this.modalidad, required this.numero});
  final _Modalidad modalidad;
  final String numero;
  static const int betValue = 2000;
  static const int ivaValue = 120;
}

// ── Screen ──────────────────────────────────────────────────────────────────

class DomingueroScreen extends StatefulWidget {
  const DomingueroScreen({super.key});

  @override
  State<DomingueroScreen> createState() => _DomingueroScreenState();
}

class _DomingueroScreenState extends State<DomingueroScreen> {
  late final List<DateTime> _sundays;
  int _selectedSunday = 0;
  _Modalidad _modalidad = _Modalidad.tresC;
  final _numeroCtrl = TextEditingController();
  final List<_BetLine> _lines = [];
  String? _fieldError;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _sundays = _calcSundays();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  static List<DateTime> _calcSundays() {
    final results = <DateTime>[];
    var d = DateTime.now();
    if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
    while (results.length < 5) {
      if (d.weekday == DateTime.sunday) results.add(d);
      d = d.add(const Duration(days: 1));
    }
    return results;
  }

  bool get _isSundayClosed => DateTime.now().weekday == DateTime.sunday;

  static String _fmtSunday(DateTime d) {
    const ms = ['', 'ene', 'feb', 'mar', 'abr', 'mayo', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${ms[d.month]}';
  }

  void _autoNumero() {
    final max = _modalidad.digits == 3 ? 999 : 9999;
    _numeroCtrl.text = math.Random().nextInt(max + 1).toString().padLeft(_modalidad.digits, '0');
    setState(() => _fieldError = null);
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    final d = _modalidad.digits;
    if (n.isEmpty || n.length != d) {
      setState(() => _fieldError = 'El número debe tener exactamente $d cifras');
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  void _addLine() {
    if (!_validate()) return;
    setState(() {
      _lines.add(_BetLine(modalidad: _modalidad, numero: _numeroCtrl.text.trim()));
      _numeroCtrl.clear();
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  int get _totalBet => _lines.length * _BetLine.betValue;
  int get _totalIva => _lines.length * _BetLine.ivaValue;
  int get _maxPrize => _lines.isEmpty
      ? 0
      : _lines.map((l) => l.modalidad.prize).reduce((a, b) => a > b ? a : b);

  static String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$${buf.toString()}';
  }

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (p, c) => (p.user == null) != (c.user == null) || p.status != c.status,
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
                    if (_isSundayClosed)
                      _buildSundayClosedBanner()
                    else if (!loggedIn)
                      _buildAuthRequired(context)
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

  // ── Auth required ────────────────────────────────────────────────────────

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
            onClose: () => Navigator.pop(dialogContext),
            onLoginSuccess: () => Navigator.pop(dialogContext),
            onRegisterRequested: () => Navigator.pop(dialogContext),
            onRecoveryRequested: (identifier) {
              Navigator.pop(dialogContext);
              dialogContext.push(AppRoutes.otpVerification, extra: {
                'destination': identifier,
                'flow': OtpFlow.passwordRecovery,
              });
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.juegoImg2, height: 120, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.lock_outline_rounded, size: 80, color: Color(0xFF2C2E6F))),
              const SizedBox(height: 20),
              Text('Inicia sesión para jugar',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF2C2E6F), height: 1.3),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Debes estar autenticado para realizar apuestas en El Dominguero Millonario.',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF4B5563), height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 220, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1372AE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => _showLoginModal(ctx),
                  child: Text('Iniciar sesión',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sunday closed banner ─────────────────────────────────────────────────

  Widget _buildSundayClosedBanner() {
    final nextMonday = DateTime.now().add(const Duration(days: 1));
    const ms = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final nextOpenLabel = '${nextMonday.day} de ${ms[nextMonday.month]}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.juegoImg2, height: 120, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports, size: 80, color: Color(0xFF2C2E6F))),
              const SizedBox(height: 20),
              Text('El Dominguero no está disponible en este momento',
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF2C2E6F), height: 1.3),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Los domingos son día de sorteo. La venta abre nuevamente el lunes $nextOpenLabel.',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF4B5563), height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 200, height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => context.go(AppRoutes.juegos),
                  child: Text('Ver otros juegos',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────

  Widget _buildContent(double screenW) {
    final isDesktop = screenW >= 1024;

    if (isDesktop) {
      // Flexible evita overflow: ambas tarjetas se ajustan al espacio disponible
      // con un máximo de 780/779 px tal como define Figma.
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
            const SizedBox(width: 40), // Figma: gap-[40px]
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

  // ── Left card ────────────────────────────────────────────────────────────
  // Estructura 1:1 con Figma: gap-[16px] entre cada bloque directo.

  Widget _buildLeftCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Figma: p-[20px]
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Banner — Figma: h-[150px] w-full rounded-[16px]
          _buildBanner(),
          const SizedBox(height: 16),

          // 2. Título + subtítulo — Figma: h-[63px] centrado gap-[4px]
          Center(
            child: Column(
              children: [
                Text(
                  'Sigue los pasos para realizar tu chance',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C2E6F),
                    height: 28 / 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'apuesta abierta de lunes a sábados,  juega y gana los domingos',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF4B5563),
                    height: 28 / 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Paso 1 — instrucción — Figma: p-[10px] texto Inter 16
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFF4B5563)),
                children: [
                  const TextSpan(text: '1.  Selecciona un día a jugar, juega con el sorteo de los resultados de '),
                  TextSpan(
                    text: 'Chontico Noche (domingos)',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F5886)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Date chips — Figma: 5 chips × 122×65 px, gap-[13px]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _sundays.length; i++) ...[
                  _DateChip(
                    date: _fmtSunday(_sundays[i]),
                    dayLabel: 'domingo',
                    isSelected: i == _selectedSunday,
                    onTap: () => setState(() => _selectedSunday = i),
                  ),
                  if (i < _sundays.length - 1) const SizedBox(width: 13),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Paso 2 — instrucción — Figma: p-[10px] texto Inter 16
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '2.  Escoge la cantidad de cifras',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: const Color(0xFF4B5563)),
            ),
          ),
          const SizedBox(height: 16),

          // 6. Botón Automático — Figma: h-[22px] w-[117px] amarillo
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: _AutomaticoBtn(onTap: _autoNumero),
          ),
          const SizedBox(height: 16),

          // 7. Cifras + campo de número — desktop: Row, mobile: Column
          _buildStep2InputBlock(isDesktop),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150, // Figma: h-[150px]
        child: Image.asset(
          AppAssets.bannerDominguero,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFFF9A825)]),
            ),
            alignment: Alignment.center,
            child: Text('El Dominguero\nMILLONARIO',
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  // Paso 2: botones de cifras + campo número
  // Desktop: Row(botones 144px | gap 24px | input Expanded)
  // Mobile:  Column
  Widget _buildStep2InputBlock(bool isDesktop) {
    void onSelect(_Modalidad m) => setState(() {
      _modalidad = m;
      _fieldError = null;
      _numeroCtrl.clear();
    });

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Figma: w-[144px] col con gap-[10px] — botones 144×36 rounded-[14px]
          _ModalidadButtons(selected: _modalidad, onSelect: onSelect),
          // Figma: gap-[170px] entre botones e inputs
          const SizedBox(width: 170),
          // El input ocupa el espacio restante: en tarjeta de 740px → ~426px ≈ w-[421px] Figma
          Expanded(child: _buildNumberInput()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModalidadButtons(selected: _modalidad, onSelect: onSelect),
        const SizedBox(height: 16),
        _buildNumberInput(),
      ],
    );
  }

  Widget _buildNumberInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Figma: "Ingresa tu número" Poppins SemiBold 14px
        Text(
          'Ingresa tu número',
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563), height: 24 / 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        // Figma: Números — h-[45px] rounded-[14px] border grey-300 shadow
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _fieldError != null ? AppColors.error : const Color(0xFFD1D5DB)),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(1, 2), blurRadius: 4)],
          ),
          child: TextField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _modalidad.digits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF4B5563)),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '?',
              hintStyle: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF4B5563)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (_) => setState(() => _fieldError = null),
          ),
        ),

        if (_fieldError != null) ...[
          const SizedBox(height: 4),
          Text(_fieldError!, style: GoogleFonts.inter(fontSize: 12, color: AppColors.error), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 10),

        // Figma: display ?C — h-[44px] rounded-[8px] grey-100 shadow
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 4), blurRadius: 2)],
          ),
          alignment: Alignment.center,
          child: Text(
            _modalidad.cifraTag,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF4B5563)),
          ),
        ),
        const SizedBox(height: 10),

        // Figma: "Agregar otra línea" — h-[24px] w-[223px] amarillo rounded-[4px]
        GestureDetector(
          onTap: _addLine,
          child: Container(
            width: 223,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFFECA0C), borderRadius: BorderRadius.circular(4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF1372AE)),
                const SizedBox(width: 5),
                Text(
                  'Agregar otra línea de apuesta',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1372AE)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Right card ───────────────────────────────────────────────────────────
  // El contenido se acota a maxWidth 492px (ancho del botón de premio en Figma).
  // No se usan anchos fijos que excedan el viewport.

  Widget _buildRightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20), // Figma: p-[20px]
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título — Figma: Inter Bold 22px #2C2E6F centrado
          Text(
            'Así va tu juego',
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF2C2E6F), height: 28 / 22),
          ),
          const SizedBox(height: 16),

          // Resumen acotado a 492px (igual que el botón de premio en Figma)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 492),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header "Tu apuesta"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('Tu apuesta',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563))),
                ),

                // Líneas
                if (_lines.isEmpty)
                  _buildEmptyLines()
                else
                  for (int i = 0; i < _lines.length; i++) _buildBetLineRow(i),

                const SizedBox(height: 8),

                // IVA y Valor apuesta
                _buildSummaryRow('IVA', _fmt(_totalIva)),
                _buildSummaryRow('Valor apuesta', _fmt(_totalBet)),

                const SizedBox(height: 16),

                // Confirmar y pagar — Figma: 371×57px rounded-[26px] verde
                if (_confirmed) _buildConfirmSuccess() else _buildConfirmButton(),

                const SizedBox(height: 16),

                // "Podrías ganar hasta" — Figma: Inter Bold 22px #1372AE
                Text(
                  'Podrías ganar hasta',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1372AE), height: 28 / 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Premio — Figma: h-[80px] w-[492px] azul rounded-[16px]
                _buildPrizeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLines() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00), width: 1),
          bottom: BorderSide(color: Color(0xFFFFCC00), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Línea 1', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1372AE))),
          Text('?c  ?', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
          Text('\$2.000', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
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
          top: const BorderSide(color: Color(0xFFFFCC00), width: 1),
          bottom: i == _lines.length - 1
              ? const BorderSide(color: Color(0xFFFFCC00), width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Línea ${i + 1}',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1372AE))),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
              children: [
                TextSpan(text: '${line.modalidad.cifraTag}  '),
                TextSpan(text: line.numero, style: const TextStyle(color: Color(0xFFFFCC00))),
              ],
            ),
          ),
          Row(
            children: [
              Text('\$2.000', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeLine(i),
                child: const Icon(Icons.close, size: 16, color: Color(0xFF4B5563)),
              ),
            ],
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
          Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: const Color(0xFF4B5563))),
          const SizedBox(width: 18),
          Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
        ],
      ),
    );
  }

  // Figma: h-[87px] contenedor centrado con botón 371×57 rounded-[26px]
  Widget _buildConfirmButton() {
    final hasLines = _lines.isNotEmpty;
    return SizedBox(
      height: 87,
      child: Center(
        child: SizedBox(
          width: 371,
          height: 57,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasLines ? const Color(0xFF43B75D) : const Color(0xFFD1D5DB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            onPressed: hasLines ? () => setState(() => _confirmed = true) : null,
            child: Text(
              'Confirmar y pagar',
              style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w600,
                color: hasLines ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
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
          const Icon(Icons.check_circle, color: Color(0xFF43B75D), size: 32),
          const SizedBox(height: 8),
          Text('¡Apuesta registrada exitosamente!',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1B5E20)),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Sorteo: Chontico Noche · ${_fmtSunday(_sundays[_selectedSunday])}',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF2E7D32)),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() { _confirmed = false; _lines.clear(); _selectedSunday = 0; }),
            child: Text('Realizar otra apuesta',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.secondary500)),
          ),
        ],
      ),
    );
  }

  // Figma: h-[80px] w-[492px] — usa double.infinity porque el padre ConstrainedBox
  // ya limita a 492px, así no hay overflow.
  Widget _buildPrizeButton() {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(color: const Color(0xFF1450EF), borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: Text(
        _maxPrize == 0 ? '\$ 0' : _fmt(_maxPrize),
        style: GoogleFonts.inter(
          fontSize: 40, fontWeight: FontWeight.w700, color: const Color(0xFFFFE30C),
          shadows: const [
            Shadow(color: Color(0xFFCEFFD8), blurRadius: 4),
            Shadow(color: Color(0xFFFFCC00), offset: Offset(0, -3), blurRadius: 20),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────────────────────

// Figma: chip 122×65px rounded-[16px], fuentes Inter Bold
class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.dayLabel, required this.isSelected, required this.onTap});

  final String date;
  final String dayLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF1372AE) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        height: 65,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x1F131927), offset: Offset(0, 2), blurRadius: 4, spreadRadius: -2),
            BoxShadow(color: Color(0x14131927), offset: Offset(0, 4), blurRadius: 4, spreadRadius: -2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sorteo',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: color, height: 24 / 12)),
            Text(date,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.24, height: 1.0)),
            Text(dayLabel,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: color, letterSpacing: -0.1, height: 17 / 10)),
          ],
        ),
      ),
    );
  }
}

// Figma: columna con gap-[10px], cada botón 144×36 rounded-[14px]
class _ModalidadButtons extends StatelessWidget {
  const _ModalidadButtons({required this.selected, required this.onSelect});

  final _Modalidad selected;
  final ValueChanged<_Modalidad> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ModalidadBtn(label: '3 Cifras', isSelected: selected == _Modalidad.tresC, onTap: () => onSelect(_Modalidad.tresC)),
        const SizedBox(height: 10),
        _ModalidadBtn(label: '4 Cifras', isSelected: selected == _Modalidad.cuatroC, onTap: () => onSelect(_Modalidad.cuatroC)),
      ],
    );
  }
}

class _ModalidadBtn extends StatelessWidget {
  const _ModalidadBtn({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 144,  // Figma: w-[144px]
        height: 36,  // Figma: h-[36px]
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1372AE) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14), // Figma: rounded-[14px]
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, height: 24 / 20),
        ),
      ),
    );
  }
}

// Figma: h-[22px] w-[117px] amarillo rounded-[4px]
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
        decoration: BoxDecoration(color: const Color(0xFFFECA0C), borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.refreshCircular, width: 14, height: 14,
                colorFilter: const ColorFilter.mode(Color(0xFF1372AE), BlendMode.srcIn)),
            const SizedBox(width: 5),
            Text('Automático',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1372AE))),
          ],
        ),
      ),
    );
  }
}

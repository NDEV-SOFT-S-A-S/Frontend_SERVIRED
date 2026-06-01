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
    // Si hoy es domingo, empezar desde el próximo lunes para buscar domingos futuros
    if (d.weekday == DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    while (results.length < 5) {
      if (d.weekday == DateTime.sunday) results.add(d);
      d = d.add(const Duration(days: 1));
    }
    return results;
  }

  bool get _isSundayClosed => DateTime.now().weekday == DateTime.sunday;

  static String _fmtSunday(DateTime d) {
    const ms = [
      '', 'ene', 'feb', 'mar', 'abr', 'mayo',
      'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${d.day} ${ms[d.month]}';
  }

  void _autoNumero() {
    final max = _modalidad.digits == 3 ? 999 : 9999;
    final rand = math.Random().nextInt(max + 1);
    _numeroCtrl.text = rand.toString().padLeft(_modalidad.digits, '0');
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
      _lines.add(_BetLine(
        modalidad: _modalidad,
        numero: _numeroCtrl.text.trim(),
      ));
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
                    if (_isSundayClosed)
                      _buildSundayClosedBanner()
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

  // ── Sunday closed banner ─────────────────────────────────────────────────

  Widget _buildSundayClosedBanner() {
    final nextMonday = DateTime.now().add(const Duration(days: 1));
    const ms = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final nextOpenLabel = '${nextMonday.day} de ${ms[nextMonday.month]}';

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
              Image.asset(
                AppAssets.juegoImg2,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_esports,
                  size: 80,
                  color: Color(0xFF2C2E6F),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'El Dominguero no está disponible en este momento',
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
                'Los domingos son día de sorteo. La venta abre nuevamente el lunes $nextOpenLabel.',
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
                width: 200,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => context.go(AppRoutes.juegos),
                  child: Text(
                    'Ver otros juegos',
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

  // ── Main game content ────────────────────────────────────────────────────

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

  // ── Left card ────────────────────────────────────────────────────────────

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
          // Banner
          _buildBanner(),
          const SizedBox(height: 16),

          // Título
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
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                    height: 28 / 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Paso 1 — Selección de fecha
          _buildStep1(),
          const SizedBox(height: 12),

          // Paso 2 — Cifras + número
          _buildStep2(isDesktop),
        ],
      ),
    );
  }

  // Banner imagen del juego
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.juegoImg2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFFF9A825)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'El Dominguero\nMILLONARIO',
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

  // Paso 1: selector de fechas (próximos domingos)
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Instrucción con texto resaltado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF4B5563),
              ),
              children: [
                const TextSpan(
                  text: '1.  Selecciona un día a jugar, juega con el sorteo de los resultados de ',
                ),
                TextSpan(
                  text: 'Chontico Noche (domingos)',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F5886),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Chips de fechas
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _sundays.length; i++) ...[
                  _DateChip(
                    date: _fmtSunday(_sundays[i]),
                    dayLabel: 'Domingo',
                    isSelected: i == _selectedSunday,
                    onTap: () => setState(() => _selectedSunday = i),
                  ),
                  if (i < _sundays.length - 1) const SizedBox(width: 13),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Paso 2: botones de cifras + campo de número
  Widget _buildStep2(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            '2.  Escoge la cantidad de cifras',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Botón Automático
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: _AutomaticoBtn(onTap: _autoNumero),
        ),
        const SizedBox(height: 12),

        // Layout cifras + input
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
                  const SizedBox(width: 40),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Ingresa tu número',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4B5563),
            height: 24 / 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Campo número
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

        // Error
        if (_fieldError != null) ...[
          const SizedBox(height: 4),
          Text(
            _fieldError!,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),

        // Display modalidad activa
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
          alignment: Alignment.center,
          child: Text(
            _modalidad.cifraTag,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
              height: 38 / 20,
            ),
          ),
        ),
        const SizedBox(height: 8),

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
                const Icon(Icons.add_circle_outline,
                    size: 18, color: Color(0xFF1372AE)),
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
      ],
    );
  }

  // ── Right card ───────────────────────────────────────────────────────────

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
          // Título
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

          // Resumen de apuesta
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header "Tu apuesta"
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

                // Líneas de apuesta
                if (_lines.isEmpty)
                  _buildEmptyLines()
                else
                  for (int i = 0; i < _lines.length; i++)
                    _buildBetLineRow(i),

                const SizedBox(height: 8),

                // IVA
                _buildSummaryRow('IVA', _fmt(_totalIva)),

                // Valor apuesta
                _buildSummaryRow('Valor apuesta', _fmt(_totalBet)),

                const SizedBox(height: 16),

                // Confirmar y pagar
                if (_confirmed)
                  _buildConfirmSuccess()
                else
                  _buildConfirmButton(),

                const SizedBox(height: 20),

                // Podrías ganar hasta
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

                // Prize button
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
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFFFCC00), width: 1),
          bottom: BorderSide(color: const Color(0xFFFFCC00), width: 1),
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
              color: const Color(0xFF1372AE),
            ),
          ),
          Text(
            '?c  ?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Text(
            '\$2.000',
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFFFCC00), width: 1),
          bottom: i == _lines.length - 1
              ? BorderSide(color: const Color(0xFFFFCC00), width: 1)
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
                TextSpan(text: '${line.modalidad.cifraTag}  '),
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
                '\$2.000',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
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
        onPressed: hasLines
            ? () => setState(() => _confirmed = true)
            : null,
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
            'Sorteo: Chontico Noche Festivo · ${_fmtSunday(_sundays[_selectedSunday])}',
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
              _selectedSunday = 0;
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
            Shadow(
              color: Color(0xFFCEFFD8),
              blurRadius: 4,
            ),
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

// ── Widgets auxiliares ───────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.dayLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String date;
  final String dayLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 65,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFCC00) : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F131927),
              offset: Offset(0, 2),
              blurRadius: 2,
            ),
            BoxShadow(
              color: Color(0x14131927),
              offset: Offset(0, 4),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sorteo',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                height: 24 / 12,
              ),
            ),
            Text(
              date,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                letterSpacing: -0.24,
                height: 24 / 16,
              ),
            ),
            Text(
              dayLabel.toLowerCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1372AE)
                    : Colors.white,
                letterSpacing: -0.1,
                height: 17 / 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        width: 130,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1372AE)
              : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 24 / 18,
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

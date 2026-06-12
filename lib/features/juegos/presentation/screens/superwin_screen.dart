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
// HU-SUP001 + Resolución G-000004: valor fijo $3.000 IVA incluido; IVA = $479 (resolución tabla); premio = $13.125.000

class _BetLine {
  const _BetLine({required this.numero});
  final String numero;

  static const int betValue =
      3000; // valor fijo parametrizable; actualmente $3.000 (HU + resolución)
  // IVA = $3.000 * 19/119 = $478,99 ≈ $479 (resolución tabla: base $2.521,01 + IVA = $3.000 total)
  // El Figma mostraba $460, pero la resolución G-000004 es la fuente definitiva.
  static const int ivaValue = 479;
  static const int prizeValue =
      13125000; // $2.521,01 × $5.206,25 = $13.125.000 (resolución tabla)
  static const int maxDigits = 4; // solo 4 cifras (HU)
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

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  // ── Lógica ───────────────────────────────────────────────────────────────

  void _autoNumero() {
    final rand = math.Random().nextInt(10000);
    _numeroCtrl.text = rand.toString().padLeft(4, '0');
    setState(() => _fieldError = null);
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    // E1: número incompleto o inválido (HU excepción E1)
    if (n.length != _BetLine.maxDigits) {
      setState(() => _fieldError = 'Ingrese un número válido de cuatro cifras');
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  void _addLine() {
    if (!_validate()) return;
    setState(() {
      _lines.add(_BetLine(numero: _numeroCtrl.text.trim()));
      _numeroCtrl.clear();
    });
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  void _limpiar() {
    // A1: limpiar todos los datos y apuestas no confirmadas
    setState(() {
      _numeroCtrl.clear();
      _lines.clear();
      _fieldError = null;
      _confirmed = false;
    });
  }

  int get _totalBet => _lines.length * _BetLine.betValue;
  int get _totalIva => _lines.length * _BetLine.ivaValue;
  // Podrías ganar hasta = premio por mejor línea (todas tienen el mismo premio)
  int get _maxPrize => _lines.isEmpty ? 0 : _BetLine.prizeValue;

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

        return Scaffold(
          backgroundColor: AppColors.homeBackground,
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: navH),
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

  // ── Left card ─────────────────────────────────────────────────────────────

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

          // Título
          Center(
            child: Text(
              'Sigue los pasos para realizar tu tiraje',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
                height: 28 / 22,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),

          // Descripción del producto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Superwin juega 1 número de 4 cifras por solo \$3.000 e incluye 1 tiraje, se jugará con:',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF4B5563),
                height: 24 / 16,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Imagen lotería asociada (Chontico Día)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                AppAssets.imagenSuperwin,
                width: 150,
                height: 81,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 150,
                  height: 81,
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
          const SizedBox(height: 16),

          // Paso 2
          _buildStep2(isDesktop),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 148,
        child: Image.asset(
          AppAssets.bannerSuperwin,
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

        // Input + display row
        Center(child: _buildNumberSection()),
      ],
    );
  }

  Widget _buildNumberSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 421),
      child: Column(
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
              maxLength: _BetLine.maxDigits,
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
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),

          // Fila 4C + dígitos + valor
          _buildDigitDisplayRow(),
          const SizedBox(height: 12),

          // Botones: agregar línea + limpiar (HU paso 4)
          _buildLineActions(),
        ],
      ),
    );
  }

  // Fila gris: "4C [?][?][?][?] $3.000" — Figma node I867:20315;867:16232
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
              color: const Color(0xFF4B5563),
              height: 38 / 20,
            ),
          ),
          const SizedBox(width: 8),
          for (int i = 0; i < 4; i++) ...[
            _DigitBall(
              digit: (i < _numeroCtrl.text.length) ? _numeroCtrl.text[i] : '?',
            ),
            if (i < 3) const SizedBox(width: 5),
          ],
          const SizedBox(width: 8),
          Text(
            '\$3.000',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
              height: 38 / 20,
            ),
          ),
        ],
      ),
    );
  }

  // Fila con "Agregar otra línea" y "Limpiar" — HU paso 4 requiere ambos botones
  Widget _buildLineActions() {
    final hasData = _lines.isNotEmpty || _numeroCtrl.text.isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón Agregar otra línea de apuesta
        GestureDetector(
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

        // Botón Limpiar — habilitado cuando hay datos capturados (HU alterno A1)
        if (hasData) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _limpiar,
            child: Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline,
                      size: 15, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    'Limpiar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
                // "Tu apuesta" header
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
                  _buildEmptyLine()
                else
                  for (int i = 0; i < _lines.length; i++) _buildBetLineRow(i),

                const SizedBox(height: 8),

                // IVA
                _buildSummaryRow('IVA', _fmt(_totalIva)),
                // Valor apuesta
                _buildSummaryRow('Valor apuesta', _fmt(_totalBet)),

                const SizedBox(height: 16),

                // Botón Confirmar o estado éxito
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

                _buildPrizeButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Línea vacía placeholder
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
          Text('Línea 1',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1372AE))),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
              children: const [
                TextSpan(text: '4c  '),
                TextSpan(
                    text: '????', style: TextStyle(color: Color(0xFFFFCC00))),
                TextSpan(text: '  Lotería '),
                TextSpan(
                    text: 'Chont.día',
                    style: TextStyle(color: Color(0xFFFFCC00))),
              ],
            ),
          ),
          Text('\$3.000',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Línea ${i + 1}',
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1372AE)),
          ),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black),
                children: [
                  const TextSpan(text: '4c  '),
                  TextSpan(
                      text: line.numero,
                      style: const TextStyle(color: Color(0xFFFFCC00))),
                  const TextSpan(text: '  Lotería '),
                  const TextSpan(
                      text: 'Chont.día',
                      style: TextStyle(color: Color(0xFFFFCC00))),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('\$3.000',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeLine(i),
                child:
                    const Icon(Icons.close, size: 16, color: Color(0xFF4B5563)),
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
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563))),
          const SizedBox(width: 18),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final enabled = _lines.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 57,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF43B75D) : const Color(0xFFBDD7EE),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 0,
        ),
        onPressed: enabled ? _showConfirmDialog : null,
        child: Text(
          'Confirmar y pagar',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : const Color(0xFF6B99B9),
          ),
        ),
      ),
    );
  }

  void _showConfirmDialog() {
    // A5: ventana de confirmación (HU paso 18)
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Está seguro de que desea realizar la compra?',
          style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C2E6F)),
          textAlign: TextAlign.center,
        ),
        content: Text(
          '${_lines.length} apuesta${_lines.length > 1 ? 's' : ''} Superwin · Total ${_fmt(_totalBet)}',
          style:
              GoogleFonts.inter(fontSize: 14, color: const Color(0xFF4B5563)),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: const Color(0xFF4B5563),
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF43B75D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Aceptar',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((accepted) {
      if (accepted == true) {
        setState(() => _confirmed = true);
      }
    });
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
            '¡La apuesta se registró con éxito!',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B5E20)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Producto: Superwin · Lotería: Chontico Día',
            style:
                GoogleFonts.inter(fontSize: 13, color: const Color(0xFF2E7D32)),
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
                  color: AppColors.secondary500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeButton() {
    final label =
        _maxPrize == 0 ? '\$ 13.125.000 COP' : '${_fmt(_maxPrize)} COP';
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
                blurRadius: 20),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _DigitBall extends StatelessWidget {
  const _DigitBall({required this.digit});

  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 29,
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(80),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4B5563),
          height: 28 / 22,
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

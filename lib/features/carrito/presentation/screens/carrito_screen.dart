// HU-CAR001 – Carrito de compras Baloto Revancha
// Versión: 1.1.0 – 05/06/2026

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';
import 'package:go_router/go_router.dart';

// ── Modelo de ítem en el carrito ──────────────────────────────────────────────

class CarritoItem {
  const CarritoItem({
    required this.balotas,
    required this.superbalota,
    required this.conRevancha,
    required this.cantidadSorteos,
    required this.precioTotal,
  });

  final List<int> balotas;
  final int superbalota;
  final bool conRevancha;
  final int cantidadSorteos;
  final int precioTotal;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtCop(int amount) {
  if (amount == 0) return '\$0';
  final s = amount.toString();
  final buf = StringBuffer('\$');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${buf.toString()},00';
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key, required this.items});
  final List<CarritoItem> items;

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  late List<CarritoItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _eliminar(int index) {
    setState(() => _items.removeAt(index));
    if (_items.isEmpty) context.go(AppRoutes.balotoRevancha);
  }

  int get _totalGeneral => _items.fold(0, (s, i) => s + i.precioTotal);
  int get _valorSinIva  => (_totalGeneral / 1.19).round();
  int get _iva          => _totalGeneral - _valorSinIva;

  @override
  Widget build(BuildContext context) {
    final sw      = MediaQuery.sizeOf(context).width;
    final isMobile = sw < 720;

    return Scaffold(
      backgroundColor: const Color(0xFF1372AE),
      body: Column(
        children: [
          NavbarWidget(
            isLoggedIn: true,
            activeNavItem: 'Carrito',
            onInicioTap: () => context.go(AppRoutes.home),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: isMobile
                  ? const EdgeInsets.fromLTRB(12, 16, 12, 24)
                  : const EdgeInsets.symmetric(horizontal: 65, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 1409,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: isMobile
                        ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
                        : const EdgeInsets.all(28),
                    child: isMobile
                        ? _buildMobileLayout()
                        : _buildDesktopLayout(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOBILE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBanner(),
        const SizedBox(height: 16),
        _buildTitulo(fontSize: 18),
        const SizedBox(height: 16),
        ..._items.asMap().entries.map((e) => _buildMobileCard(e.key, e.value)),
        const SizedBox(height: 24),
        _buildMobileResumen(),
      ],
    );
  }

  Widget _buildMobileCard(int index, CarritoItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila 1 — Revancha chip + eliminar
          Row(
            children: [
              if (item.conRevancha) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBBF24)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0C2577), width: 2),
                        ),
                        child: Center(
                          child: Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0C2577),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Revancha',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0C2577),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Text(
                  'Sin revancha',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              const Spacer(),
              GestureDetector(
                onTap: () => _eliminar(index),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFFDC2626), size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fila 2 — Sorteos
          _buildMobileFilaInfo(
            'Sorteos',
            Text(
              '${item.cantidadSorteos}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0C2577),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Fila 3 — Números apostados
          _buildMobileFilaInfo(
            '# Apostado',
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...item.balotas.map((n) => _buildBola(n, isSuper: false, size: 28)),
                _buildBola(item.superbalota, isSuper: true, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Fila 4 — Valor total
          _buildMobileFilaInfo(
            'Valor total',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_outlined,
                    color: Color(0xFF0C2577), size: 16),
                const SizedBox(width: 6),
                Text(
                  _fmtCop(item.precioTotal),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFilaInfo(String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(child: value),
      ],
    );
  }

  Widget _buildMobileResumen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildFilaResumen('Valor sin IVA', _fmtCop(_valorSinIva), fontSize: 15),
              const SizedBox(height: 8),
              _buildFilaResumen('IVA', _fmtCop(_iva), fontSize: 15),
              const SizedBox(height: 8),
              _buildFilaResumen('Valor total', _fmtCop(_totalGeneral),
                  bold: true, fontSize: 16),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.go(AppRoutes.balotoRevancha),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B3E),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'SEGUIR APOSTANDO',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 110,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF43B75D),
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: Text(
                  'PAGAR',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESKTOP
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBanner(),
        const SizedBox(height: 20),
        _buildTitulo(fontSize: 22),
        const SizedBox(height: 20),
        _buildHeadersTabla(),
        const SizedBox(height: 10),
        ..._items.asMap().entries.map((e) => _buildDesktopFila(e.key, e.value)),
        const SizedBox(height: 40),
        _buildDesktopResumen(),
      ],
    );
  }

  Widget _buildHeadersTabla() {
    const style = TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF0C2577),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 77),
          Expanded(flex: 2, child: Text('PRODUCTO',    style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('JUEGA CON',   style: style, textAlign: TextAlign.center)),
          Expanded(flex: 1, child: Text('SORTEOS',     style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('# APOSTADOS', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('VALOR TOTAL', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildDesktopFila(int index, CarritoItem item) {
    return Container(
      height: 80,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 62),
          // Logo
          Expanded(
            flex: 2,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  AppAssets.logoBalotoRevancha,
                  height: 60,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80, height: 60,
                    color: const Color(0xFF071647),
                    alignment: Alignment.center,
                    child: Text('BR',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  ),
                ),
              ),
            ),
          ),
          // Juega con
          Expanded(
            flex: 2,
            child: Center(
              child: item.conRevancha
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0C2577), width: 2),
                          ),
                          child: Center(
                            child: Container(
                              width: 10, height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0C2577),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Revancha',
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF071647))),
                      ],
                    )
                  : Text('Sin revancha',
                      style: GoogleFonts.inter(
                          fontSize: 15, color: const Color(0xFF6B7280))),
            ),
          ),
          // Sorteos
          Expanded(
            flex: 1,
            child: Text(
              '${item.cantidadSorteos}',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0C2577),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Números apostados
          Expanded(
            flex: 3,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                ...item.balotas.map((n) => _buildBola(n, isSuper: false, size: 32)),
                _buildBola(item.superbalota, isSuper: true, size: 32),
              ],
            ),
          ),
          // Precio + acciones
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_outlined, color: Color(0xFF0C2577), size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _fmtCop(item.precioTotal),
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0C2577),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _eliminar(index),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFF0C2577), size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildDesktopResumen() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 436,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildFilaResumen('Valor sin IVA', _fmtCop(_valorSinIva)),
                  const SizedBox(height: 10),
                  _buildFilaResumen('IVA', _fmtCop(_iva)),
                  const SizedBox(height: 10),
                  _buildFilaResumen('Valor total', _fmtCop(_totalGeneral), bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.go(AppRoutes.balotoRevancha),
                    child: Container(
                      height: 47,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'SEGUIR APOSTANDO',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 135,
                    height: 47,
                    decoration: BoxDecoration(
                      color: const Color(0xFF43B75D),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'PAGAR',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS COMPARTIDOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.bannerBalotoRevancha,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => Container(
          height: 120,
          color: const Color(0xFF071647),
          alignment: Alignment.center,
          child: Text('Baloto Revancha',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 22)),
        ),
      ),
    );
  }

  Widget _buildTitulo({required double fontSize}) {
    return Center(
      child: Text(
        'TU CARRITO',
        style: GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0C2577),
        ),
      ),
    );
  }

  Widget _buildBola(int numero, {required bool isSuper, double size = 28}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSuper ? const Color(0xFFF70700) : const Color(0xFFFFE30C),
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: GoogleFonts.inter(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: isSuper ? Colors.white : const Color(0xFF071647),
        ),
      ),
    );
  }

  Widget _buildFilaResumen(String label, String valor,
      {bool bold = false, double fontSize = 22}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: const Color(0xFF0C2577),
          ),
        ),
        Text(
          valor,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0C2577),
          ),
        ),
      ],
    );
  }
}

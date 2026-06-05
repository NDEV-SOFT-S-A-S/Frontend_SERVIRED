// HU-CAR001 – Carrito de compras Baloto Revancha
// Versión: 1.0.0.0 – 04/06/2026

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

  int get _valorSinIva => (_totalGeneral / 1.19).round();

  int get _iva => _totalGeneral - _valorSinIva;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const NavbarWidget(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 65, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1409),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBanner(),
                        const SizedBox(height: 20),
                        _buildTitulo(),
                        const SizedBox(height: 20),
                        _buildHeadersTabla(),
                        const SizedBox(height: 10),
                        ..._items.asMap().entries.map((e) => _buildFila(e.key, e.value)),
                        const SizedBox(height: 40),
                        _buildResumen(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.bannerBalotoRevancha,
        width: double.infinity,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => Container(
          height: 150,
          color: const Color(0xFF071647),
          alignment: Alignment.center,
          child: Text('Baloto Revancha',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 24)),
        ),
      ),
    );
  }

  // ── Título ────────────────────────────────────────────────────────────────

  Widget _buildTitulo() {
    return Center(
      child: Text(
        'TU CARRITO',
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0C2577),
        ),
      ),
    );
  }

  // ── Headers de la tabla ───────────────────────────────────────────────────

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
          SizedBox(width: 133, child: Text('PRODUCTO', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 120, child: Text('JUEGA CON', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 100, child: Text('SORTEOS', style: style, textAlign: TextAlign.center)),
          Expanded(child: Text('# APOSTADOS', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 220, child: Text('VALOR TOTAL', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  // ── Fila de producto ──────────────────────────────────────────────────────

  Widget _buildFila(int index, CarritoItem item) {
    return Container(
      height: 72,
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 62),
          // Logo del producto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              AppAssets.logoBalotoRevancha,
              width: 133,
              height: 72,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 133, height: 72,
                color: const Color(0xFF071647),
                alignment: Alignment.center,
                child: Text('BR', style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(width: 0),
          // Juega con (Revancha)
          SizedBox(
            width: 158,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.conRevancha) ...[
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0C2577), width: 2),
                    ),
                    child: Center(
                      child: Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0C2577),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Revancha',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w400, color: const Color(0xFF071647))),
                ] else
                  Text('Sin revancha',
                      style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF0C2577))),
              ],
            ),
          ),
          // Sorteos
          SizedBox(
            width: 100,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...item.balotas.map((n) => _buildBola(n, isSuper: false)),
                _buildBola(item.superbalota, isSuper: true),
              ],
            ),
          ),
          // Precio + acciones
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, color: const Color(0xFF0C2577), size: 22),
                const SizedBox(width: 8),
                Text(
                  _fmtCop(item.precioTotal),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0C2577),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _eliminar(index),
                  child: const Icon(Icons.delete_outline, color: Color(0xFF0C2577), size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }

  Widget _buildBola(int numero, {required bool isSuper}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSuper ? const Color(0xFFF70700) : const Color(0xFFFFE30C),
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isSuper ? Colors.white : const Color(0xFF071647),
        ),
      ),
    );
  }

  // ── Resumen ───────────────────────────────────────────────────────────────

  Widget _buildResumen() {
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

  Widget _buildFilaResumen(String label, String valor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: const Color(0xFF0C2577),
            )),
        Text(valor,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0C2577),
            )),
      ],
    );
  }
}

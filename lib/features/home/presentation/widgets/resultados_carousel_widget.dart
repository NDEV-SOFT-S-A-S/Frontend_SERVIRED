import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import 'resultado_card_widget.dart';

// Figma node 548:1798
// Track: 8 tarjetas × 273px + 7 × 31px gap = 2401px
// Animación ping-pong: 10s izquierda → 10s derecha, easeInOut, sin pausa

const _kLogoRisaralda = AppAssets.logoRisaralda;

final _kResultados = [
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda día',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
  const ResultadoData(
    logoUrl: _kLogoRisaralda,
    nombre: 'Risaralda noche',
    fecha: '04 de Mayo 2026',
    numeros: [5, 4, 7, 1],
  ),
];

class ResultadosCarouselWidget extends StatefulWidget {
  const ResultadosCarouselWidget({super.key});

  @override
  State<ResultadosCarouselWidget> createState() =>
      _ResultadosCarouselWidgetState();
}

class _ResultadosCarouselWidgetState extends State<ResultadosCarouselWidget>
    with SingleTickerProviderStateMixin {
  // Medidas exactas de Figma (nodo 548:1798)
  static const double _cardWidth = 273.0;
  static const double _gap = 31.0;
  static const int _cardCount = 8;
  static const double _trackWidth =
      _cardCount * _cardWidth + (_cardCount - 1) * _gap; // 2401px

  late AnimationController _controller;
  late CurvedAnimation _curvedAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _curvedAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _curvedAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Móvil (<680px): scroll táctil manual con ListView
          if (constraints.maxWidth < 680) {
            return _buildMobileScroll();
          }
          // Desktop: animación ping-pong automática
          return _buildDesktopAnimation(constraints);
        },
      ),
    );
  }

  // ── Móvil: scroll horizontal táctil ──────────────────────────────────────
  Widget _buildMobileScroll() {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      // Sin padding extra — la sección ya tiene padding lateral en home_screen
      padding: EdgeInsets.zero,
      itemCount: _kResultados.length,
      separatorBuilder: (_, __) => const SizedBox(width: _gap),
      itemBuilder: (_, i) => ResultadoCardWidget(data: _kResultados[i]),
    );
  }

  // ── Desktop: animación ping-pong automática ───────────────────────────────
  Widget _buildDesktopAnimation(BoxConstraints constraints) {
    // Desplazamiento máximo: sobrante del track que no cabe en el viewport
    final maxOffset =
        (_trackWidth - constraints.maxWidth).clamp(0.0, double.maxFinite);

    // OverflowBox le dice al layout engine que el track mide exactamente
    // _trackWidth (2401px) sin estar limitado por el maxWidth del viewport.
    // ClipRect recorta el rendering; Transform.translate desplaza el track.
    return ClipRect(
      child: AnimatedBuilder(
        animation: _curvedAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(-maxOffset * _curvedAnim.value, 0),
            child: child,
          );
        },
        // El track se construye una sola vez (child del AnimatedBuilder)
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: _trackWidth,
          maxWidth: _trackWidth,
          minHeight: 146,
          maxHeight: 146,
          child: Row(
            children: [
              for (int i = 0; i < _kResultados.length; i++) ...[
                ResultadoCardWidget(data: _kResultados[i]),
                if (i < _kResultados.length - 1)
                  const SizedBox(width: _gap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

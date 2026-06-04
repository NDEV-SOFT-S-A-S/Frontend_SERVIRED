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
  // Medidas desktop (Figma 548:1798): 273×146px, gap 31px
  static const double _cardW = 273.0;
  static const double _cardH = 146.0;
  static const double _gap = 31.0;
  static const int _cardCount = 8;
  static const double _trackW = _cardCount * _cardW + (_cardCount - 1) * _gap;

  // Medidas mobile (Figma 553:2135): 106×66px, gap 12px
  static const double _mCardW = 106.0;
  static const double _mCardH = 66.0;
  static const double _mGap = 12.0;
  static const double _mTrackW =
      _cardCount * _mCardW + (_cardCount - 1) * _mGap;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 680;
        // Altura del track según breakpoint
        final double trackH = mobile ? _mCardH : _cardH;
        return SizedBox(
          height: trackH,
          child: _buildAnimation(constraints, mobile: mobile),
        );
      },
    );
  }

  // Animación ping-pong — igual en desktop y mobile, solo cambia el tamaño
  Widget _buildAnimation(BoxConstraints constraints, {required bool mobile}) {
    final double trackW = mobile ? _mTrackW : _trackW;
    final double trackH = mobile ? _mCardH : _cardH;
    final double gap = mobile ? _mGap : _gap;

    final maxOffset =
        (trackW - constraints.maxWidth).clamp(0.0, double.maxFinite);

    return ClipRect(
      child: AnimatedBuilder(
        animation: _curvedAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(-maxOffset * _curvedAnim.value, 0),
            child: child,
          );
        },
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: trackW,
          maxWidth: trackW,
          minHeight: trackH,
          maxHeight: trackH,
          child: Row(
            children: [
              for (int i = 0; i < _kResultados.length; i++) ...[
                ResultadoCardWidget(
                  data: _kResultados[i],
                  compact: mobile,
                ),
                if (i < _kResultados.length - 1) SizedBox(width: gap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

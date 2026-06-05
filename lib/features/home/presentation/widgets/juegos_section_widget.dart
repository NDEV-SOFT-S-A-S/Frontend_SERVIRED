import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'juego_card_widget.dart';
import 'section_header_widget.dart';

// Figma nodes 561:8133 y 561:8139
// 3 filas: 5 + 5 + 2 tarjetas (288×360px)
//
// Fila 1 (índices 0-4):  Chance · Paga Todo · SuperWin · Dominguero · Quincenazo
// Fila 2 (índices 5-9):  Doble Chance · Chance Millonario · Pata Millonaria · La Quinta · Baloto
// Fila 3 (índices 10-11): Miloto · Colorloto  (alineadas al inicio)

const kJuegos = [
  // ── Fila 1 ────────────────────────────────────────────────────────────────
  JuegoData(
    imageUrl: AppAssets.juegoChance,           // 0 · Chance Tradicional
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoPagaTodo,         // 1 · Paga Todo
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoSuperwin,         // 2 · SuperWin
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoDominguero,       // 3 · Dominguero Millonario
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoQuincenazo,       // 4 · Quincenazo / Venta Futura
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoDobleChance,      // 5 · Doble Chance
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  // ── Fila 2 ────────────────────────────────────────────────────────────────
  JuegoData(
    imageUrl: AppAssets.juegoChanceMillonario, // 6 · Chance Millonario
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoPataMillonaria,   // 7 · Pata Millonaria
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoQuinta,           // 8 · La Quinta
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoBalotoRevancha,   // 9 · Baloto Revancha
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoMiloto,           // 10 · Miloto
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoColorloto,        // 11 · Colorloto
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
];

class JuegosSectionWidget extends StatelessWidget {
  const JuegosSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool mobile = constraints.maxWidth < 720;

        if (mobile) return _buildMobile(context, constraints);
        return _buildDesktop(context);
      },
    );
  }

  // ── Desktop: grid de filas ──────────────────────────────────────────────
  Widget _buildDesktop(BuildContext context) {
    final row1 = kJuegos.sublist(0, 5);
    final row2 = kJuegos.sublist(5, 10);
    final row3 = kJuegos.sublist(10, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeaderWidget(
          icon: SvgPicture.asset(
            AppAssets.iconJuego,
            width: 28,
            height: 28,
          ),
          title: 'Juegos',
          showVerMas: true,
          onVerMas: () => context.go(AppRoutes.juegos),
        ),
        const SizedBox(height: 16),
        _JuegosRow(juegos: row1, startIndex: 0),
        const SizedBox(height: 16),
        _JuegosRow(juegos: row2, startIndex: 5),
        const SizedBox(height: 16),
        _JuegosRow(juegos: row3, startIndex: 10, alignStart: true),
      ],
    );
  }

  // ── Mobile: 3 filas con scroll horizontal (5 + 5 + 2 cards por fila) ────
  // Padding lateral 16px, gap 12px entre cards, 12px entre filas
  Widget _buildMobile(BuildContext context, BoxConstraints constraints) {
    final rows = [
      kJuegos.sublist(0, 5),   // Fila 1: índices 0-4
      kJuegos.sublist(5, 10),  // Fila 2: índices 5-9
      kJuegos.sublist(10, 12), // Fila 3: índices 10-11
    ];
    final rowStartIndex = [0, 5, 10];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeaderWidget(
            icon: SvgPicture.asset(
              AppAssets.iconJuego,
              width: 24,
              height: 24,
            ),
            title: 'Juegos',
            showVerMas: true,
            onVerMas: () => context.go(AppRoutes.juegos),
          ),
        ),
        const SizedBox(height: 12),

        for (int r = 0; r < rows.length; r++) ...[
          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: rows[r].length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final globalIndex = rowStartIndex[r] + i;
                return JuegoCardWidget(
                  data: rows[r][i],
                  compact: true,
                  onTap: _tapFor(context, globalIndex),
                );
              },
            ),
          ),
          if (r < rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  VoidCallback? _tapFor(BuildContext context, int i) {
    switch (i) {
      case 0: return () => context.push(AppRoutes.chanceTradicional);
      case 1: return () => context.push(AppRoutes.pagaTodo);
      case 2: return () => context.push(AppRoutes.superwin);
      case 3: return () => context.push(AppRoutes.dominguero);
      case 6: return () => context.push(AppRoutes.chanceMillonario);
      case 7: return () => context.push(AppRoutes.pataMillonaria);
      case 9: return () => context.push(AppRoutes.balotoRevancha);
      default: return null;
    }
  }
}

class _JuegosRow extends StatelessWidget {
  const _JuegosRow({
    required this.juegos,
    required this.startIndex,
    this.alignStart = false,
  });

  final List<JuegoData> juegos;
  // Índice global del primer elemento de esta fila dentro de kJuegos
  final int startIndex;
  // true → la fila no ocupa todo el ancho (ej. última fila de 2 cards)
  final bool alignStart;

  /// Número de columnas según el ancho disponible.
  /// En tablet y mobile las cards se distribuyen en Wrap para evitar overflow.
  int _columnsFor(double w) {
    if (w >= 1440) return 5;
    if (w >= 1100) return 4;
    if (w >= 800)  return 3;
    if (w >= 520)  return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = _columnsFor(w);

        // ── Desktop: 5 columnas con gap proporcional ─────────────────────
        // Cuando la fila tiene menos cards que columnas (ej. fila de 2),
        // se alinea al inicio para no crear un gap visual excesivo.
        if (cols >= 5 || juegos.length <= 2 && alignStart) {
          final cardCount = juegos.length;
          // gap entre cards = espacio restante dividido entre n-1 huecos
          // mínimo 8px, máximo 80px
          final gap = cardCount > 1
              ? ((w - cardCount * 288.0) / (cardCount - 1)).clamp(8.0, 80.0)
              : 0.0;

          return Row(
            mainAxisAlignment: alignStart
                ? MainAxisAlignment.start
                : MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < cardCount; i++) ...[
                if (alignStart && i > 0) SizedBox(width: gap),
                JuegoCardWidget(
                  data: juegos[i],
                  onTap: _tapFor(context, startIndex + i),
                ),
                if (!alignStart && i < cardCount - 1) SizedBox(width: gap),
              ],
            ],
          );
        }

        // ── Tablet / Mobile: Wrap sin scroll horizontal ───────────────────
        // El gap entre cards se calcula para que exactamente `cols` quepan.
        final gap = cols > 1
            ? ((w - cols * 288.0) / (cols - 1)).clamp(8.0, 80.0)
            : 0.0;

        return Wrap(
          spacing: gap,
          runSpacing: 16,
          children: [
            for (int i = 0; i < juegos.length; i++)
              JuegoCardWidget(
                data: juegos[i],
                onTap: _tapFor(context, startIndex + i),
              ),
          ],
        );
      },
    );
  }

  VoidCallback? _tapFor(BuildContext context, int globalIndex) {
    // Orden: 0=Chance, 1=PagaTodo, 2=SuperWin, 3=Dominguero,
    //        4=Quincenazo, 5=DobleChance, 6=ChanceMillonario, 7=PataMillonaria,
    //        8=LaQuinta, 9=Baloto, 10=Miloto, 11=Colorloto
    switch (globalIndex) {
      case 0: return () => context.push(AppRoutes.chanceTradicional);
      case 1: return () => context.push(AppRoutes.pagaTodo);
      case 2: return () => context.push(AppRoutes.superwin);
      case 3: return () => context.push(AppRoutes.dominguero);
      case 6: return () => context.push(AppRoutes.chanceMillonario);
      case 7: return () => context.push(AppRoutes.pataMillonaria);
      case 9: return () => context.push(AppRoutes.balotoRevancha);
      default: return null;
    }
  }
}

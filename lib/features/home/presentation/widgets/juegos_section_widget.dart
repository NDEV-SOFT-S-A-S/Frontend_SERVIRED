import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import 'juego_card_widget.dart';
import 'section_header_widget.dart';

// Figma nodes 561:8133 y 561:8139
// 2 filas de 5 tarjetas (288×360px), gap ~58px entre tarjetas
// Imágenes verificadas por hash SHA-1 contra Figma — sin duplicados
//
// Fila 1: La Pata Millonaria · El Domingueño Millonario · Paga Todo
//         Baloto Revancha · Doble Chance
// Fila 2: La Quinta · Chance · Quincenazo
//         Chance Millonario Sorprendente · Chance Superwin

const kJuegos = [
  // ── Fila 1 ────────────────────────────────────────────────────────────────
  JuegoData(
    imageUrl: AppAssets.juegoImg1,   // La Pata Millonaria
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg2,   // El Domingueño Millonario
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg3,   // Paga Todo
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg4,   // Baloto Revancha (juego_4.jpeg)
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg5,   // Doble Chance
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  // ── Fila 2 ────────────────────────────────────────────────────────────────
  JuegoData(
    imageUrl: AppAssets.juegoImg6,   // La Quinta
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg7,   // Chance
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg8,   // Quincenazo
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg9,   // Chance Millonario Sorprendente
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
  JuegoData(
    imageUrl: AppAssets.juegoImg10,  // Chance Superwin
    label: 'Apostá desde 2.000 y ganá hasta',
    monto: '\$118.278.000',
  ),
];

class JuegosSectionWidget extends StatelessWidget {
  const JuegosSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final row1 = kJuegos.sublist(0, 5);
    final row2 = kJuegos.sublist(5, 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header "Juegos" ─────────────────────────────────────────────────
        SectionHeaderWidget(
          icon: const Icon(
            Icons.sports_esports_rounded,
            size: 28,
            color: AppColors.neutralWhite,
          ),
          title: 'Juegos',
          showVerMas: true,
          onVerMas: () => context.go(AppRoutes.juegos),
        ),
        const SizedBox(height: 16),

        // ── Fila 1 ──────────────────────────────────────────────────────────
        _JuegosRow(juegos: row1, startIndex: 0),
        const SizedBox(height: 16),

        // ── Fila 2 ──────────────────────────────────────────────────────────
        _JuegosRow(juegos: row2, startIndex: 5),
      ],
    );
  }
}

class _JuegosRow extends StatelessWidget {
  const _JuegosRow({required this.juegos, required this.startIndex});

  final List<JuegoData> juegos;
  // Índice global del primer elemento de esta fila dentro de kJuegos
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1500;
        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < juegos.length; i++)
                JuegoCardWidget(
                  data: juegos[i],
                  onTap: _tapFor(context, startIndex + i),
                ),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < juegos.length; i++) ...[
                JuegoCardWidget(
                  data: juegos[i],
                  onTap: _tapFor(context, startIndex + i),
                ),
                if (i < juegos.length - 1) const SizedBox(width: 58),
              ],
            ],
          ),
        );
      },
    );
  }

  // Solo el juego en índice 1 (El Dominguero Millonario) tiene navegación
  VoidCallback? _tapFor(BuildContext context, int globalIndex) {
    if (globalIndex == 1) {
      return () => context.go(AppRoutes.dominguero);
    }
    return null;
  }
}

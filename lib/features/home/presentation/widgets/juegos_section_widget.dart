import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../../shared/utils/auth_modal.dart';
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

  // ── Desktop: grid unificado con Wrap ────────────────────────────────────
  // El gap se calcula siempre a partir de 5 columnas, de modo que la fila 3
  // (2 cards) empiece desde la izquierda con el mismo espaciado que las filas
  // completas. WrapAlignment.start garantiza que no se centra ni se distribuye.
  Widget _buildDesktop(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
      const int    cols      = 5;
      const double cardWidth = 288.0;
      final double gap =
          (constraints.maxWidth - cols * cardWidth) / (cols - 1);

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
          Wrap(
            alignment: WrapAlignment.start,
            spacing: gap,
            runSpacing: 16,
            children: [
              for (int i = 0; i < kJuegos.length; i++)
                JuegoCardWidget(
                  data: kJuegos[i],
                  onTap: _tapFor(context, i),
                ),
            ],
          ),
        ],
      );
      },
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

  // Ruta interna del juego según su índice global.
  // null → juego aún sin pantalla implementada.
  VoidCallback? _routeFor(BuildContext context, int i) {
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

  // Siempre devuelve un callback:
  //   · Sin sesión → abre modal de login directamente (sin pasos intermedios).
  //   · Con sesión + ruta → navega al juego.
  //   · Con sesión + sin ruta → no hace nada (juego no implementado aún).
  VoidCallback _tapFor(BuildContext context, int i) {
    final route = _routeFor(context, i);
    return () {
      final s = context.read<AuthCubit>().state;
      final isLoggedIn = s.user != null ||
          s.status == AuthStatus.success ||
          s.status == AuthStatus.registrationSuccess;

      if (!isLoggedIn) {
        showLoginRequired(context);
        return;
      }

      if (route != null) route();
    };
  }
}


import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import 'acumulado_card_widget.dart';
import 'section_header_widget.dart';

// Figma node 561:8102 — Frame 2085663139
// 4 × "Tarjeta acumulados" (340×470px), gap-[36px], items-center justify-center
// Distribución: card x=108, gap=36, card x=484, gap=36, card x=860, gap=36, card x=1236
// Total cards+gaps: 4×340 + 3×36 = 1468px (centrado en 1684px → 108px cada lado)

const _kAcumulados = [
  // ── Tarjeta 1 — Doble Chance ──────────────────────────────────────────────
  // Variante standard: logo top 135×63 (blanco), 2 bloques con subtítulo
  AcumuladoData(
    variant: AcumuladoVariant.standard,
    topLogoUrl: AppAssets.logoDobleChance,
    blocks: [
      AcumuladoBlock(subtitle: '3 cifras', amount: '\$12,4'),
      AcumuladoBlock(subtitle: '4 cifras', amount: '\$12,4'),
    ],
    countdown: Duration(hours: 23, minutes: 40, seconds: 16),
  ),
  // ── Tarjeta 2 — Baloto / Revancha ────────────────────────────────────────
  // Variante standard: logo top 135×63 (blanco), 2 bloques con subtítulo
  AcumuladoData(
    variant: AcumuladoVariant.standard,
    topLogoUrl: AppAssets.logoBalotoRevancha,
    blocks: [
      AcumuladoBlock(subtitle: 'Sin revancha', amount: '\$36.000'),
      AcumuladoBlock(subtitle: 'Con revancha', amount: '\$2.000'),
    ],
    countdown: Duration(hours: 23, minutes: 40, seconds: 16),
  ),
  // ── Tarjeta 3 — Chance Millonario ─────────────────────────────────────────
  // Variante largeLogoSingle: logo grande h-139 centrado + un bloque de premio
  AcumuladoData(
    variant: AcumuladoVariant.largeLogoSingle,
    topLogoUrl: AppAssets.logoChanceMillonario,
    blocks: [
      AcumuladoBlock(amount: '\$1.560'),
    ],
    countdown: Duration(hours: 23, minutes: 40, seconds: 16),
  ),
  // ── Tarjeta 4 — MiLoto + iColorLoto ──────────────────────────────────────
  // Variante dualLogo: sin logo superior, cada bloque tiene su propio logo
  // Figma: MiLoto (img h=46) → $150 → Millones / ColorLoto (img h=40) → $1.760 → Millones
  AcumuladoData(
    variant: AcumuladoVariant.dualLogo,
    blocks: [
      AcumuladoBlock(logoUrl: AppAssets.logoMiLoto, amount: '\$150'),
      AcumuladoBlock(logoUrl: AppAssets.logoIColorLoto, amount: '\$1.760'),
    ],
    countdown: Duration(hours: 23, minutes: 40, seconds: 16),
  ),
];

class AcumuladosSectionWidget extends StatelessWidget {
  const AcumuladosSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Encabezado "Acumulados" — Icon 32×32, Inter Bold 32px white ──────
        // Figma node 561:8096: Icon 32×32, gap-8, texto bold 32px white
        SectionHeaderWidget(
          icon: SvgPicture.asset(
            AppAssets.iconAcumulados,
            width: 32,
            height: 32,
          ),
          title: 'Acumulados',
        ),

        const SizedBox(height: 16),

        // ── 4 tarjetas ───────────────────────────────────────────────────────
        // Ancho mínimo para desktop: 4×340 + 3×36 = 1468px
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1468) {
              return const _WideCardRow();
            }
            return const _ScrollableCardRow();
          },
        ),
      ],
    );
  }
}

// ── Desktop: 4 tarjetas con gap exacto de 36px (Figma: gap-[36px]) ────────────
class _WideCardRow extends StatelessWidget {
  const _WideCardRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _kAcumulados.length; i++) ...[
          AcumuladoCardWidget(data: _kAcumulados[i]),
          if (i < _kAcumulados.length - 1) const SizedBox(width: 36),
        ],
      ],
    );
  }
}

// ── Tablet/Mobile: scroll horizontal ─────────────────────────────────────────
class _ScrollableCardRow extends StatelessWidget {
  const _ScrollableCardRow();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < _kAcumulados.length; i++) ...[
            AcumuladoCardWidget(data: _kAcumulados[i]),
            if (i < _kAcumulados.length - 1) const SizedBox(width: 36),
          ],
        ],
      ),
    );
  }
}

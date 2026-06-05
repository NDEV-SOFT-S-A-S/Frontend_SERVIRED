import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Modelo ─────────────────────────────────────────────────────────────────

class ResultadoData {
  const ResultadoData({
    this.logoUrl,
    required this.nombre,
    required this.fecha,
    required this.numeros,
    this.subtitulo,
    this.serie,
  });

  final String? logoUrl;
  final String nombre;
  final String fecha;
  final List<int> numeros;
  final String? subtitulo;
  final String? serie;
}

// ── Widget ─────────────────────────────────────────────────────────────────

// Desktop (Figma 534:1742): 273×146px, backdrop-blur 2px,
//   gradient rgba(44,46,111,0.5)→rgba(84,88,213,0.5), rounded-16
//   Logo: white 48×48 rounded-8, left:22 top:12
//   Nombre: Inter SemiBold 16px · Fecha: 14px
//   Números: fila bg rgba(90,92,192,0.5) rounded-8, left:21 top:70
//            chip white 45×43 rounded-60px, número Inter SemiBold 33px #2C2E6F
//
// Mobile (Figma 553:2135): 106×66px, rounded-8
//   gradient rgba(5,60,97,0.77)→rgba(0,100,167,0.77)
//   Logo: white 28×22 rounded-6, left:5.6 top:5.6
//   Nombre: Inter SemiBold 6px, left:40 top:6.7
//   Fecha:  Inter Regular 6px, left:40 top:15.7
//   Números: fila bg rgba(90,92,192,0.5) rounded-8, top:33.6 left:5.6 right:5.6 bottom:5.6
//            chip white ~18×17px rounded-60px, número Inter SemiBold 13px #2C2E6F

class ResultadoCardWidget extends StatelessWidget {
  const ResultadoCardWidget({
    super.key,
    required this.data,
    this.compact = false,
  });

  final ResultadoData data;
  /// compact=true → versión mobile 106×66px
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildMobile();
    return _buildDesktop();
  }

  Widget _buildDesktop() {
    return SizedBox(
      width: 273,
      height: 146,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x802C2E6F),
                  AppColors.resultadoEnd,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 22,
                  top: 12,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: data.logoUrl != null
                        ? Image.asset(
                            data.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const _LogoFallback(),
                          )
                        : const _LogoFallback(),
                  ),
                ),
                Positioned(
                  left: 97,
                  top: 11,
                  width: 151,
                  height: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data.nombre,
                        style: AppTextStyles.resultadoNombre,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        data.fecha,
                        style: AppTextStyles.resultadoFecha,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 21,
                  top: 70,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.resultadoNumRow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < data.numeros.length; i++) ...[
                          _NumeroChip(numero: data.numeros[i]),
                          if (i < data.numeros.length - 1)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mobile: 106×66px — proporciones exactas de Figma node 553:2135
  Widget _buildMobile() {
    return SizedBox(
      width: 106,
      height: 66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xC4053C61), // rgba(5,60,97,0.77)
                Color(0xC40064A7), // rgba(0,100,167,0.77)
              ],
            ),
          ),
          child: Stack(
            children: [
              // ── Logo ────────────────────────────────────────────────────
              Positioned(
                left: 5.6,
                top: 5.6,
                child: Container(
                  width: 28,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: data.logoUrl != null
                      ? Image.asset(
                          data.logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const _LogoFallback(),
                        )
                      : const _LogoFallback(),
                ),
              ),

              // ── Nombre ──────────────────────────────────────────────────
              Positioned(
                left: 40,
                top: 6.7,
                right: 4,
                child: Text(
                  data.nombre,
                  style: AppTextStyles.resultadoNombre.copyWith(
                    fontSize: 6,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Fecha ────────────────────────────────────────────────────
              Positioned(
                left: 40,
                top: 15.7,
                right: 4,
                child: Text(
                  data.fecha,
                  style: AppTextStyles.resultadoFecha.copyWith(fontSize: 6),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Fila de números ─────────────────────────────────────────
              // bg rgba(90,92,192,0.5): top=33.6, left=5.6, right=5.6, bottom=5.6
              Positioned(
                left: 5.6,
                right: 5.6,
                top: 33.6,
                bottom: 5.6,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.resultadoNumRow,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final n in data.numeros)
                        _NumeroChipCompact(numero: n),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Desktop chip: bg white 45×43px rounded-60px, Inter SemiBold 33px #2C2E6F
class _NumeroChip extends StatelessWidget {
  const _NumeroChip({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 45,
      height: 43,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString(),
        style: AppTextStyles.resultadoNumero,
      ),
    );
  }
}

// Mobile chip: bg white ~18×17px rounded-60px, Inter SemiBold 13px #2C2E6F
class _NumeroChipCompact extends StatelessWidget {
  const _NumeroChipCompact({required this.numero});

  final int numero;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 17,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
      ),
      alignment: Alignment.center,
      child: Text(
        numero.toString(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2C2E6F),
          height: 1.0,
        ),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EAF6),
      child: const Icon(Icons.casino, color: Colors.grey, size: 24),
    );
  }
}

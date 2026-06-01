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
  });

  final String? logoUrl;
  final String nombre;
  final String fecha;
  final List<int> numeros; // 4 números del sorteo
}

// ── Widget ─────────────────────────────────────────────────────────────────

// Figma node 534:1742
// 273×146px, backdrop-blur 2px,
// gradient rgba(44,46,111,0.5) → rgba(84,88,213,0.5), rounded-16
// Logo: bg white 48×48px rounded-8, left:22 top:12
// Nombre: Inter SemiBold 16px, white — left:97 top:11
// Fecha:  Inter Regular 14px, white
// Números: fila bg rgba(90,92,192,0.5), rounded-8, left:21 top:70, p:10 gap:10
//           chip bg white 45×43px rounded-60px, número Inter SemiBold 33px #2C2E6F

class ResultadoCardWidget extends StatelessWidget {
  const ResultadoCardWidget({super.key, required this.data});

  final ResultadoData data;

  @override
  Widget build(BuildContext context) {
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
                  Color(0x802C2E6F), // rgba(44,46,111,0.5)
                  AppColors.resultadoEnd,
                ],
              ),
            ),
            child: Stack(
              children: [
                // ── Logo ──────────────────────────────────────────────────
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

                // ── Nombre y fecha ─────────────────────────────────────────
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

                // ── Fila de números ────────────────────────────────────────
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
}

// Chip de número: bg white 45×43px rounded-60px, Inter SemiBold 33px #2C2E6F
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

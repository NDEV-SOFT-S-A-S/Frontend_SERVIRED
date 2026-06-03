import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

// Figma: ".❖ Main / Input Validation" — nodo 145:1668
// Container: bg #feefef · rounded-11px · px-16 py-6 · gap-4 (ícono↔texto)
// Ícono "Alert / error": 16×16 · color #da1414 · py-2 (alineación vertical)
// Texto: Inter Light · 12px · lh-18 · #da1414

class InputErrorBox extends StatelessWidget {
  const InputErrorBox({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.errorBg,             // #feefef
        borderRadius: BorderRadius.circular(11),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono: contenedor con pt-2 para alineación con texto
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_rounded,
              size: 16,
              color: AppColors.error,          // #da1414
            ),
          ),
          const SizedBox(width: 4),
          // Texto: Inter Light 12px #da1414 lh-18
          Expanded(
            child: Text(
              errorText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                height: 18 / 12,
                color: AppColors.error,        // #da1414
              ),
            ),
          ),
        ],
      ),
    );
  }
}

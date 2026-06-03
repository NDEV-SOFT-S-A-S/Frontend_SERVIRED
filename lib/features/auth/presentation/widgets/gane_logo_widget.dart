import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Logo GANE reconstruido con widgets Flutter.
/// Reemplazar con asset SVG cuando esté disponible en assets/images/logo_gane.svg
class GaneLogoWidget extends StatelessWidget {
  const GaneLogoWidget({super.key, this.size = 80});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bienvenido
        Text(
          'Bienvenido',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),

        // Logo principal — estrella dorada + "Gane"
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Estrella / ícono dorado
            Container(
              width: size * 0.55,
              height: size * 0.55,
              decoration: const BoxDecoration(
                color: AppColors.accent500,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.star_rounded,
                color: AppColors.primary700,
                size: size * 0.35,
              ),
            ),
            const SizedBox(width: 4),
            // Texto "Gane"
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'G',
                    style: GoogleFonts.poppins(
                      fontSize: size * 0.45,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accent500,
                      height: 1,
                    ),
                  ),
                  TextSpan(
                    text: 'ane',
                    style: GoogleFonts.poppins(
                      fontSize: size * 0.40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary700,
                      height: 1,
                    ),
                  ),
                  WidgetSpan(
                    child: Transform.translate(
                      offset: const Offset(1, -6),
                      child: Text(
                        '®',
                        style: GoogleFonts.poppins(
                          fontSize: size * 0.16,
                          color: AppColors.primary700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Subtítulo
        Text(
          'Jamundí-Yumbo',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.neutral5,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

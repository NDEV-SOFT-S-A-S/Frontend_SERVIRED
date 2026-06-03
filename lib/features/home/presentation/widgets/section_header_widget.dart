import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// Figma: header row h=36px, icono 28-32px, título Inter Bold 32/24, pill "Ver más"

class SectionHeaderWidget extends StatelessWidget {
  const SectionHeaderWidget({
    super.key,
    required this.icon,
    required this.title,
    this.showVerMas = false,
    this.onVerMas,
  });

  final Widget icon;
  final String title;
  final bool showVerMas;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // < 600px de ancho disponible → móvil (pantalla < ~640px con padding lateral)
        final bool compact = constraints.maxWidth < 600;
        return SizedBox(
          height: compact ? 28.0 : 36.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Icono + Título ─────────────────────────────────────────────
              icon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: compact
                      ? AppTextStyles.sectionTitle.copyWith(fontSize: 20)
                      : AppTextStyles.sectionTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ── Pill "Ver más" (solo en Resultados y Juegos) ───────────────
              if (showVerMas) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onVerMas,
                  child: Container(
                    // Figma: pl-16 pr-4 py-8, rounded-99px, bg rgba(255,255,255,0.16)
                    // Móvil: padding reducido para que quepan título + pill
                    padding: EdgeInsets.only(
                      left: compact ? 10 : 16,
                      right: compact ? 2 : 4,
                      top: 6,
                      bottom: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.seeMorePill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver más',
                          style: compact
                              ? AppTextStyles.verMasText.copyWith(fontSize: 12)
                              : AppTextStyles.verMasText,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: compact ? 16 : 20,
                          color: AppColors.neutralWhite,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Modelo ─────────────────────────────────────────────────────────────────

class JuegoData {
  const JuegoData({
    this.imageUrl,
    required this.label,
    required this.monto,
  });

  final String? imageUrl;
  final String label;
  final String monto;
}

// ── Widget ─────────────────────────────────────────────────────────────────

// Desktop (Figma I561:8134): 288×360px
//   Imagen: inset left:11 right:12 top:0 bottom:24, rounded-20
//   Bloque morado: h=87px rounded-30px, ancho 288px
//   Label: Poppins 13px · Monto: Inter ExtraBold 28px gold gradient
//
// Mobile (Figma 400:3285 etc): 155×164px
//   Imagen: inset left:17 right:17 top:0 bottom:23, rounded-20
//   Bloque morado: h=23px rounded-20
//   Label: Poppins 8px · Monto: Inter ExtraBold 16px gold gradient

class JuegoCardWidget extends StatefulWidget {
  const JuegoCardWidget({
    super.key,
    required this.data,
    this.onTap,
    this.compact = false,
  });

  final JuegoData data;
  final VoidCallback? onTap;
  /// compact=true en mobile (155×164), false en desktop (288×360)
  final bool compact;

  @override
  State<JuegoCardWidget> createState() => _JuegoCardWidgetState();
}

class _JuegoCardWidgetState extends State<JuegoCardWidget> {
  bool _hovered = false;

  // Gradiente dorado del monto (Figma: 119.096° stops)
  static const _goldGradient = LinearGradient(
    begin: Alignment(-0.485, -0.875),
    end: Alignment(0.485, 0.875),
    colors: AppColors.goldGradient,
    stops: [0.002, 0.106, 0.266, 0.790, 0.930],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildMobile();
    return _buildDesktop();
  }

  // ── Desktop: 288×360px ───────────────────────────────────────────────────
  Widget _buildDesktop() {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 288,
          height: 360,
          child: Stack(
            children: [
              Positioned(
                left: 11,
                right: 12,
                top: 0,
                bottom: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.data.imageUrl != null
                          ? Image.asset(
                              widget.data.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _GameImagePlaceholder(),
                            )
                          : _GameImagePlaceholder(),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1.0 : 0.0,
                        child: const ColoredBox(color: Color(0x66000000)),
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _hovered ? 1.0 : 0.0,
                        child: Center(
                          child: GestureDetector(
                            onTap: widget.onTap,
                            child: Container(
                              width: 120,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2DB35B),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40000000),
                                    offset: Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Jugar',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutralWhite,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 87,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: AppColors.primary700,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 13,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 228,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.data.label,
                            style: AppTextStyles.juegoCardLabel
                                .copyWith(height: 1.2),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                _goldGradient.createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: Text(
                              widget.data.monto,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile: 155×164px ────────────────────────────────────────────────────
  // Imagen: inset left:17 right:17 top:0 bottom:23, rounded-20
  // Bloque morado: h=50px bottom, rounded-20
  // Active: overlay oscuro + botón "Jugar" sobre la imagen (igual que desktop hover)
  Widget _buildMobile() {
    // Área de imagen: top=0, bottom=23 dentro del SizedBox(164)  → altura=141
    const imgBottom = 23.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) => setState(() => _hovered = false),
      onTapCancel: () => setState(() => _hovered = false),
      child: SizedBox(
        width: 155,
        height: 164,
        child: Stack(
          children: [
            // Imagen con overlay y botón Jugar
            Positioned(
              left: 17,
              right: 17,
              top: 0,
              bottom: imgBottom,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.data.imageUrl != null
                        ? Image.asset(
                            widget.data.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _GameImagePlaceholder(),
                          )
                        : _GameImagePlaceholder(),
                    // Overlay oscuro al activar
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _hovered ? 1.0 : 0.0,
                      child: const ColoredBox(color: Color(0x66000000)),
                    ),
                    // Botón Jugar centrado
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _hovered ? 1.0 : 0.0,
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2DB35B),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40000000),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Jugar',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutralWhite,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bloque morado inferior
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: AppColors.primary700,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.data.label,
                      style: AppTextStyles.juegoCardLabel.copyWith(
                        fontSize: 8,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          _goldGradient.createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        widget.data.monto,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2C5B), Color(0xFF0D1A3A)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.sports_esports_outlined,
          color: Colors.white24,
          size: 64,
        ),
      ),
    );
  }
}

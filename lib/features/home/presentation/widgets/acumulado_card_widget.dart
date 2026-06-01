import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Modelos de datos ──────────────────────────────────────────────────────────

/// Variante de layout — determina la estructura interna de la tarjeta
enum AcumuladoVariant {
  /// Tarjetas 1 y 2: logo superior 135×63 + 2 bloques con subtítulo de texto
  standard,

  /// Tarjeta 3: logo grande centrado (h=139) + un solo bloque de premio
  largeLogoSingle,

  /// Tarjeta 4: sin logo superior; cada bloque tiene su propio logo
  dualLogo,
}

/// Un bloque de premio: logo opcional (solo dualLogo), subtítulo opcional
/// (solo standard), siempre tiene monto
class AcumuladoBlock {
  const AcumuladoBlock({this.logoUrl, this.subtitle, required this.amount});

  /// Logo por bloque — solo variante dualLogo (tarjeta 4)
  final String? logoUrl;

  /// Subtítulo de texto — solo variante standard (tarjetas 1 y 2)
  final String? subtitle;

  /// Monto acumulado: "\$12,4", "\$36.000", etc.
  final String amount;
}

/// Datos de una tarjeta acumulado
class AcumuladoData {
  const AcumuladoData({
    required this.variant,
    this.topLogoUrl,
    required this.blocks,
    required this.countdown,
  });

  final AcumuladoVariant variant;

  /// Logo superior — variantes standard y largeLogoSingle
  final String? topLogoUrl;

  final List<AcumuladoBlock> blocks;
  final Duration countdown;
}

// ── Widget principal ──────────────────────────────────────────────────────────

// Figma node 561:8103–8106 — "Tarjeta acumulados"
// Tamaño: 340×470px
// backdrop-blur-25 · gradient rgba(44,46,111,0.5)→rgba(19,114,174,0.5)
// border 1px rgba(173,70,255,0.3) · rounded-16
// padding vertical: py-19 (el padding horizontal es por ítem, no global)
//   - contenido:  px-33 aplicado en cada ítem
//   - timer:      px-8  (→ timer w ≈ 324px, match Figma w-[323.328px])
// Hover: glow amarillo externo, difuso, sin mover ni escalar la tarjeta

class AcumuladoCardWidget extends StatefulWidget {
  const AcumuladoCardWidget({super.key, required this.data});

  final AcumuladoData data;

  @override
  State<AcumuladoCardWidget> createState() => _AcumuladoCardWidgetState();
}

class _AcumuladoCardWidgetState extends State<AcumuladoCardWidget> {
  late Duration _remaining;
  Timer? _timer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.data.countdown;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining.inSeconds > 0) {
        setState(() => _remaining -= const Duration(seconds: 1));
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: 340,
        height: 470,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Glow exterior — BlurStyle.outer pinta SOLO fuera del RRect.
            // Al no haber color dentro del RRect, el BackdropFilter de la tarjeta
            // no captura el glow y el gradiente interior mantiene su azul limpio.
            AnimatedOpacity(
              opacity: _isHovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const CustomPaint(
                size: Size(340, 470),
                painter: _CardGlowPainter(),
              ),
            ),
            // Tarjeta — el BackdropFilter solo ve el fondo real de la página
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  width: 340,
                  height: 470,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.cardBlueStart, AppColors.cardBlueEnd],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.cardBorderPurple,
                      width: 1,
                    ),
                  ),
                  // Solo padding vertical — el horizontal se aplica por ítem
                  padding: const EdgeInsets.symmetric(vertical: 19),
                  child: _buildContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.data.variant) {
      case AcumuladoVariant.standard:
        return _buildStandard();
      case AcumuladoVariant.largeLogoSingle:
        return _buildLargeLogoSingle();
      case AcumuladoVariant.dualLogo:
        return _buildDualLogo();
    }
  }

  // ── Standard (tarjetas 1 & 2): logo top 135×63 + 2 bloques con subtítulo ───
  Widget _buildStandard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo superior — fondo blanco 135×63, rounded-10
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 33),
                  child: Container(
                    width: 135,
                    height: 63,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: widget.data.topLogoUrl != null
                        ? Image.asset(
                            widget.data.topLogoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
                          )
                        : const _LogoPlaceholder(),
                  ),
                ),

                // Bloques de premio (×2)
                for (final block in widget.data.blocks) ...[
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      block.subtitle ?? '',
                      style: AppTextStyles.acumuladoSubtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 33),
                    child: Text(
                      block.amount,
                      style: AppTextStyles.acumuladoAmount,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    'Millones',
                    style: AppTextStyles.acumuladoMillones,
                  ),
                ],
              ],
            ),
          ),
        ),

        // Timer — px-8 para alcanzar ~324px (Figma w-[323.328px])
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _TimerBox(remaining: _remaining),
        ),
      ],
    );
  }

  // ── Large logo single (tarjeta 3): logo grande h-139 centrado + 1 bloque ───
  // Figma: contenedor h-139 flex-col items-center justify-center
  //        → bg blanco px-8 py-4 rounded-10, imagen 120×55 con sombra
  Widget _buildLargeLogoSingle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Logo grande — h-139 centrado, fondo blanco con sombra
        SizedBox(
          height: 139,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(3, 5),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: widget.data.topLogoUrl != null
                  ? Image.asset(
                      widget.data.topLogoUrl!,
                      width: 120,
                      height: 55,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
                    )
                  : const _LogoPlaceholder(),
            ),
          ),
        ),

        // Monto — Figma: h-72 flex-col justify-center 48px ExtraBold
        SizedBox(
          height: 72,
          child: Center(
            child: Text(
              widget.data.blocks.first.amount,
              style: AppTextStyles.acumuladoAmount,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // "Millones" — Figma: h-37 centrado
        SizedBox(
          height: 37,
          child: Center(
            child: Text(
              'Millones',
              style: AppTextStyles.acumuladoMillones,
            ),
          ),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _TimerBox(remaining: _remaining),
        ),
      ],
    );
  }

  // ── Dual logo (tarjeta 4): 2 bloques, cada uno con su propio logo ───────────
  // Figma: MiLoto (h-65, img h-46) + $150 + Millones
  //        ColorLoto (h-57, img h-40) + $1.760 + Millones
  //        → Spacer → Timer
  Widget _buildDualLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < widget.data.blocks.length; i++)
          _buildDualLogoBlock(widget.data.blocks[i], i),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _TimerBox(remaining: _remaining),
        ),
      ],
    );
  }

  /// Un bloque logo+monto+Millones para la tarjeta 4
  /// index 0 = MiLoto: containerH=65, imgH=46
  /// index 1 = ColorLoto: containerH=57, imgH=40
  ///
  /// Los textos usan altura natural (acumuladoAmount≈48px, acumuladoMillones≈27px)
  /// en lugar de SizedBox fijos, para evitar overflow del card (470-2×19=432px).
  Widget _buildDualLogoBlock(AcumuladoBlock block, int index) {
    final containerH = index == 0 ? 65.0 : 57.0;
    final imageH = index == 0 ? 46.0 : 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Contenedor logo con altura fija para el centrado vertical de Figma
        SizedBox(
          height: containerH,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: block.logoUrl != null
                  ? Image.asset(
                      block.logoUrl!,
                      width: 120,
                      height: imageH,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
                    )
                  : const _LogoPlaceholder(),
            ),
          ),
        ),

        // Monto — altura natural: fontSize 48 × height 1.0 ≈ 48px
        Text(
          block.amount,
          style: AppTextStyles.acumuladoAmount,
          textAlign: TextAlign.center,
        ),

        // "Millones" — altura natural: fontSize 25 × height 27/25 ≈ 27px
        Text(
          'Millones',
          style: AppTextStyles.acumuladoMillones,
        ),
      ],
    );
  }
}

// ── Glow exterior de la tarjeta en estado activo ─────────────────────────────

// BlurStyle.outer → pinta el halo SOLO fuera del RRect, dejando el interior
// completamente transparente. Así el BackdropFilter de la tarjeta no captura
// el color amarillo y el gradiente interior permanece azul sin contaminación.
class _CardGlowPainter extends CustomPainter {
  const _CardGlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ),
      Paint()
        ..color = AppColors.navActiveYellow
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18),
    );
  }

  @override
  bool shouldRepaint(_CardGlowPainter old) => false;
}

// ── Logo placeholder ──────────────────────────────────────────────────────────

class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.casino_outlined, color: Colors.grey, size: 32),
    );
  }
}

// ── Caja "Próximo sorteo" + countdown ─────────────────────────────────────────

// Figma: bg rgba(16,90,136,0.74) · h-124 · rounded-10 · pt-16 px-16 · gap-8
// Label row: Icon 16×16 + texto Inter Regular 14px white
// Columnas:  bg #fafafa · h-64 · rounded-10 · pt-8 px-8

class _TimerBox extends StatelessWidget {
  const _TimerBox({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);

    return Container(
      height: 124,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      decoration: BoxDecoration(
        color: AppColors.timerBoxBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label "Próximo sorteo" — Icon 16×16 + texto 14px
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppColors.neutralWhite,
              ),
              const SizedBox(width: 8),
              Text('Próximo sorteo', style: AppTextStyles.timerProximo),
            ],
          ),
          const SizedBox(height: 8),
          // Tres columnas Horas / Mins / Secs
          Row(
            children: [
              Expanded(child: _TimerColumn(value: h, label: 'Horas')),
              const SizedBox(width: 8),
              Expanded(child: _TimerColumn(value: m, label: 'Mins')),
              const SizedBox(width: 8),
              Expanded(child: _TimerColumn(value: s, label: 'Secs')),
            ],
          ),
        ],
      ),
    );
  }
}

// Figma: bg #fafafa · h-64 · rounded-10 · pt-8 px-8
// Número: Inter Bold 24px h-32 leading-32 #1372ae
// Label:  Inter Regular 12px h-16 leading-16 #1372ae

class _TimerColumn extends StatelessWidget {
  const _TimerColumn({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: Text(
              value.toString().padLeft(2, '0'),
              style: AppTextStyles.timerNumber,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: 16,
            child: Text(
              label,
              style: AppTextStyles.timerLabel,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

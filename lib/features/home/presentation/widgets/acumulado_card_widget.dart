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

// Figma desktop: 340×470px · rounded-16 · py-19 · px-33 · timer px-8
// Figma mobile:  162×233px · rounded-8  · proporciones similares escaladas
// backdrop-blur-25 · gradient rgba(44,46,111,0.5)→rgba(19,114,174,0.5)
// border 1px rgba(173,70,255,0.3)
// Hover (solo desktop): glow amarillo externo difuso

class AcumuladoCardWidget extends StatefulWidget {
  const AcumuladoCardWidget({
    super.key,
    required this.data,
    this.compact = false,
  });

  final AcumuladoData data;
  /// compact=true en mobile (162×233), false en desktop (340×470)
  final bool compact;

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

  bool get _compact => widget.compact;

  @override
  Widget build(BuildContext context) {
    final double cardW = _compact ? 162.0 : 340.0;
    final double cardH = _compact ? 233.0 : 470.0;
    final double radius = _compact ? 8.0 : 16.0;
    final double vPad = _compact ? 10.0 : 19.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: SizedBox(
        width: cardW,
        height: cardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedOpacity(
              opacity: _isHovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: CustomPaint(
                size: Size(cardW, cardH),
                painter: _CardGlowPainter(radius: radius),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  width: cardW,
                  height: cardH,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.cardBlueStart, AppColors.cardBlueEnd],
                    ),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: AppColors.cardBorderPurple,
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: vPad),
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

  // ── Standard (tarjetas 1 & 2) ────────────────────────────────────────────────
  // Desktop: logo 135×63 · px-33 · subtítulo/monto/Millones
  // Mobile:  logo 58×27  · px-8  · FittedBox escala
  Widget _buildStandard() {
    final double logoPH = _compact ? 8.0 : 33.0;
    final double logoW = _compact ? 58.0 : 135.0;
    final double logoH = _compact ? 27.0 : 63.0;
    final double logoR = _compact ? 5.0 : 10.0;

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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: logoPH),
                  child: Container(
                    width: logoW,
                    height: logoH,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(logoR),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: widget.data.topLogoUrl != null
                        ? Image.asset(
                            widget.data.topLogoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const _LogoPlaceholder(),
                          )
                        : const _LogoPlaceholder(),
                  ),
                ),

                for (final block in widget.data.blocks) ...[
                  Padding(
                    padding: EdgeInsets.all(_compact ? 5 : 10),
                    child: Text(
                      block.subtitle ?? '',
                      style: _compact
                          ? AppTextStyles.acumuladoSubtitle
                              .copyWith(fontSize: 8)
                          : AppTextStyles.acumuladoSubtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: logoPH),
                    child: Text(
                      block.amount,
                      style: _compact
                          ? AppTextStyles.acumuladoAmount.copyWith(fontSize: 22)
                          : AppTextStyles.acumuladoAmount,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Text(
                    'Millones',
                    style: _compact
                        ? AppTextStyles.acumuladoMillones
                            .copyWith(fontSize: 12)
                        : AppTextStyles.acumuladoMillones,
                  ),
                ],
              ],
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: _compact ? 4 : 8),
          child: _TimerBox(remaining: _remaining, compact: _compact),
        ),
      ],
    );
  }

  // ── Large logo single (tarjeta 3) ────────────────────────────────────────────
  Widget _buildLargeLogoSingle() {
    final double logoContainerH = _compact ? 65.0 : 139.0;
    final double logoW = _compact ? 55.0 : 120.0;
    final double logoH = _compact ? 25.0 : 55.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: logoContainerH,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _compact ? 4 : 8,
                vertical: _compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_compact ? 5 : 10),
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
                      width: logoW,
                      height: logoH,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
                    )
                  : const _LogoPlaceholder(),
            ),
          ),
        ),

        SizedBox(
          height: _compact ? 34 : 72,
          child: Center(
            child: Text(
              widget.data.blocks.first.amount,
              style: _compact
                  ? AppTextStyles.acumuladoAmount.copyWith(fontSize: 22)
                  : AppTextStyles.acumuladoAmount,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        SizedBox(
          height: _compact ? 18 : 37,
          child: Center(
            child: Text(
              'Millones',
              style: _compact
                  ? AppTextStyles.acumuladoMillones.copyWith(fontSize: 12)
                  : AppTextStyles.acumuladoMillones,
            ),
          ),
        ),

        const Spacer(),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: _compact ? 4 : 8),
          child: _TimerBox(remaining: _remaining, compact: _compact),
        ),
      ],
    );
  }

  // ── Dual logo (tarjeta 4) ────────────────────────────────────────────────────
  Widget _buildDualLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < widget.data.blocks.length; i++)
          _buildDualLogoBlock(widget.data.blocks[i], i),

        const Spacer(),

        Padding(
          padding: EdgeInsets.symmetric(horizontal: _compact ? 4 : 8),
          child: _TimerBox(remaining: _remaining, compact: _compact),
        ),
      ],
    );
  }

  Widget _buildDualLogoBlock(AcumuladoBlock block, int index) {
    final containerH = _compact
        ? (index == 0 ? 32.0 : 28.0)
        : (index == 0 ? 65.0 : 57.0);
    final imageH = _compact
        ? (index == 0 ? 22.0 : 18.0)
        : (index == 0 ? 46.0 : 40.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: containerH,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: _compact ? 4 : 8,
                vertical: _compact ? 2 : 4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_compact ? 5 : 10),
              ),
              child: block.logoUrl != null
                  ? Image.asset(
                      block.logoUrl!,
                      width: _compact ? 55.0 : 120.0,
                      height: imageH,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const _LogoPlaceholder(),
                    )
                  : const _LogoPlaceholder(),
            ),
          ),
        ),

        Text(
          block.amount,
          style: _compact
              ? AppTextStyles.acumuladoAmount.copyWith(fontSize: 22)
              : AppTextStyles.acumuladoAmount,
          textAlign: TextAlign.center,
        ),

        Text(
          'Millones',
          style: _compact
              ? AppTextStyles.acumuladoMillones.copyWith(fontSize: 12)
              : AppTextStyles.acumuladoMillones,
        ),
      ],
    );
  }
}

// ── Glow exterior de la tarjeta ───────────────────────────────────────────────

class _CardGlowPainter extends CustomPainter {
  const _CardGlowPainter({this.radius = 16});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ),
      Paint()
        ..color = AppColors.navActiveYellow
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18),
    );
  }

  @override
  bool shouldRepaint(_CardGlowPainter old) => old.radius != radius;
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

// Desktop: h-124 · rounded-10 · pt-16 px-16 · gap-8
//   Label: Icon 16×16 + texto 14px · Columnas h-64 · número 24px · label 12px
// Mobile:  h-56  · rounded-5  · pt-3  px-8  · gap-4
//   Label: Icon 8×8  + texto 8px  · Columnas h-34 · número 10px · label 6px

class _TimerBox extends StatelessWidget {
  const _TimerBox({required this.remaining, this.compact = false});

  final Duration remaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);

    return Container(
      height: compact ? 56 : 124,
      padding: compact
          ? const EdgeInsets.only(left: 8, right: 8, top: 3)
          : const EdgeInsets.only(left: 16, right: 16, top: 16),
      decoration: BoxDecoration(
        color: AppColors.timerBoxBg,
        borderRadius: BorderRadius.circular(compact ? 5 : 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: compact ? 8 : 16,
                color: AppColors.neutralWhite,
              ),
              SizedBox(width: compact ? 4 : 8),
              Text(
                'Próximo sorteo',
                style: compact
                    ? AppTextStyles.timerProximo.copyWith(fontSize: 8)
                    : AppTextStyles.timerProximo,
              ),
            ],
          ),
          SizedBox(height: compact ? 4 : 8),
          Row(
            children: [
              Expanded(
                child: _TimerColumn(
                  value: h,
                  label: 'Horas',
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              Expanded(
                child: _TimerColumn(
                  value: m,
                  label: 'Mins',
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              Expanded(
                child: _TimerColumn(
                  value: s,
                  label: 'Secs',
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Desktop: bg #fafafa · h-64 · rounded-10 · número 24px · label 12px
// Mobile:  bg #fafafa · h-34 · rounded-5  · número 10px · label 6px

class _TimerColumn extends StatelessWidget {
  const _TimerColumn({
    required this.value,
    required this.label,
    this.compact = false,
  });

  final int value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 34 : 64,
      padding: compact
          ? const EdgeInsets.only(top: 8, left: 4, right: 4)
          : const EdgeInsets.only(top: 8, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(compact ? 5 : 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: compact ? 15 : 32,
            child: Text(
              value.toString().padLeft(2, '0'),
              style: compact
                  ? AppTextStyles.timerNumber.copyWith(fontSize: 10)
                  : AppTextStyles.timerNumber,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            height: compact ? 6 : 16,
            child: Text(
              label,
              style: compact
                  ? AppTextStyles.timerLabel.copyWith(fontSize: 6)
                  : AppTextStyles.timerLabel,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

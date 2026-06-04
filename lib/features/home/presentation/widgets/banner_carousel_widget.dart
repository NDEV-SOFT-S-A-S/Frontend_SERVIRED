import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';

const _kBannerUrls = AppAssets.banners;

// Alignment por banner: ancla el borde donde están los logos para que BoxFit.cover
// no los recorte al ajustar el desborde horizontal (móvil) o vertical (desktop).
const _kBannerAlignments = [
  Alignment.bottomLeft,              // banner_1: Astro — logos Gane+Chance abajo izquierda
  Alignment(0.28, 1.0),              // banner_2: Baloto — ancla a la derecha para mostrar logo Gane/ChancE completo
  Alignment.bottomCenter,            // banner_3
  Alignment.bottomLeft,              // banner_4
];

// Figma desktop: banner 821×304px, gap 5px, carousel h=333px, botones 37×37px
// Figma móvil  : banner full-width, h=170px, viewportFraction=0.92, dots abajo
const double _kBannerH      = 304.0;
const double _kCarouselH    = 333.0;
const double _kBannerRadius = 16.0;
const double _kGap          = 5.0;
// viewportFraction desktop = (821+5) / 1688 para referencia 1728px
const double _kVFDesktop    = 0.489;
// viewportFraction móvil: muestra el banner activo + 8% del siguiente
const double _kVFMobile     = 0.92;

class BannerCarouselWidget extends StatefulWidget {
  const BannerCarouselWidget({super.key});

  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  // Dos controladores independientes para cada breakpoint.
  // Solo uno está activo a la vez (según LayoutBuilder en build()).
  late final PageController _desktopCtrl;
  late final PageController _mobileCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _desktopCtrl = PageController(viewportFraction: _kVFDesktop)
      ..addListener(_listenDesktop);
    _mobileCtrl = PageController(viewportFraction: _kVFMobile)
      ..addListener(_listenMobile);
  }

  void _listenDesktop() => _setPage(_desktopCtrl.page?.round() ?? 0);
  void _listenMobile()  => _setPage(_mobileCtrl.page?.round() ?? 0);

  void _setPage(int page) {
    if (page != _currentPage && mounted) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _desktopCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _prev() => _desktopCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _next() => _desktopCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) return _buildMobile();
        return _buildDesktop();
      },
    );
  }

  // ── Desktop: dos banners visibles, botones prev/next ──────────────────────
  Widget _buildDesktop() {
    const double vPad = (_kCarouselH - _kBannerH) / 2; // 14.5 px top/bottom

    return SizedBox(
      height: _kCarouselH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _desktopCtrl,
            padEnds: false,
            itemCount: _kBannerUrls.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(
                  right: _kGap,
                  top: vPad,
                  bottom: vPad,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kBannerRadius),
                  child: Image.asset(
                    _kBannerUrls[i],
                    fit: BoxFit.cover,
                    alignment: _kBannerAlignments[i],
                    errorBuilder: (_, __, ___) => _BannerPlaceholder(index: i),
                  ),
                ),
              );
            },
          ),

          Positioned(
            left: 11,
            top: 0,
            bottom: 0,
            child: Center(child: _NavButton(onTap: _prev, isForward: false)),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(child: _NavButton(onTap: _next, isForward: true)),
          ),
        ],
      ),
    );
  }

  // ── Móvil: un banner casi full-width (0.92 VF) + dots indicator ───────────
  // Todos los assets tienen ratio 821/304 = 2.701.
  // AspectRatio con ese valor hace que cover llene el contenedor exactamente
  // (sin recorte ni barras) en cualquier ancho de pantalla.
  Widget _buildMobile() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 821 / 304,
          child: PageView.builder(
            controller: _mobileCtrl,
            padEnds: false,
            itemCount: _kBannerUrls.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kBannerRadius),
                  child: Image.asset(
                    _kBannerUrls[i],
                    fit: BoxFit.cover,
                    alignment: _kBannerAlignments[i],
                    errorBuilder: (_, __, ___) => _BannerPlaceholder(index: i),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        _DotsIndicator(
          count: _kBannerUrls.length,
          current: _currentPage,
        ),
      ],
    );
  }
}

// ── Botón de navegación (desktop) ────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  const _NavButton({required this.onTap, required this.isForward});

  final VoidCallback onTap;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 37,
        height: 37,
        decoration: const BoxDecoration(
          color: Color(0xB3111827), // rgba(17,24,39,0.7)
          shape: BoxShape.circle,
        ),
        child: Icon(
          isForward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          color: AppColors.neutralWhite,
          size: 22,
        ),
      ),
    );
  }
}

// ── Dots indicator (móvil) ────────────────────────────────────────────────────
// Dot activo: 20×6px blanco · inactivo: 6×6px blanco 35% opacidad

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: active ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? AppColors.neutralWhite
                : AppColors.neutralWhite.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Placeholder cuando la imagen no carga ─────────────────────────────────────

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.index});

  final int index;

  static const _colors = [
    Color(0xFF1E3A5F),
    Color(0xFF0B4F6C),
    Color(0xFF1A2744),
    Color(0xFF0D3349),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _colors[index % _colors.length],
        borderRadius: BorderRadius.circular(_kBannerRadius),
      ),
      child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white38, size: 64),
      ),
    );
  }
}

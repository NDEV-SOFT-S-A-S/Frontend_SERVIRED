import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Figma: Header — dos variantes ────────────────────────────────────────────
//
// propiedad1="sin logueo" (node 561:8147) — 1728×104px
//   Derecha: botón "Inicia sesión" (#fafafa) + "Regístrate" (#fdc700)
//
// propiedad1="logueado" (node 561:10713) — 1725×120px
//   Derecha (gap-26 h-62 items-end justify-end w-459):
//     · Saldo: rounded-8 bg-#fafafa w-83 h-41 — $ icon (16px) + "$ 0" Nunito Bold 12
//     · Wallet: rounded-8 bg-#c7b322 w-41 h-41 — pi-wallet icon (25px) blanco
//     · Carrito: rounded-8 bg-#fafafa w-53 h-41 — shopping-cart icon (24px)
//     · Avatar: rounded-full w-44 h-45 — foto de usuario
//
// Ambas variantes comparten:
//   backdrop-blur-25 · bg-rgba(53,113,150,0.5) · px-21 · gap-27
//   Logo 150×66 · Nav (Inicio activo, Juegos, Resultados) gap-64

class NavbarWidget extends StatelessWidget {
  const NavbarWidget({
    super.key,
    this.onLoginTap,
    this.onRegisterTap,
    this.isLoggedIn = false,
    this.activeNavItem = 'Inicio',
    this.onInicioTap,
    this.onJuegosTap,
    this.onResultadosTap,
    this.saldo = r'$ 0',
    this.onWalletTap,
    this.onCartTap,
    this.onAvatarTap,
    this.userAvatarUrl,
  });

  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;

  /// Muestra el header logueado cuando es true.
  final bool isLoggedIn;

  /// Ítem activo del nav: 'Inicio', 'Juegos' o 'Resultados'.
  final String activeNavItem;

  final VoidCallback? onInicioTap;
  final VoidCallback? onJuegosTap;
  final VoidCallback? onResultadosTap;

  /// Texto de saldo mostrado en el widget Saldo (e.g. "$ 0", "$ 3.200").
  final String saldo;

  final VoidCallback? onWalletTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onAvatarTap;

  /// URL o ruta local de la foto de perfil del usuario. Si es null usa placeholder.
  final String? userAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return _NavbarMobile(
            isLoggedIn: isLoggedIn,
            onLoginTap: onLoginTap,
            onRegisterTap: onRegisterTap,
            onInicioTap: onInicioTap,
            onJuegosTap: onJuegosTap,
            onResultadosTap: onResultadosTap,
          );
        }
        return _NavbarDesktop(
          onLoginTap: onLoginTap,
          onRegisterTap: onRegisterTap,
          isLoggedIn: isLoggedIn,
          activeNavItem: activeNavItem,
          onInicioTap: onInicioTap,
          onJuegosTap: onJuegosTap,
          onResultadosTap: onResultadosTap,
          saldo: saldo,
          onWalletTap: onWalletTap,
          onCartTap: onCartTap,
          onAvatarTap: onAvatarTap,
          userAvatarUrl: userAvatarUrl,
        );
      },
    );
  }
}

// ── Desktop ───────────────────────────────────────────────────────────────────

class _NavbarDesktop extends StatelessWidget {
  const _NavbarDesktop({
    this.onLoginTap,
    this.onRegisterTap,
    required this.isLoggedIn,
    required this.activeNavItem,
    this.onInicioTap,
    this.onJuegosTap,
    this.onResultadosTap,
    required this.saldo,
    this.onWalletTap,
    this.onCartTap,
    this.onAvatarTap,
    this.userAvatarUrl,
  });

  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;
  final bool isLoggedIn;
  final String activeNavItem;
  final VoidCallback? onInicioTap;
  final VoidCallback? onJuegosTap;
  final VoidCallback? onResultadosTap;
  final String saldo;
  final VoidCallback? onWalletTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onAvatarTap;
  final String? userAvatarUrl;

  // Figma: 104px sin logueo · 120px logueado
  double get _height => isLoggedIn ? 120.0 : 104.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: _height,
          width: double.infinity,
          color: AppColors.navbarBg, // rgba(53,113,150,0.5)
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Logo 150×66 ───────────────────────────────────────────
              SvgPicture.asset(
                AppAssets.logoGane,
                width: 150,
                height: 66,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 27),

              // ── Nav Inicio · Juegos · Resultados ──────────────────────
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _NavItem(
                        label: 'Inicio',
                        isActive: activeNavItem == 'Inicio',
                        onTap: onInicioTap,
                      ),
                      const SizedBox(width: 64),
                      _NavItem(
                        label: 'Juegos',
                        isActive: activeNavItem == 'Juegos',
                        onTap: onJuegosTap,
                      ),
                      const SizedBox(width: 64),
                      _NavItem(
                        label: 'Resultados',
                        isActive: activeNavItem == 'Resultados',
                        onTap: onResultadosTap,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 27),

              // ── Zona derecha: botones O controles de usuario ──────────
              if (isLoggedIn)
                _UserControls(
                  saldo: saldo,
                  onWalletTap: onWalletTap,
                  onCartTap: onCartTap,
                  onAvatarTap: onAvatarTap,
                  userAvatarUrl: userAvatarUrl,
                )
              else
                _AuthButtons(
                  onLoginTap: onLoginTap,
                  onRegisterTap: onRegisterTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile ────────────────────────────────────────────────────────────────────
// Figma node 561:12013 — h-[44px], backdrop-blur-15, bg-[rgba(15,88,134,0.2)]
// Logo: 73×30px · Hamburger icon: 33×31px

class _NavbarMobile extends StatefulWidget {
  const _NavbarMobile({
    required this.isLoggedIn,
    this.onLoginTap,
    this.onRegisterTap,
    this.onInicioTap,
    this.onJuegosTap,
    this.onResultadosTap,
  });

  final bool isLoggedIn;
  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onInicioTap;
  final VoidCallback? onJuegosTap;
  final VoidCallback? onResultadosTap;

  @override
  State<_NavbarMobile> createState() => _NavbarMobileState();
}

class _NavbarMobileState extends State<_NavbarMobile> {
  OverlayEntry? _menuEntry;

  void _openMenu() {
    if (_menuEntry != null) return;
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final navbarOffset = renderBox.localToGlobal(Offset.zero);
    final navbarHeight = renderBox.size.height;
    final screenWidth = renderBox.size.width;

    _menuEntry = OverlayEntry(
      builder: (_) => _MobileMenuDropdown(
        top: navbarOffset.dy,
        right: 8,
        screenWidth: screenWidth,
        navbarHeight: navbarHeight,
        onClose: _closeMenu,
        onLoginTap: widget.isLoggedIn
            ? null
            : () {
                _closeMenu();
                widget.onLoginTap?.call();
              },
        onRegisterTap: widget.isLoggedIn
            ? null
            : () {
                _closeMenu();
                widget.onRegisterTap?.call();
              },
        onInicioTap: () {
          _closeMenu();
          widget.onInicioTap?.call();
        },
        onJuegosTap: () {
          _closeMenu();
          widget.onJuegosTap?.call();
        },
        onResultadosTap: () {
          _closeMenu();
          widget.onResultadosTap?.call();
        },
      ),
    );
    overlay.insert(_menuEntry!);
  }

  void _closeMenu() {
    _menuEntry?.remove();
    _menuEntry = null;
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Figma: h-44, blur 15, bg rgba(15,88,134,0.2)
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          height: 44,
          width: double.infinity,
          color: const Color(0x330F5886), // rgba(15,88,134,0.2)
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo: 73px ancho, ~30px alto (Figma node 561:12015)
              SvgPicture.asset(
                AppAssets.logoGane,
                width: 73,
                fit: BoxFit.fitWidth,
              ),
              const Spacer(),
              if (widget.isLoggedIn)
                _AvatarCircle(size: 32, avatarUrl: null, onTap: _openMenu)
              else
                // Hamburger 33×31px (Figma node 561:12038)
                GestureDetector(
                  onTap: _openMenu,
                  child: const SizedBox(
                    width: 33,
                    height: 31,
                    child: Icon(
                      Icons.menu_rounded,
                      color: AppColors.neutralWhite,
                      size: 26,
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

// ── Dropdown menu mobile ──────────────────────────────────────────────────────
// Figma node 561:12459
// backdrop-blur-25 · bg-[rgba(15,88,134,0.5)] · h-290 · w-287 · rounded-8
// Estructura:
//   close row  (p-10, justify-end, circle-X 24×24 border blanco)
//   content col (gap-9, items-start):
//     buttons row (w-258, gap-8): "Inicia sesión" 125×28 | "Regístrate" 125×28
//     links col  (p-10, gap-10, text-22, leading-48)

class _MobileMenuDropdown extends StatelessWidget {
  const _MobileMenuDropdown({
    required this.top,
    required this.right,
    required this.screenWidth,
    required this.navbarHeight,
    required this.onClose,
    this.onLoginTap,
    this.onRegisterTap,
    this.onInicioTap,
    this.onJuegosTap,
    this.onResultadosTap,
  });

  final double top;
  final double right;
  final double screenWidth;
  final double navbarHeight;
  final VoidCallback onClose;
  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onInicioTap;
  final VoidCallback? onJuegosTap;
  final VoidCallback? onResultadosTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap fuera para cerrar
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Panel dropdown
        Positioned(
          top: top,
          right: right,
          // Material resetea DefaultTextStyle del Overlay → sin subrayados
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  width: 287,
                  height: 290,
                  color: const Color(0x800F5886), // rgba(15,88,134,0.5)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Botón cerrar ──────────────────────────────────
                      // Figma: p-10, justify-end, delete-circle 24×24
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: onClose,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Contenido: gap-9, items-start ────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Botones row: w-258 (125+8+125), centrado
                          SizedBox(
                            width: 258,
                            height: 28,
                            child: Row(
                              children: [
                                _MenuAuthButton(
                                  label: 'Inicia sesión',
                                  bgColor: const Color(0xFFFAFAFA),
                                  textColor: const Color(0xFF1372AE),
                                  onTap: onLoginTap,
                                ),
                                const SizedBox(width: 8),
                                _MenuAuthButton(
                                  label: 'Regístrate',
                                  bgColor: const Color(0xFFFDC700),
                                  textColor: const Color(0xFF093048),
                                  onTap: onRegisterTap,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 9),

                          // Nav links: p-10, gap-10, text-22, leading-48
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MenuNavLink(
                                  label: 'Inicio',
                                  color: const Color(0xFFFFCB3C),
                                  onTap: onInicioTap,
                                ),
                                const SizedBox(height: 10),
                                _MenuNavLink(
                                  label: 'Juegos',
                                  color: Colors.white,
                                  onTap: onJuegosTap,
                                ),
                                const SizedBox(height: 10),
                                _MenuNavLink(
                                  label: 'Resultados',
                                  color: Colors.white,
                                  onTap: onResultadosTap,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Botón auth dentro del menú mobile
class _MenuAuthButton extends StatelessWidget {
  const _MenuAuthButton({
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.onTap,
  });

  final String label;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 125,
        height: 28,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// Link de nav dentro del menú mobile
class _MenuNavLink extends StatelessWidget {
  const _MenuNavLink({
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w400,
              color: color,
              height: 1.0,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botones sin logueo: "Inicia sesión" + "Regístrate" ───────────────────────
// Figma (sin logueo): gap-[16px] h-[65px] items-end justify-center w-[465px]

class _AuthButtons extends StatelessWidget {
  const _AuthButtons({this.onLoginTap, this.onRegisterTap});

  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 65,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              _NavWhiteButton(label: 'Inicia sesión', onTap: onLoginTap),
              const SizedBox(width: 16),
              _NavYellowButton(label: 'Regístrate', onTap: onRegisterTap),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Controles logueado ────────────────────────────────────────────────────────
// Figma (logueado, node 17:2024):
//   gap-[26px] h-[62px] items-end justify-end w-[459px]
//   Hijos: Saldo · Wallet button · Cart button · Avatar

class _UserControls extends StatelessWidget {
  const _UserControls({
    required this.saldo,
    this.onWalletTap,
    this.onCartTap,
    this.onAvatarTap,
    this.userAvatarUrl,
  });

  final String saldo;
  final VoidCallback? onWalletTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onAvatarTap;
  final String? userAvatarUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Saldo ──────────────────────────────────────────────────────
          _SaldoWidget(saldo: saldo),
          const SizedBox(width: 26),

          // ── Wallet button ──────────────────────────────────────────────
          _WalletButton(onTap: onWalletTap),
          const SizedBox(width: 26),

          // ── Carrito ────────────────────────────────────────────────────
          _CartButton(onTap: onCartTap),
          const SizedBox(width: 26),

          // ── Avatar ─────────────────────────────────────────────────────
          _AvatarCircle(
            size: 44,
            avatarUrl: userAvatarUrl,
            onTap: onAvatarTap,
          ),
        ],
      ),
    );
  }
}

// ── Widget Saldo ──────────────────────────────────────────────────────────────
// Figma node 17:1808 / 14:1551 — Segmented control
//   bg-[#fafafa] h-[41px] w-[83px] rounded-[8px]
//   Inner segment: h-[33px] gap-[4px] p-[8px] rounded-[8px]
//     Dollar icon 16×16 SVG + "$ 0" Nunito Bold 12px #111827

class _SaldoWidget extends StatelessWidget {
  const _SaldoWidget({required this.saldo});

  final String saldo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 83,
      height: 41,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Container(
        // Inner segment: h-33 rounded-8 con padding 8px
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dollar icon 16×16
            SvgPicture.asset(
              AppAssets.iconDollar,
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 4),
            // Texto saldo: Nunito Bold 12px · #111827
            Text(
              saldo,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón Wallet ──────────────────────────────────────────────────────────────
// Figma node 17:1779/17:1781:
//   bg-[#c7b322] (accent-500) · h-[41px] w-[41px] · rounded-[8px]
//   drop-shadow: 0px 3px 8px #fc0
//   inner highlight: inset 0px 4px 3px rgba(255,255,255,0.3)
//   Icono pi-wallet 25×25 blanco

class _WalletButton extends StatelessWidget {
  const _WalletButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 41,
        height: 41,
        decoration: BoxDecoration(
          color: const Color(0xFFC7B322), // accent-500
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFFFCC00), // #fc0 drop-shadow Figma
              offset: Offset(0, 3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Inner highlight: inset 0px 4px 3px rgba(255,255,255,0.3)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x4DFFFFFF), // rgba(255,255,255,0.3) arriba
                      Color(0x00FFFFFF), // transparente abajo
                    ],
                    stops: [0.0, 0.35],
                  ),
                ),
              ),
            ),
            // Icono wallet centrado: 25×25px
            Center(
              child: SvgPicture.asset(
                AppAssets.iconWallet,
                width: 25,
                height: 25,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón Carrito ─────────────────────────────────────────────────────────────
// Figma node 17:2304:
//   bg-white · h-[41px] w-[53px] · rounded-[8px] · overflow-clip
//   Shopping cart icon 24×24

class _CartButton extends StatelessWidget {
  const _CartButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 53,
        height: 41,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          AppAssets.iconCart,
          width: 24,
          height: 24,
        ),
      ),
    );
  }
}

// ── Avatar circular ───────────────────────────────────────────────────────────
// Figma node 17:2057:
//   h-[45px] w-[44px] · rounded-full (9999px) · overflow-clip

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.avatarUrl,
    required this.onTap,
  });

  final double size;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.hardEdge,
        child: avatarUrl != null
            ? Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Image.asset(
      AppAssets.avatarPlaceholder,
      fit: BoxFit.cover,
    );
  }
}

// ── Nav item ──────────────────────────────────────────────────────────────────
// Figma (I561:8147;14:942):
//   h-[69px] · p-[10px] · items-end · justify-center
//   Texto interior: h-[49px] justify-end → alineado al fondo del padding

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, this.isActive = false, this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 69,
        padding: const EdgeInsets.all(10),
        alignment: Alignment.bottomCenter,
        child: Text(
          label,
          style: AppTextStyles.navLink.copyWith(
            // Inicio → #feca0c (activo), demás → #fafafa
            color: isActive
                ? AppColors.navActiveYellow
                : const Color(0xFFFAFAFA),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Botón "Inicia sesión" ─────────────────────────────────────────────────────
// Figma: h-[41px] w-[184px] rounded-[14px] bg-[#fafafa]
// Texto: Inter SemiBold 14px · color: var(--secondary-500,#1372ae)

class _NavWhiteButton extends StatelessWidget {
  const _NavWhiteButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 41,
        width: 184,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.navButtonOutlined, // #1372ae sobre #fafafa
        ),
      ),
    );
  }
}

// ── Botón "Regístrate" ────────────────────────────────────────────────────────
// Figma: h-[41px] w-[184px] rounded-[14px] bg-[#fdc700]
// Texto: Inter SemiBold 14px · color: #093048

class _NavYellowButton extends StatelessWidget {
  const _NavYellowButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 41,
        width: 184,
        decoration: BoxDecoration(
          color: AppColors.navBtnYellow, // #fdc700
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.navButtonFilled, // #093048 sobre #fdc700
        ),
      ),
    );
  }
}

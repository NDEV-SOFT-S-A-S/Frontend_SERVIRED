abstract final class AppAssets {
  // ── Iconos generales ──────────────────────────────────────────────────────
  static const String starResultados = 'assets/images/star_resultados.svg';

  // ── Logo Gane (SVG) ───────────────────────────────────────────────────────
  static const String logoGane = 'assets/images/logo_gane.svg';

  // ── Banners (carousel principal) ──────────────────────────────────────────
  static const String bannerAstro   = 'assets/images/banner_1.png';
  static const String bannerBaloto  = 'assets/images/banner_2.png';
  static const String bannerBanner3 = 'assets/images/banner_3.png';
  static const String bannerBanner4 = 'assets/images/banner_4.png';

  static const List<String> banners = [
    bannerAstro,
    bannerBaloto,
    bannerBanner3,
    bannerBanner4,
  ];

  // ── Logos de loterías — acumulados ────────────────────────────────────────
  static const String logoDobleChance      = 'assets/images/logo_doble_chance.png';
  static const String logoBalotoRevancha   = 'assets/images/logo_baloto_revancha.png';
  static const String logoChanceMillonario = 'assets/images/logo_chance_millonario.png';
  static const String logoMiLoto           = 'assets/images/logo_mi_loto.png';
  static const String logoIColorLoto       = 'assets/images/logo_i_color_loto.png';

  // ── Íconos de secciones ───────────────────────────────────────────────────
  static const String iconResultados = 'assets/images/icon_resultados.svg';
  static const String iconAcumulados = 'assets/images/icon_acumulados.svg';
  static const String iconReloj      = 'assets/images/icon_reloj.svg';
  static const String iconJuego      = 'assets/images/Icon_juego.svg';

  // ── Logos de loterías — resultados ────────────────────────────────────────
  static const String logoRisaralda = 'assets/images/logo_risaralda.png';
  static const String logoValle     = 'assets/images/logo_valle.png';

  // ── Juegos (assets renombrados, orden de producto) ───────────────────────
  // Orden: Chance · PagaTodo · SuperWin · Dominguero · Quincenazo · DobleChance
  //        ChanceMillonario · PataMillonaria · LaQuinta · Baloto · Miloto · Colorloto
  static const String juegoChance          = 'assets/images/juego_chance.png';
  static const String juegoPagaTodo        = 'assets/images/juego_paga_todo.png';
  static const String juegoSuperwin        = 'assets/images/juego_superwin.png';
  static const String juegoDominguero      = 'assets/images/juego_dominguero.png';
  static const String juegoQuincenazo      = 'assets/images/juego_quincenazo.png';
  static const String juegoDobleChance     = 'assets/images/juego_doble_chance.png';
  static const String juegoChanceMillonario= 'assets/images/juego_chance_millonario.png';
  static const String juegoPataMillonaria  = 'assets/images/juego_pata_millonaria.png';
  static const String juegoQuinta         = 'assets/images/juego_quinta.png';
  static const String juegoBalotoRevancha = 'assets/images/juego_baloto_revancha.jpeg';
  static const String juegoMiloto         = 'assets/images/juego_miloto.png';
  static const String juegoColorloto      = 'assets/images/juego_colorloto.png';

  static const List<String> juegoImages = [
    juegoChance, juegoPagaTodo, juegoSuperwin, juegoDominguero,
    juegoQuincenazo, juegoDobleChance, juegoChanceMillonario, juegoPataMillonaria,
    juegoQuinta, juegoBalotoRevancha, juegoMiloto, juegoColorloto,
  ];

  // ── Juegos legacy (juego_N) — conservados para backward-compat ───────────
  static const String juegoImg1  = 'assets/images/juego_1.png';
  static const String juegoImg2  = 'assets/images/juego_2.png';
  static const String juegoImg3  = 'assets/images/juego_3.png';
  static const String juegoImg4  = 'assets/images/juego_4.jpeg';
  static const String juegoImg5  = 'assets/images/juego_5.png';
  static const String juegoImg6  = 'assets/images/juego_6.png';
  static const String juegoImg7  = 'assets/images/juego_7.png';
  static const String juegoImg8  = 'assets/images/juego_8.png';
  static const String juegoImg9  = 'assets/images/juego_9.png';
  static const String juegoImg10 = 'assets/images/juego_10.png';

  // ── Navbar logueado (Figma: Header propiedad1="logueado", node 561:10713) ──
  static const String iconDollar  = 'assets/images/Dollar.svg';                    // 16×16 saldo
  static const String iconWallet  = 'assets/images/pi-wallet.svg';                 // 25×25 pi-wallet
  static const String iconCart    = 'assets/images/_x30_1_Shopping_Cart.svg';      // 24×24 carrito
  static const String avatarPlaceholder = 'assets/images/avatar_placeholder.png';  // 44×45 avatar default

  // ── Íconos de contraseña (password toggle) ───────────────────────────────
  // Figma: size-[24px] · color neutral5 (#858C94) · dentro del input
  static const String eyeAlt   = 'assets/images/eye-alt.svg';   // ojo abierto  → contraseña visible
  static const String eyeClose = 'assets/images/eye-close.svg'; // ojo cerrado → contraseña oculta

  // ── Registro ─────────────────────────────────────────────────────────────
  static const String bannerRegistro = 'assets/images/banner_registro.png';

  // ── Footer — logos regulatorios ───────────────────────────────────────────
  // Variantes blancas exportadas desde Figma (asset real del diseño)
  static const String logoVigilado  = 'assets/images/logo_vigilado_supersalud_white.png';
  static const String logoColjuegos = 'assets/images/coljuegos_logo_white.png';

  // ── Superwin ──────────────────────────────────────────────────────────────
  static const String bannerSuperwin = 'assets/images/banner_juegos_superwin.png';
  static const String imagenSuperwin = 'assets/images/imagen_1_superwin.png';

  // ── Paga Todo (HU-PAG001) ─────────────────────────────────────────────────
  static const String bannerPagaTodo = 'assets/images/banner_paga_todo.png';

  // ── Chance Millonario (HU-CM001) ─────────────────────────────────────────
  // Mismo archivo que juegoImg9 — "Chance Millonario Sorprendente"
  static const String bannerChanceMillonario = 'assets/images/juego_9.png';

  // ── Pata Millonaria ───────────────────────────────────────────────────────
  static const String bannerPataMillonaria = 'assets/images/banner-paramillonaria.png';

  // ── Dominguero ────────────────────────────────────────────────────────────
  static const String bannerDominguero  = 'assets/images/banner_dominguero.png';
  static const String refreshCircular   = 'assets/images/refresh-circular.svg';

  // ── Resultados banner ─────────────────────────────────────────────────────
  static const String frameResultados = 'assets/images/frame_resultados.png';
  static const String iconCopa        = 'assets/images/Icon_copa.svg';
  static const String iconCalendario  = 'assets/images/calendar.svg';

  // ── Baloto / Revancha ─────────────────────────────────────────────────────
  static const String bannerBalotoRevancha = 'assets/images/Banner-Baloto-Rebancha.png';
  static const String baloteraTube         = 'assets/images/balotera_tube.png';

  // ── Chance Tradicional (HU-PD-003) ───────────────────────────────────────
  // Figma node 762:3908 — banner ChanCe (746×150)
  static const String frameChanceTradicional = 'assets/images/frame_chance_tradicional.png';

  // Logos de loterías del Chance — Figma "Loterias Juego" (87×87 cada una)
  static const String logoLoteriaMeta          = 'assets/images/logo_loteria_meta.png';
  static const String logoLoteriaQuindio       = 'assets/images/logo_loteria_quindio.png';
  static const String logoLoteriaCauca         = 'assets/images/logo_loteria_cauca.png';
  static const String logoLoteriaMedellin      = 'assets/images/logo_loteria_medellin.png';
  static const String logoLoteriaExtraMedellin = 'assets/images/logo_loteria_extra_medellin.png';
  static const String logoLoteriaManizales     = 'assets/images/logo_loteria_manizales.png';
  static const String logoLoteriaCundinamarca  = 'assets/images/logo_loteria_cundinamarca.png';
  static const String logoLoteriaBoyaca        = 'assets/images/logo_loteria_boyaca.png';
  static const String logoLoteriaBogota        = 'assets/images/logo_loteria_bogota.png';
  static const String logoLoteriaTolima        = 'assets/images/logo_loteria_tolima.png';
  static const String logoLoteriaHuila         = 'assets/images/logo_loteria_huila.png';
  static const String logoLoteriaSantander     = 'assets/images/logo_loteria_santander.png';
}

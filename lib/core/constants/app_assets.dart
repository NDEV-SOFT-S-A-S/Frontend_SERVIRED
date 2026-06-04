abstract final class AppAssets {
  // ── Logo Gane (SVG) ───────────────────────────────────────────────────────
  static const String logoGane = 'assets/images/logo_gane.svg';

  // ── Banners (carousel principal) ──────────────────────────────────────────
  static const String bannerAstro   = 'assets/images/banner_1.png';
  static const String bannerBaloto  = 'assets/images/banner_2.png';
  static const String bannerBanner3 = 'assets/images/banner_3.png';
  static const String bannerBanner4 = 'assets/images/banner_1.png'; // reusar

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

  // ── Logos de loterías — resultados ────────────────────────────────────────
  static const String logoRisaralda = 'assets/images/logo_risaralda.png';
  static const String logoValle     = 'assets/images/logo_valle.png';

  // ── Juegos ────────────────────────────────────────────────────────────────
  // Verificado contra Figma (nodos 561:8133 y 561:8139) por hash SHA-1.
  // juego_4 es JPEG (distinto hash al PNG de Figma, mismo contenido visual).
  // Fila 1: La Pata Millonaria · El Domingueño Millonario · Paga Todo · Baloto Revancha · Doble Chance
  // Fila 2: La Quinta · Chance · Quincenazo · Chance Millonario Sorprendente · Chance Superwin
  static const String juegoImg1  = 'assets/images/juego_1.png';   // La Pata Millonaria
  static const String juegoImg2  = 'assets/images/juego_2.png';   // El Domingueño Millonario
  static const String juegoImg3  = 'assets/images/juego_3.png';   // Paga Todo
  static const String juegoImg4  = 'assets/images/juego_4.jpeg';  // Baloto Revancha
  static const String juegoImg5  = 'assets/images/juego_5.png';   // Doble Chance
  static const String juegoImg6  = 'assets/images/juego_6.png';   // La Quinta
  static const String juegoImg7  = 'assets/images/juego_7.png';   // Chance
  static const String juegoImg8  = 'assets/images/juego_8.png';   // Quincenazo
  static const String juegoImg9  = 'assets/images/juego_9.png';   // Chance Millonario Sorprendente
  static const String juegoImg10 = 'assets/images/juego_10.png';  // Chance Superwin

  static const List<String> juegoImages = [
    juegoImg1, juegoImg2, juegoImg3, juegoImg4,  juegoImg5,
    juegoImg6, juegoImg7, juegoImg8, juegoImg9,  juegoImg10,
  ];

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

  // ── Chance Millonario (HU-CM001) ─────────────────────────────────────────
  // Mismo archivo que juegoImg9 — "Chance Millonario Sorprendente"
  static const String bannerChanceMillonario = 'assets/images/juego_9.png';

  // ── Dominguero ────────────────────────────────────────────────────────────
  static const String bannerDominguero  = 'assets/images/banner_dominguero.png';
  static const String refreshCircular   = 'assets/images/refresh-circular.svg';

  // ── Pata Millonaria (HU-PM001) ───────────────────────────────────────────
  /// Banner horizontal de La Pata Millonaria (pata con sombrero rosa + monedas)
  static const String bannerPataMillonaria =
      'assets/images/b5a8d0e4f0b8de6fd40dc505745f1360db373c8b.png';
  static const double bannerPataMillonariaAspectRatio = 1492 / 300;

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

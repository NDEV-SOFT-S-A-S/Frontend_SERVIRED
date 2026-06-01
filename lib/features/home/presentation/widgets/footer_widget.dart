import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Figma node 561:8146 — Footer (instancia) 1668×768px ──────────────────────
//
// Estructura absoluta en canvas de 1729px:
//   Col 1 GENERAL         left:120  width:167  top:79
//   Sep 1                 left:401  h:574      top:41
//   Col 2 Empresa         left:497  width:268  top:79
//   Sep 2                 left:840  h:574      top:41
//   Col 3 FUNDACIÓN       left:952  width:266  top:79
//   Sep 3                 left:1303 h:574      top:41
//   Col 4 ÉTICA+SÍGUENOS  left:1393 top:79
//
// Tipografía:
//   Titles (cols 1,3,4): Inter Bold   16px  LH:24px
//   Links  (cols 1,3,4): Inter Regular 16px  LH:24px
//   Col 2 completa:      Inter Regular 16px  LH:41px  (título NO es bold)
//   Spacers entre secciones: párrafo vacío de 28px (text-[22px] leading-[28px])
//
// Col 4 logos (top desde footer):
//   GANE logo     left:1402  top:376  138×57px
//   Vigilado      left:1402  top:442  224×68px  (gap desde GANE: 9px)
//   Coljuegos     left:1402  top:519  224×73px  (gap desde Vigilado: 9px)
//
// Copyright: bg #2C2E6F, h:84px, top:683, Inter Bold 22/28 blanco, centrado
// Border-top: rgba(255,255,255,0.2)  shadow: 0 4 4 rgba(0,0,0,0.25)

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Figma: el footer rende sobre bg-[#1372ae] del frame padre.
        // Declaramos el color explícito para evitar que fondos del tema
        // (surface: white) aparezcan a través del widget transparente.
        color: AppColors.homeBackground,
        border: Border(
          top: BorderSide(
            color: Color(0x33FFFFFF), // rgba(255,255,255,0.2)
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Cuerpo del footer: 4 columnas ─────────────────────────────────
          // paddingTop 79: columnas empiezan en top:79 dentro del footer (Figma)
          // paddingBottom 68: gap entre fondo separador (615px) y fin de contenido (683px)
          Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 10,
              top: 79,
              bottom: 68,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 900) {
                  return const _FooterColumns();
                }
                return const _FooterColumnsMobile();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Columnas de footer — layout desktop ──────────────────────────────────────
// IntrinsicHeight hace que los separadores verticales se estiren al alto de la
// columna más alta (reemplaza el h:574 absoluto de Figma).

class _FooterColumns extends StatelessWidget {
  const _FooterColumns();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Col1General()),
          const _VerticalDivider(),
          Expanded(child: _Col2Empresa()),
          const _VerticalDivider(),
          Expanded(child: _Col3Fundacion()),
          const _VerticalDivider(),
          Expanded(child: _Col4EticaLogos()),
        ],
      ),
    );
  }
}

// ── Separador vertical — 1px rgba(255,255,255,0.2) ────────────────────────────
// Figma: w:0 con inset [0_-0.5px] → efectivamente 1px blanco semitransparente

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0x33FFFFFF),
    );
  }
}

// ── Columna 1: GENERAL ────────────────────────────────────────────────────────
// Figma node I561:8146;179:726
// Título: Bold 16/24  |  Links: Regular 16/24
// Párrafos dobles BR crean spacers de 24px (= un leading vacío)

class _Col1General extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _FooterColCompact(
      title: 'GENERAL',
      items: const [
        _FooterItem.spacer(),
        _FooterItem.link(' Dirección principal'),
        _FooterItem.spacer(),
        _FooterItem.link('Calle 13 No.4-25'),
        _FooterItem.link('Edificio Carvajal'),
        _FooterItem.spacer(),
        _FooterItem.link(' Teléfonos (PBX):'),
        _FooterItem.spacer(),
        _FooterItem.link('(602) 884 3434'),
        _FooterItem.spacer(),
        _FooterItem.link(' Correos:'),
        _FooterItem.spacer(),
        _FooterItem.link('info@gane.com.co'),
        _FooterItem.link('pqrs@gane.com.co'),
        _FooterItem.spacer(),
        _FooterItem.link('Cali, Valle del Cauca.'),
        _FooterItem.link('CONTÁCTANOS'),
      ],
    );
  }
}

// ── Columna 2: Empresa ────────────────────────────────────────────────────────
// Figma node I561:8146;185:812
// TODO el bloque: Regular 16px, lineHeight 41px (incluye el título "Empresa")
// El título NO es bold — Figma usa font-normal para todos los ítems de esta col.

class _Col2Empresa extends StatelessWidget {
  const _Col2Empresa();

  static const _links = [
    'Ingresa a Gane Corporativo',
    'Video Institucional',
    'Campañas',
    'Preguntas frecuentes',
    'Pago premios',
    'Puntos de servicios',
    'Aviso de privacidad',
    'Periódico Gane al día',
    'Comunicados de presa',
    'Sistemas de gestión de calidad',
    'Estados financieros',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Empresa', style: AppTextStyles.footerEmpresaLink),
          for (final link in _links)
            Text(link, style: AppTextStyles.footerEmpresaLink),
        ],
      ),
    );
  }
}

// ── Columna 3: FUNDACIÓN SOCIAL ───────────────────────────────────────────────
// Figma node I561:8146;181:794
// Spacers entre secciones: 28px (= leading-[28px] text-[22px] vacío)

class _Col3Fundacion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FUNDACIÓN SOCIAL', style: AppTextStyles.footerColTitle),
          const SizedBox(height: 28), // spacer post-título Figma
          ...const [
            '¿Quiénes somos?',
            'Ayudas sociales',
            'Políticas',
            'Educación contínua',
            'Salud',
            'Vivienda',
            'Recreación y deporte',
            'Infancia y adolescencia',
            'Cuidarte',
            'Escuela de iniciación deportiva',
          ].map((l) => Text(l, style: AppTextStyles.footerColLink)),
          const SizedBox(height: 28), // spacer entre secciones
          Text('Informe fundación social gane',
              style: AppTextStyles.footerColTitle),
          const SizedBox(height: 28), // spacer post sub-título
          ...const [
            'Estados Financieros',
            'Informe Anual Datos Generales',
            'Informe del Revisor Fiscal',
          ].map((l) => Text(l, style: AppTextStyles.footerColLink)),
        ],
      ),
    );
  }
}

// ── Columna 4: ÉTICA + SÍGUENOS + logos ──────────────────────────────────────
// Figma node I561:8146;185:814 (ética, top:79) + nodos separados:
//   SÍGUENOS (top:298), iconos (top:320), GANE logo (top:376)
//   Vigilado (top:442), Coljuegos (top:519)
//
// Gaps verticales medidos en Figma:
//   Ética links → SÍGUENOS:  spacer 28px
//   SÍGUENOS → íconos:       8px  (top:320 - (298+13translateY) ≈ 8px)
//   Íconos → GANE logo:      32px (top:376 - (320+24) = 32px)
//   GANE → Vigilado:         9px  (top:442 - (376+57) = 9px)
//   Vigilado → Coljuegos:    9px  (top:519 - (442+68) = 9px)

class _Col4EticaLogos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ÉTICA Y BUEN GOBIERNO', style: AppTextStyles.footerColTitle),
          const SizedBox(height: 28), // spacer post-título Figma
          ...const [
            'Cultura Anticorrupción',
            'Cultura Antilavado',
            'Cultura de Protección de Datos',
            'Línea Ética',
            'Código de Buen Gobierno',
          ].map((l) => Text(l, style: AppTextStyles.footerColLink)),
          const SizedBox(height: 28), // spacer antes de SÍGUENOS

          // ── SÍGUENOS ───────────────────────────────────────────────────
          Text('SÍGUENOS', style: AppTextStyles.footerColTitle),
          const SizedBox(height: 8),
          const _SocialRow(),
          const SizedBox(height: 32), // gap íconos → GANE logo

          // ── Logos regulatorios ─────────────────────────────────────────
          // GANE logo — SVG 138×57px (Figma top:376)
          SvgPicture.asset(
            AppAssets.logoGane,
            width: 138,
            height: 57,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 9), // gap GANE → Vigilado

          // Vigilado Supersalud — 224×68px (Figma top:442)
          _FooterLogo(url: AppAssets.logoVigilado, width: 224, height: 68),
          const SizedBox(height: 9), // gap Vigilado → Coljuegos

          // Coljuegos — 224×73px (Figma top:519)
          _FooterLogo(url: AppAssets.logoColjuegos, width: 224, height: 73),
        ],
      ),
    );
  }
}

// ── Redes sociales — 5 íconos 24×24px, gap 9px ───────────────────────────────
// Figma: facebook(1393) linkedin(1426) instagram(1459) youtube(1492) tiktok(1525)
// Gap entre íconos: 33px / pero en la fila con Spacer equivale a 9px entre bordes

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _SocialIcon(icon: Icons.facebook_rounded),
        SizedBox(width: 9),
        _SocialIcon(icon: Icons.linked_camera),
        SizedBox(width: 9),
        _SocialIcon(icon: Icons.camera_alt_outlined),
        SizedBox(width: 9),
        _SocialIcon(icon: Icons.play_circle_outline_rounded),
        SizedBox(width: 9),
        _SocialIcon(icon: Icons.music_note_outlined),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Icon(icon, color: AppColors.neutralWhite, size: 20),
    );
  }
}

// ── Logo regulatorio con fallback ─────────────────────────────────────────────

class _FooterLogo extends StatelessWidget {
  const _FooterLogo({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        url,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

// ── Columna genérica compacta (cols 1, 3, 4) ─────────────────────────────────
// Acepta una lista tipada de _FooterItem para distinguir links y spacers.

class _FooterColCompact extends StatelessWidget {
  const _FooterColCompact({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_FooterItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.footerColTitle),
        for (final item in items)
          if (item.isLink)
            Text(item.text, style: AppTextStyles.footerColLink)
          else
            const SizedBox(height: 24),
      ],
    );
  }
}

class _FooterItem {
  const _FooterItem.link(this.text) : isLink = true;
  const _FooterItem.spacer()
      : isLink = false,
        text = '';

  final bool isLink;
  final String text;
}

// ── Layout mobile (columna única) ─────────────────────────────────────────────

class _FooterColumnsMobile extends StatelessWidget {
  const _FooterColumnsMobile();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Col1General(),
        const SizedBox(height: 24),
        const _Col2Empresa(),
        const SizedBox(height: 24),
        _Col3Fundacion(),
        const SizedBox(height: 24),
        _Col4EticaLogos(),
      ],
    );
  }
}

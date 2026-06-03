import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Estilos tipográficos extraídos de Figma (nodo 150:3634)
/// Familias: Poppins · Inter · Source Sans Pro · Nunito
class AppTextStyles {
  AppTextStyles._();

  // ── Inter ──────────────────────────────────────────────────────────────────

  /// Regular Body L — Inter Regular 16/24
  static TextStyle get bodyL => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.textPrimary,
      );

  /// Bold Body L — Inter Bold 16/24
  static TextStyle get bodyLBold => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 24 / 16,
        color: AppColors.textPrimary,
      );

  /// Light Body M — Inter Light 12/18
  static TextStyle get bodyMLight => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        height: 18 / 12,
        color: AppColors.textSecondary,
      );

  /// H3 Light — Inter Light 22/28
  static TextStyle get h3Light => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 28 / 22,
        color: AppColors.textPrimary,
      );

  /// H3 Bold — Inter Bold 22/28
  static TextStyle get h3Bold => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
        color: AppColors.textPrimary,
      );

  // ── Poppins ────────────────────────────────────────────────────────────────

  /// Semibold Body L — Poppins SemiBold 14/24 (labels de formulario)
  static TextStyle get labelSemibold => GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 24 / 14,
        color: AppColors.textPrimary,
      );

  /// Bold Body M — Poppins Bold 12 (tags, badges)
  static TextStyle get bodyMBold => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // ── Source Sans Pro ────────────────────────────────────────────────────────

  /// Paragraph Small / Heavy — Source Sans Pro SemiBold 13/20 (error messages)
  static TextStyle get errorText => GoogleFonts.sourceSans3(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 20 / 13,
        color: AppColors.error,
      );

  // ── Nunito ─────────────────────────────────────────────────────────────────

  /// Button — Nunito Bold 14 (texto del botón primario)
  static TextStyle get button => GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
        letterSpacing: 0.2,
      );

  // ── Derivados UI ───────────────────────────────────────────────────────────

  static TextStyle get inputHint => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.neutral5,
      );

  static TextStyle get inputText => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get formLabel => GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get linkSecondary => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get linkGold => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.accent500,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.accent500,
      );

  // ── Navbar ─────────────────────────────────────────────────────────────────

  /// "G" del logo — Inter ExtraBold 26px dorado
  static TextStyle get logoGBold => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: AppColors.accent500,
        height: 1.0,
      );

  /// "ane" del logo — Inter Regular 22px dorado
  static TextStyle get logoAneRegular => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w400,
        color: AppColors.accent500,
        height: 1.0,
      );

  /// Link de navegación — Inter Medium 34px (Figma node I561:8147;14:939)
  /// leading-[28px] → height:1.0 en Flutter (0.824 causa clipping)
  static TextStyle get navLink => GoogleFonts.inter(
        fontSize: 34,
        fontWeight: FontWeight.w500,
        height: 1.0,
        color: AppColors.navActiveYellow,
      );

  /// Botón "Inicia sesión" — Inter SemiBold 14px · texto #1372ae sobre bg #fafafa
  /// Figma node I561:8147;17:2083;31:28914: text-[color:var(--secondary-500,#1372ae)]
  static TextStyle get navButtonOutlined => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.secondary500, // #1372ae — azul sobre blanco
      );

  /// Botón "Regístrate" — Inter SemiBold 14px · texto #093048 sobre bg #fdc700
  /// Figma node I561:8147;17:1765;31:28938: text-[#093048]
  static TextStyle get navButtonFilled => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.navBtnDark, // #093048 — oscuro sobre amarillo
      );

  // ── Landing page ───────────────────────────────────────────────────────────

  /// Título de sección — Inter Bold 32px (Acumulados, Resultados, Juegos)
  static TextStyle get sectionTitle => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: AppColors.neutralWhite,
      );

  /// Monto acumulado — Inter ExtraBold 48/48
  static TextStyle get acumuladoAmount => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: AppColors.neutralWhite,
      );

  /// "Millones" subtítulo — Inter Medium 25/27
  static TextStyle get acumuladoMillones => GoogleFonts.inter(
        fontSize: 25,
        fontWeight: FontWeight.w500,
        height: 27 / 25,
        color: AppColors.neutralWhite,
      );

  /// Subtítulo linea (ej. "3 cifras") — Inter Regular 16/24
  static TextStyle get acumuladoSubtitle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.neutralWhite,
      );

  /// Número del timer — Inter Bold 24/32, azul secundario
  static TextStyle get timerNumber => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        color: AppColors.secondary500,
      );

  /// Etiqueta del timer (Horas/Mins/Secs) — Inter Regular 12/16, azul secundario
  static TextStyle get timerLabel => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.secondary500,
      );

  /// "Próximo sorteo" — Inter Regular 14/20, blanco
  static TextStyle get timerProximo => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.neutralWhite,
      );

  /// Nombre lotería en resultado — Inter SemiBold 16/24, blanco
  static TextStyle get resultadoNombre => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 24 / 16,
        color: AppColors.neutralWhite,
      );

  /// Fecha del resultado — Inter Regular 14/24, blanco
  static TextStyle get resultadoFecha => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 24 / 14,
        color: AppColors.neutralWhite,
      );

  /// Número en chip de resultado — Inter SemiBold 33, primary700
  static TextStyle get resultadoNumero => GoogleFonts.inter(
        fontSize: 33,
        fontWeight: FontWeight.w600,
        color: AppColors.primary700,
      );

  /// Etiqueta de tarjeta de juego — Poppins Bold 12, blanco
  static TextStyle get juegoCardLabel => GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.neutralWhite,
      );

  /// Texto del botón "Ver más" — Inter Medium 16, blanco
  static TextStyle get verMasText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.neutralWhite,
      );

  /// Título de columna del footer — Inter Bold 16/24, blanco
  static TextStyle get footerColTitle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 24 / 16,
        color: AppColors.neutralWhite,
      );

  /// Link de columna del footer (cols 1, 3, 4) — Inter Regular 16/24, blanco
  /// Figma: leading-[24px] en nodos I561:8146;179:726, 181:794, 185:814
  static TextStyle get footerColLink => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AppColors.neutralWhite,
      );

  /// Link columna Empresa (col 2) — Inter Regular 16/41, blanco
  /// Figma: nodo I561:8146;185:812 usa leading-[41px] en todos sus ítems
  static TextStyle get footerEmpresaLink => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 41 / 16,
        color: AppColors.neutralWhite,
      );

  /// Texto del copyright — Inter Bold 22/28, blanco
  static TextStyle get footerCopyright => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 28 / 22,
        color: AppColors.neutralWhite,
      );
}

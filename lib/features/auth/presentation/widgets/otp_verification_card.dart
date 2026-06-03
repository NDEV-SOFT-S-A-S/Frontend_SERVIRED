import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';

// ── Figma: plataforma-Gane-Web · node 60:5832 "codigo otp" ───────────────────
//
// Variante SMS   : isPhone = true
// Variante correo: isPhone = false
//
// Specs Figma:
//   Container  : solid #1372AE · rounded-38 · max-w-660 · drop-shadow Sombra200
//   Título     : Inter SemiBold 32px · lh-38 · blanco · centrado
//   Descripción: Inter Regular 20px · lh-24 · blanco · centrado · max-w-489px
//   Destination: Poppins Medium 15px blanco + valor resaltado #fc0 (amarillo)
//   Círculos   : 81×79px · shape círculo · gap-24px
//                  vacío  → bg transparente · borde 1px blanco
//                  lleno  → bg #cfcfd1 · borde 1px blanco · dígito Inter Bold 36px blanco
//   Botón      : 371×57px · rounded-26px
//                  desactivado → bg #cfcfd1 · texto blanco Inter SemiBold 20px
//                  activado    → bg #3C9BD6 · texto blanco Inter SemiBold 20px
//   Timer      : Poppins Regular 15px blanco + "MM:SS" en amarillo #fc0
//   Links      : Poppins Medium 14px · blanco + enlace amarillo subrayado
// ─────────────────────────────────────────────────────────────────────────────

class OtpVerificationCard extends StatefulWidget {
  const OtpVerificationCard({
    super.key,
    required this.destination,
    required this.isPhone,
    required this.onClose,
    required this.onConfirmed,
    required this.onCorrect,
    required this.onSwitchMethod,
  });

  /// Correo o número de teléfono que se muestra resaltado.
  final String destination;

  /// true = variante SMS, false = variante correo.
  final bool isPhone;

  final VoidCallback onClose;

  /// Se llama cuando el código es confirmado con éxito.
  final VoidCallback onConfirmed;

  /// "Corregir" — vuelve al paso donde se ingresó el destino.
  final VoidCallback onCorrect;

  /// "Enviar mejor a mi…" — alterna entre email y teléfono.
  final VoidCallback onSwitchMethod;

  @override
  State<OtpVerificationCard> createState() => _OtpVerificationCardState();
}

class _OtpVerificationCardState extends State<OtpVerificationCard> {
  static const int _totalSeconds = 30;
  static const int _digitCount = 4;

  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late Timer _timer;

  int _secondsLeft = _totalSeconds;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_digitCount, (_) => TextEditingController());
    _focusNodes = List.generate(_digitCount, (_) => FocusNode());

    // Backspace en campo vacío → mover foco al anterior
    for (int i = 0; i < _digitCount; i++) {
      final idx = i;
      _focusNodes[i].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[idx].text.isEmpty &&
            idx > 0) {
          _focusNodes[idx - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }

    _startTimer();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _secondsLeft = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
        else _timer.cancel();
      });
    });
  }

  void _resend() {
    _timer.cancel();
    for (final c in _controllers) c.clear();
    setState(() => _isVerifying = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.first.requestFocus();
    });
    _startTimer();
    // TODO: llamar API de reenvío cuando esté disponible
  }

  // ── Código ─────────────────────────────────────────────────────────────────

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isComplete => _code.length == _digitCount;

  void _onDigitChanged(int index, String value) {
    // Paste: distribuir dígitos en los campos restantes
    if (value.length > 1) {
      final digits = value
          .replaceAll(RegExp(r'[^0-9]'), '')
          .substring(0, min(value.length, _digitCount - index));
      for (int i = 0; i < digits.length; i++) {
        final fi = index + i;
        if (fi < _digitCount) _controllers[fi].text = digits[i];
      }
      final next = min(index + digits.length, _digitCount - 1);
      _focusNodes[next].requestFocus();
    } else if (value.length == 1) {
      // Avanzar al siguiente
      if (index < _digitCount - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    setState(() {});
  }

  // ── Confirmar ──────────────────────────────────────────────────────────────

  Future<void> _onConfirm() async {
    if (!_isComplete || _isVerifying) return;
    setState(() => _isVerifying = true);
    // Mock: acepta cualquier código de 4 dígitos mientras no haya backend.
    // TODO: reemplazar con verifyOtp del AuthCubit cuando backend esté listo.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isVerifying = false);
    widget.onConfirmed();
  }

  @override
  void dispose() {
    _timer.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 660,
      constraints: const BoxConstraints(maxWidth: 660),
      decoration: BoxDecoration(
        color: AppColors.secondary500, // #1372AE
        borderRadius: BorderRadius.circular(38),
        boxShadow: AppColors.sombra200,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Botón cerrar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10, right: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.onClose,
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // ── Contenido central ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Título
                Text(
                  'Código de verificación',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 38 / 32,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Descripción
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 489),
                  child: Text(
                    widget.isPhone
                        ? 'Te hemos enviado un código de cuatro dígitos por mensaje de texto a tu número de teléfono.'
                        : 'Te hemos enviado un código de cuatro dígitos a tu correo.',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                      height: 24 / 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                // Destino resaltado
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: widget.isPhone
                            ? 'Enviamos el código al número '
                            : 'Enviamos el código al correo ',
                      ),
                      TextSpan(
                        text: widget.destination,
                        style: const TextStyle(color: Color(0xFFFFCC00)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Círculos de dígitos ──────────────────────────────────
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_digitCount, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < _digitCount - 1 ? 24.0 : 0.0,
                      ),
                      child: _DigitCircle(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        onChanged: (v) => _onDigitChanged(i, v),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // ── Botón Confirmar ─────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 371,
                  height: 57,
                  decoration: BoxDecoration(
                    color: _isComplete && !_isVerifying
                        ? AppColors.secondary300 // #3C9BD6 activado
                        : const Color(0xFFCFCFD1), // gris desactivado
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isComplete && !_isVerifying ? _onConfirm : null,
                      borderRadius: BorderRadius.circular(26),
                      child: Center(
                        child: _isVerifying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Confirmar código',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Temporizador / reenviar ──────────────────────────────
                if (_secondsLeft > 0)
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: '¿no llegó el código? Reenviar en '),
                        TextSpan(
                          text: _timerText,
                          style: const TextStyle(color: Color(0xFFFFCC00)),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _resend,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                        children: const [
                          TextSpan(text: '¿no llegó el código? '),
                          TextSpan(
                            text: 'Reenviar',
                            style: TextStyle(
                              color: Color(0xFFFFCC00),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFFFFCC00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // ── "¿No es tu…? Corregir" ───────────────────────────────
                GestureDetector(
                  onTap: widget.onCorrect,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(
                          text: widget.isPhone
                              ? '¿No es tu número? '
                              : '¿No es tu correo? ',
                        ),
                        const TextSpan(
                          text: 'Corregir',
                          style: TextStyle(
                            color: Color(0xFFFFCC00),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFCC00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── "Enviar mejor a mi…" ─────────────────────────────────
                GestureDetector(
                  onTap: widget.onSwitchMethod,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      children: [
                        const TextSpan(text: 'Enviar mejor a mi '),
                        TextSpan(
                          text: widget.isPhone
                              ? 'Correo electrónico'
                              : 'Número de teléfono',
                          style: const TextStyle(
                            color: Color(0xFFFFCC00),
                            decoration: TextDecoration.underline,
                            decorationColor: Color(0xFFFFCC00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Círculo de un dígito ──────────────────────────────────────────────────────
// Figma: 81×79px · shape=circle · border 1px blanco
//   vacío  → bg transparente
//   lleno  → bg #cfcfd1 · dígito Inter Bold 36px blanco

class _DigitCircle extends StatelessWidget {
  const _DigitCircle({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool filled = controller.text.isNotEmpty;
    return Container(
      width: 81,
      height: 79,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFCFCFD1) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: SizedBox(
          width: 50,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            maxLength: 1,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );
  }
}

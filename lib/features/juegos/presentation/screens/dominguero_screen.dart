import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';
import '../../domain/entities/dominguero_entities.dart';
import '../cubit/dominguero_cubit.dart';
import '../cubit/dominguero_state.dart';
import '../helpers/dominguero_sugerencias_helper.dart';

// ── Modelo local ─────────────────────────────────────────────────────────────

class _BetLine {
  const _BetLine({required this.modalidad, required this.numero});
  final ModalidadDominguero modalidad;
  final String numero;
  static const int betValue = 2000; // HU: valor fijo $2.000
  static const int ivaValue = 120;  // Figma: IVA por línea de $2.000
}

// ── Screen wrapper — provee DomingueroCubit ──────────────────────────────────

class DomingueroScreen extends StatelessWidget {
  const DomingueroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DomingueroCubit>(),
      child: const _DomingueroView(),
    );
  }
}

// ── Vista principal ───────────────────────────────────────────────────────────

class _DomingueroView extends StatefulWidget {
  const _DomingueroView();

  @override
  State<_DomingueroView> createState() => _DomingueroViewState();
}

class _DomingueroViewState extends State<_DomingueroView> {
  late final List<DateTime> _sundays;
  int _selectedSunday = 0;
  ModalidadDominguero _modalidad = ModalidadDominguero.tresC;
  final _numeroCtrl = TextEditingController();
  final List<_BetLine> _lines = [];
  String? _fieldError;
  bool _resumenOpen = false;

  @override
  void initState() {
    super.initState();
    _sundays = _calcSundays();
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  static List<DateTime> _calcSundays() {
    final results = <DateTime>[];
    var d = DateTime.now();
    if (d.weekday == DateTime.sunday) d = d.add(const Duration(days: 1));
    while (results.length < 5) {
      if (d.weekday == DateTime.sunday) results.add(d);
      d = d.add(const Duration(days: 1));
    }
    return results;
  }

  bool get _isSundayClosed => DateTime.now().weekday == DateTime.sunday;

  static String _fmtSunday(DateTime d) {
    const ms = ['', 'ene', 'feb', 'mar', 'abr', 'mayo', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${d.day} ${ms[d.month]}';
  }

  int _usosEnLineas(String numero, ModalidadDominguero modalidad) =>
      _lines.where((l) => l.numero == numero && l.modalidad == modalidad).length;

  /// Devuelve true si el texto actual del input es una apuesta válida:
  /// - longitud correcta para la modalidad
  /// - no está bloqueado por inline-check (número agotado o ≥ 2 usos)
  /// - sin error de campo activo
  bool _isCurrentInputValid(String? numeroBloqueado) {
    final text = _numeroCtrl.text;
    return text.length == _modalidad.digits &&
        (numeroBloqueado == null || numeroBloqueado != text) &&
        _fieldError == null;
  }

  void _autoNumero() {
    final max = _modalidad.digits == 3 ? 999 : 9999;
    final num =
        math.Random().nextInt(max + 1).toString().padLeft(_modalidad.digits, '0');
    _numeroCtrl.text = num;
    setState(() => _fieldError = null);
    context.read<DomingueroCubit>().checkInline(
          num,
          _modalidad,
          usosLocales: _usosEnLineas(num, _modalidad),
        );
  }

  void _handleNumeroChanged(String value) {
    setState(() => _fieldError = null);
    if (value.length == _modalidad.digits) {
      context.read<DomingueroCubit>().checkInline(
            value,
            _modalidad,
            usosLocales: _usosEnLineas(value, _modalidad),
          );
    } else {
      context.read<DomingueroCubit>().clearInline();
    }
  }

  bool _validate() {
    final n = _numeroCtrl.text.trim();
    final d = _modalidad.digits;
    if (n.isEmpty || n.length != d) {
      setState(() => _fieldError = 'El número debe tener exactamente $d cifras');
      return false;
    }
    if (context.read<DomingueroCubit>().state.numeroBloqueadoInline == n) {
      // Número agotado (E3) — el error inline ya se muestra en el input.
      return false;
    }
    setState(() => _fieldError = null);
    return true;
  }

  void _addLine() {
    if (!_validate()) return;
    setState(() {
      _lines.add(_BetLine(modalidad: _modalidad, numero: _numeroCtrl.text.trim()));
      _numeroCtrl.clear();
    });
    context.read<DomingueroCubit>().clearInline();
  }

  void _removeLine(int i) => setState(() => _lines.removeAt(i));

  static String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  // ── Gestión de estados del Cubit ──────────────────────────────────────────

  void _handleStateChange(BuildContext context, DomingueroState state) {
    switch (state.status) {
      case DomingueroStatus.resumenListo:
        if (!_resumenOpen && _sundays.isNotEmpty) {
          _resumenOpen = true;
          _showResumenDialog(
            context,
            state.lineasVerificadas,
            _sundays[_selectedSunday],
            context.read<DomingueroCubit>(),
          ).then((_) {
            if (mounted) setState(() => _resumenOpen = false);
          });
        }
      case DomingueroStatus.exito:
        if (_resumenOpen) {
          _resumenOpen = false;
          Navigator.of(context).pop();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showComprobanteDialog(context, state.resultados, onClose: () {
            if (!mounted) return;
            setState(() {
              _lines.clear();
              _selectedSunday = 0;
              _numeroCtrl.clear();
              _fieldError = null;
            });
            context.read<DomingueroCubit>().reset();
          });
        });
      case DomingueroStatus.error:
        if (_resumenOpen) {
          _resumenOpen = false;
          Navigator.of(context).pop();
        }
        final msg = state.errorMessage ?? 'Ocurrió un error. Intente nuevamente';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<DomingueroCubit>().reset();
        });
      default:
        break;
    }
  }

  // ── Diálogo resumen de transacción (Figma 1095:24381) ────────────────────

  Future<void> _showResumenDialog(
    BuildContext context,
    List<DomingueroLineaVerificada> lineas,
    DateTime fechaSorteo,
    DomingueroCubit cubit,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResumenTransaccionDialog(
        lineas: lineas,
        fechaSorteo: fechaSorteo,
        cubit: cubit,
        // Resetea el cubit al volver al formulario para que el usuario
        // pueda agregar más líneas y confirmar de nuevo.
        onAgregarOtraApuesta: () => cubit.reset(),
      ),
    );
  }

  // ── Diálogo comprobante ───────────────────────────────────────────────────

  void _showComprobanteDialog(
    BuildContext context,
    List<DomingueroBetResult> resultados, {
    required VoidCallback onClose,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ComprobanteDialog(
        resultados: resultados,
        onClose: () {
          Navigator.of(dialogCtx).pop();
          onClose();
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DomingueroCubit, DomingueroState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.errorMessage != curr.errorMessage,
      listener: _handleStateChange,
      builder: (context, domState) {
        final isApiLoading = domState.status == DomingueroStatus.verificando;

        return BlocBuilder<AuthCubit, AuthState>(
          buildWhen: (p, c) =>
              (p.user == null) != (c.user == null) || p.status != c.status,
          builder: (context, authState) {
            final loggedIn = authState.user != null ||
                authState.status == AuthStatus.success ||
                authState.status == AuthStatus.registrationSuccess;
            final sw = MediaQuery.of(context).size.width;
            final navH = _navH(sw, loggedIn);

            return Scaffold(
              backgroundColor: AppColors.homeBackground,
              body: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: navH),
                        if (_isSundayClosed)
                          _buildSundayClosedBanner()
                        else if (!loggedIn)
                          _buildAuthRequired(context)
                        else
                          _buildContent(
                            context,
                            sw,
                            domState.numeroBloqueadoInline,
                          ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  if (isApiLoading) _buildLoadingOverlay(),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: NavbarWidget(
                      isLoggedIn: loggedIn,
                      activeNavItem: 'Juegos',
                      onInicioTap: () => context.go(AppRoutes.home),
                      onResultadosTap: () => context.go(AppRoutes.resultados),
                      onWalletTap: loggedIn ? () {} : null,
                      onCartTap: loggedIn ? () {} : null,
                      onAvatarTap: loggedIn ? () {} : null,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF1372AE)),
      ),
    );
  }

  // ── Modal de sugerencias ──────────────────────────────────────────────────

  void _showSugerenciasModal(String? numeroBloqueado) {
    // Construye mapa de usos actuales: clave '${tag}_${numero}'
    final usosMap = <String, int>{};
    for (final line in _lines) {
      final key = '${line.modalidad.tag}_${line.numero}';
      usosMap[key] = (usosMap[key] ?? 0) + 1;
    }

    final sugerencias = DomingueroSugerenciasMock.generar(
      modalidad: _modalidad,
      numeroEnError: numeroBloqueado,
      usosPorNumero: usosMap,
    );

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogCtx) => _SugerenciasDialog(
        sugerencias: sugerencias,
        modalidad: _modalidad,
        onSelect: (numero) {
          Navigator.pop(dialogCtx);
          setState(() {
            _numeroCtrl.text = numero;
            _fieldError = null;
          });
          context.read<DomingueroCubit>().clearInline();
        },
      ),
    );
  }

  // ── Auth required ─────────────────────────────────────────────────────────

  void _showLoginModal(BuildContext ctx) {
    if (MediaQuery.sizeOf(ctx).width < 600) {
      ctx.push(AppRoutes.login);
      return;
    }
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: LoginFormWidget(
            onClose: () => Navigator.pop(dialogContext),
            onLoginSuccess: () => Navigator.pop(dialogContext),
            onRegisterRequested: () => Navigator.pop(dialogContext),
            onRecoveryRequested: (identifier) {
              Navigator.pop(dialogContext);
              dialogContext.push(AppRoutes.otpVerification, extra: {
                'destination': identifier,
                'flow': OtpFlow.passwordRecovery,
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAuthRequired(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.juegoImg2,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.lock_outline_rounded,
                      size: 80,
                      color: Color(0xFF2C2E6F))),
              const SizedBox(height: 20),
              Text('Inicia sesión para jugar',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F),
                      height: 1.3),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                  'Debes estar autenticado para realizar apuestas en El Dominguero.',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF4B5563),
                      height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1372AE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => _showLoginModal(ctx),
                  child: Text('Iniciar sesión',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sunday closed banner ──────────────────────────────────────────────────

  Widget _buildSundayClosedBanner() {
    final nextMonday = DateTime.now().add(const Duration(days: 1));
    const ms = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final nextOpenLabel = '${nextMonday.day} de ${ms[nextMonday.month]}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(AppAssets.juegoImg2,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_esports,
                      size: 80,
                      color: Color(0xFF2C2E6F))),
              const SizedBox(height: 20),
              Text(
                  'El Dominguero no está disponible en este momento',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F),
                      height: 1.3),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                  'Los domingos son día de sorteo. La venta abre nuevamente el lunes $nextOpenLabel.',
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF4B5563),
                      height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary500,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () => context.go(AppRoutes.juegos),
                  child: Text('Ver otros juegos',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout principal ──────────────────────────────────────────────────────

  Widget _buildContent(
      BuildContext context, double screenW, String? numeroBloqueado) {
    final isDesktop = screenW >= 1024;
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: _buildLeftCard(isDesktop, numeroBloqueado),
              ),
            ),
            const SizedBox(width: 40),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 779),
                child: _buildRightCard(context, numeroBloqueado),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          _buildLeftCard(isDesktop, numeroBloqueado),
          const SizedBox(height: 24),
          _buildRightCard(context, numeroBloqueado),
        ],
      ),
    );
  }

  // ── Left card ─────────────────────────────────────────────────────────────

  Widget _buildLeftCard(bool isDesktop, String? numeroBloqueado) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'Sigue los pasos para realizar tu chance',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F),
                      height: 28 / 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Apuesta abierta de lunes a sábados, juega y gana los domingos',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF4B5563),
                      height: 28 / 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF4B5563)),
                children: [
                  const TextSpan(
                      text:
                          '1.  Selecciona un día a jugar, juega con el sorteo de los resultados de '),
                  TextSpan(
                    text: 'Chontico Noche Festivo (domingos)',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F5886)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < _sundays.length; i++) ...[
                  _DateChip(
                    date: _fmtSunday(_sundays[i]),
                    dayLabel: 'domingo',
                    isSelected: i == _selectedSunday,
                    onTap: () => setState(() => _selectedSunday = i),
                  ),
                  if (i < _sundays.length - 1) const SizedBox(width: 13),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '2.  Escoge la cantidad de cifras',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF4B5563)),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: _AutomaticoBtn(onTap: _autoNumero),
          ),
          const SizedBox(height: 16),
          _buildStep2InputBlock(isDesktop, numeroBloqueado),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.bannerDominguero,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFFF9A825)]),
            ),
            alignment: Alignment.center,
            child: Text('El Dominguero\nMILLONARIO',
                style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
                textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2InputBlock(bool isDesktop, String? numeroBloqueado) {
    void onSelect(ModalidadDominguero m) {
      context.read<DomingueroCubit>().clearInline();
      setState(() {
        _modalidad = m;
        _fieldError = null;
        _numeroCtrl.clear();
      });
    }

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ModalidadButtons(selected: _modalidad, onSelect: onSelect),
          const SizedBox(width: 170),
          Expanded(child: _buildNumberInput(numeroBloqueado)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModalidadButtons(selected: _modalidad, onSelect: onSelect),
        const SizedBox(height: 16),
        _buildNumberInput(numeroBloqueado),
      ],
    );
  }

  Widget _buildNumberInput(String? numeroBloqueado) {
    final currentText = _numeroCtrl.text;
    final isBlocked =
        numeroBloqueado != null && numeroBloqueado == currentText;
    final hasFieldError = _fieldError != null;
    final borderColor = (isBlocked || hasFieldError)
        ? const Color(0xFFEE443F)
        : const Color(0xFFD1D5DB);
    final textColor =
        isBlocked ? const Color(0xFFEE443F) : const Color(0xFF4B5563);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Ingresa tu número',
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
              height: 24 / 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Container(
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(1, 2),
                  blurRadius: 4)
            ],
          ),
          child: TextField(
            controller: _numeroCtrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: _modalidad.digits,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textColor),
            decoration: InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: '?',
              hintStyle: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4B5563)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: _handleNumeroChanged,
          ),
        ),
        if (hasFieldError && !isBlocked) ...[
          const SizedBox(height: 4),
          Text(_fieldError!,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
              textAlign: TextAlign.center),
        ] else if (isBlocked) ...[
          const SizedBox(height: 4),
          // TEMPORAL_MOCK: E3 — número agotado o tercer intento del mismo número.
          // Cuando backend esté conectado, este error vendrá del servidor en tiempo real.
          // TODO: reemplazar por respuesta real de la API cuando exista contrato.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No puedes usar un número más de dos veces  ',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEE443F)),
                ),
                GestureDetector(
                  onTap: () => _showSugerenciasModal(numeroBloqueado),
                  child: Text(
                    'Sugerencias',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF1372AE),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 4),
                  blurRadius: 2)
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _modalidad.tag,
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4B5563)),
              ),
              const SizedBox(width: 8),
              for (int i = 0; i < _modalidad.digits; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _DigitBall(
                  digit: i < currentText.length ? currentText[i] : '?',
                  isError: isBlocked,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _addLine,
          child: Container(
            width: 223,
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
                color: const Color(0xFFFECA0C),
                borderRadius: BorderRadius.circular(4)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 16, color: Color(0xFF1372AE)),
                const SizedBox(width: 5),
                Text(
                  'Agregar otra línea de apuesta',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1372AE)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Right card ────────────────────────────────────────────────────────────

  Widget _buildRightCard(BuildContext context, String? numeroBloqueado) {
    final isCurrentValid = _isCurrentInputValid(numeroBloqueado);
    final effectiveCount = _lines.length + (isCurrentValid ? 1 : 0);

    // Premio potencial total: suma de los premios de todas las líneas válidas.
    // Regla de negocio (HU-DOM001, decisión PO): "Podrías ganar hasta" muestra
    // el acumulado si TODOS los números del usuario salen el mismo domingo.
    // Cada línea es una apuesta independiente con su propio premio.
    final allModalidades = [
      ..._lines.map((l) => l.modalidad),
      if (isCurrentValid) _modalidad,
    ];
    final maxPrize =
        allModalidades.fold(0, (sum, m) => sum + m.premio);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Así va tu juego',
            style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
                height: 28 / 22),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 492),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text('Tu apuesta',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4B5563))),
                ),
                // Líneas ya comprometidas (sin borde inferior — la fila actual lo cierra)
                for (int i = 0; i < _lines.length; i++) _buildBetLineRow(i),
                // Línea actual en tiempo real (siempre visible)
                _buildCurrentLineRow(_lines.length, isCurrentValid),
                const SizedBox(height: 8),
                _buildSummaryRow(
                    'IVA', _fmt(effectiveCount * _BetLine.ivaValue)),
                _buildSummaryRow(
                    'Valor apuesta', _fmt(effectiveCount * _BetLine.betValue)),
                const SizedBox(height: 16),
                _buildConfirmButton(context, isCurrentValid),
                const SizedBox(height: 16),
                Text(
                  'Podrías ganar hasta',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                      height: 28 / 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _buildPrizeButton(maxPrize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetLineRow(int i) {
    final line = _lines[i];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      // Solo borde superior; el borde inferior lo pone la fila de línea actual
      // que siempre aparece debajo de las líneas comprometidas.
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Línea ${i + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1372AE))),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
              children: [
                TextSpan(text: '${line.modalidad.tag}  '),
                TextSpan(
                    text: line.numero,
                    style: const TextStyle(color: Color(0xFFFFCC00))),
              ],
            ),
          ),
          Row(
            children: [
              Text('\$2.000',
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeLine(i),
                child:
                    const Icon(Icons.close, size: 16, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563))),
          const SizedBox(width: 18),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        ],
      ),
    );
  }

  /// Fila de la línea que el usuario está editando en este momento.
  /// Siempre visible en el resumen:
  /// - Si [isValid] es true muestra la modalidad + número real en amarillo.
  /// - Si no es válido muestra la modalidad + '?' como placeholder.
  Widget _buildCurrentLineRow(int lineIndex, bool isValid) {
    final currentText = _numeroCtrl.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00), width: 1),
          bottom: BorderSide(color: Color(0xFFFFCC00), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Línea ${lineIndex + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1372AE))),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
              children: [
                TextSpan(text: '${_modalidad.tag}  '),
                if (isValid)
                  TextSpan(
                      text: currentText,
                      style: const TextStyle(color: Color(0xFFFFCC00)))
                else
                  const TextSpan(text: '?'),
              ],
            ),
          ),
          Text('\$2.000',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(BuildContext context, bool isCurrentValid) {
    final hasLines = _lines.isNotEmpty || isCurrentValid;
    return SizedBox(
      height: 87,
      child: Center(
        child: SizedBox(
          width: 371,
          height: 57,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasLines
                  ? const Color(0xFF43B75D)
                  : const Color(0xFFD1D5DB),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            onPressed: hasLines ? () => _onConfirmar(context) : null,
            child: Text(
              'Confirmar y pagar',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: hasLines ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onConfirmar(BuildContext context) {
    final numBloqueado =
        context.read<DomingueroCubit>().state.numeroBloqueadoInline;
    final allLines = [..._lines];
    // Auto-incluye la línea actual si es válida (el usuario no necesita
    // presionar "Agregar" para que su número entre al pedido de confirmación).
    if (_isCurrentInputValid(numBloqueado)) {
      allLines.add(_BetLine(
          modalidad: _modalidad, numero: _numeroCtrl.text.trim()));
    }
    if (allLines.isEmpty) return;
    context.read<DomingueroCubit>().verificarLineas(
          allLines
              .map((l) => (numero: l.numero, modalidad: l.modalidad))
              .toList(),
        );
  }

  Widget _buildPrizeButton(int maxPrize) {
    return Container(
      width: double.infinity,
      height: 80,
      decoration: BoxDecoration(
          color: const Color(0xFF1450EF),
          borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.center,
      child: Text(
        maxPrize == 0 ? '\$ 0' : _fmt(maxPrize),
        style: GoogleFonts.inter(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFE30C),
          shadows: const [
            Shadow(color: Color(0xFFCEFFD8), blurRadius: 4),
            Shadow(
                color: Color(0xFFFFCC00), offset: Offset(0, -3), blurRadius: 20),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.date,
    required this.dayLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String date;
  final String dayLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF1372AE) : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 122,
        height: 65,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFCC00)
              : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1F131927),
                offset: Offset(0, 2),
                blurRadius: 4,
                spreadRadius: -2),
            BoxShadow(
                color: Color(0x14131927),
                offset: Offset(0, 4),
                blurRadius: 4,
                spreadRadius: -2),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sorteo',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                    height: 24 / 12)),
            Text(date,
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.24,
                    height: 1.0)),
            Text(dayLabel,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color,
                    letterSpacing: -0.1,
                    height: 17 / 10)),
          ],
        ),
      ),
    );
  }
}

class _ModalidadButtons extends StatelessWidget {
  const _ModalidadButtons(
      {required this.selected, required this.onSelect});

  final ModalidadDominguero selected;
  final ValueChanged<ModalidadDominguero> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModalidadBtn(
            label: '3 Cifras',
            isSelected: selected == ModalidadDominguero.tresC,
            onTap: () => onSelect(ModalidadDominguero.tresC)),
        if (selected == ModalidadDominguero.tresC) ...[
          const SizedBox(height: 4),
          Text(
            ModalidadDominguero.tresC.napaText,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563)),
          ),
        ],
        const SizedBox(height: 10),
        _ModalidadBtn(
            label: '4 Cifras',
            isSelected: selected == ModalidadDominguero.cuatroC,
            onTap: () => onSelect(ModalidadDominguero.cuatroC)),
        if (selected == ModalidadDominguero.cuatroC) ...[
          const SizedBox(height: 4),
          Text(
            ModalidadDominguero.cuatroC.napaText,
            style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B5563)),
          ),
        ],
      ],
    );
  }
}

class _ModalidadBtn extends StatelessWidget {
  const _ModalidadBtn(
      {required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 144,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFCC00)
              : const Color(0xFF4B5563),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 24 / 20),
        ),
      ),
    );
  }
}

class _AutomaticoBtn extends StatelessWidget {
  const _AutomaticoBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: const Color(0xFFFECA0C),
            borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppAssets.refreshCircular,
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                    Color(0xFF1372AE), BlendMode.srcIn)),
            const SizedBox(width: 5),
            Text('Automático',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1372AE))),
          ],
        ),
      ),
    );
  }
}

// ── Balota de dígito ─────────────────────────────────────────────────────────

class _DigitBall extends StatelessWidget {
  const _DigitBall({required this.digit, this.isError = false});
  final String digit;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 29,
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFAC5C3) : const Color(0xFFD1D5DB),
        borderRadius: BorderRadius.circular(80),
      ),
      alignment: Alignment.center,
      child: Text(
        isError ? '*' : digit,
        style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isError
                ? const Color(0xFFEE443F)
                : const Color(0xFF4B5563)),
      ),
    );
  }
}

// ── Modal de sugerencias de número ───────────────────────────────────────────

class _SugerenciasDialog extends StatelessWidget {
  const _SugerenciasDialog({
    required this.sugerencias,
    required this.modalidad,
    required this.onSelect,
  });

  final List<String> sugerencias;
  final ModalidadDominguero modalidad;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Construye las filas del grid (3 columnas por fila, gap 17px)
    final rows = <Widget>[];
    for (int r = 0; r * 3 < sugerencias.length; r++) {
      final items = <Widget>[];
      for (int c = 0; c < 3 && r * 3 + c < sugerencias.length; c++) {
        if (c > 0) items.add(const SizedBox(width: 17));
        final num = sugerencias[r * 3 + c];
        items.add(_SugerenciaItem(
          numero: num,
          digits: modalidad.digits,
          onTap: () => onSelect(num),
        ));
      }
      rows.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: items,
      ));
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Botón cerrar
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF4B5563), width: 1.5),
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Color(0xFF4B5563)),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Título
                Text(
                  'Puedes elegir estas opciones de número:',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                      height: 28 / 16),
                ),
                const SizedBox(height: 4),
                // Subtítulo
                Text(
                  'También puedes elegir un número automático',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                      height: 28 / 14),
                ),
                const SizedBox(height: 10),
                // Grid de sugerencias — escala hacia abajo en pantallas angostas
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 0),
                        rows[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Ítem individual de sugerencia: balotas amarillas con dígito azul + borde inferior
class _SugerenciaItem extends StatelessWidget {
  const _SugerenciaItem({
    required this.numero,
    required this.digits,
    required this.onTap,
  });

  final String numero;
  final int digits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Para 4 cifras las balotas escalan hacia abajo para caber en el mismo ancho
    // de 116px: 4×26 + 3×3 = 113px < 116px ✓
    // Para 3 cifras: 3×32 + 2×5 = 106px < 116px ✓
    final is4C = digits == 4;
    final ballW = is4C ? 26.0 : 32.28;
    final ballH = is4C ? 23.0 : 29.26;
    final ballGap = is4C ? 3.0 : 5.0;
    final fontSize = is4C ? 17.0 : 22.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        height: 40,
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFF1372AE), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < digits && i < numero.length; i++) ...[
              if (i > 0) SizedBox(width: ballGap),
              Container(
                width: ballW,
                height: ballH,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFCC00),
                  borderRadius: BorderRadius.circular(80),
                ),
                alignment: Alignment.center,
                child: Text(
                  numero[i],
                  style: GoogleFonts.inter(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1372AE),
                      height: 1.2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Método de pago ────────────────────────────────────────────────────────────

enum _MetodoPago { billetera, externo }

// ── Diálogo "Resumen de transacción" — Figma 1095:24381 ──────────────────────

class _ResumenTransaccionDialog extends StatefulWidget {
  const _ResumenTransaccionDialog({
    required this.lineas,
    required this.fechaSorteo,
    required this.cubit,
    required this.onAgregarOtraApuesta,
  });

  final List<DomingueroLineaVerificada> lineas;
  final DateTime fechaSorteo;
  final DomingueroCubit cubit;

  /// Callback invocado cuando el usuario elige "Agregar otra apuesta".
  /// El llamador debe resetear el cubit para permitir una nueva ronda.
  final VoidCallback onAgregarOtraApuesta;

  @override
  State<_ResumenTransaccionDialog> createState() =>
      _ResumenTransaccionDialogState();
}

class _ResumenTransaccionDialogState
    extends State<_ResumenTransaccionDialog> {
  _MetodoPago? _metodo;

  // IVA = 19 % del subtotal (HU-DOM001 no especifica; se toma 19 % estándar)
  static const double _ivaRate = 0.19;

  static String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  int get _subtotal => widget.lineas.length * 2000;
  int get _iva => (_subtotal * _ivaRate).round();
  int get _totalPagar => _subtotal + _iva;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: BlocBuilder<DomingueroCubit, DomingueroState>(
        builder: (ctx, state) {
          final isLoading = state.status == DomingueroStatus.registrando;
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Botón X cerrar ───────────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: isLoading
                              ? null
                              : () => Navigator.of(ctx).pop(),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF4B5563),
                                  width: 1.5),
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Color(0xFF4B5563)),
                          ),
                        ),
                      ),
                      // ── Título ───────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        child: Text(
                          'Resumen de transacción',
                          style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1372AE),
                              height: 1.0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // ── Texto informativo ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Text(
                          '¡Gracias por hacer tu apuesta en nuestra plataforma! con cada apuesta recibes una ñapa automática que aumenta el valor de tu premio.',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                              height: 24 / 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // ── Sección de resumen y pago ────────────────────────
                      _buildResumenPago(ctx, state, isLoading),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumenPago(
      BuildContext ctx, DomingueroState state, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtotal
          _buildAmountRow('Subtotal', _fmt(_subtotal), isBold: false),
          const SizedBox(height: 8),
          // IVA
          _buildAmountRow('IVA', _fmt(_iva), isBold: false),
          const SizedBox(height: 8),
          // Total a pagar — azul negrita
          _buildAmountRow(
            'Total a pagar',
            _fmt(_totalPagar),
            isBold: true,
            valueColor: const Color(0xFF1372AE),
          ),
          const SizedBox(height: 8),
          // Separador amarillo + "Elige un método de pago"
          Container(
            width: double.infinity,
            height: 48,
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFFFCC00), width: 1)),
            ),
            alignment: Alignment.center,
            child: Text(
              'Elige un método de pago',
              style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4B5563),
                  height: 24 / 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // Opción: Saldo en billetera
          _buildBilleteraOption(),
          const SizedBox(height: 8),
          // Opción: Medios externos (PSE / Mastercard / Visa)
          _buildExternoOption(),
          // Botón "Confirmar y pagar"
          _buildConfirmButton(ctx, isLoading),
          // Link "Agregar otra apuesta"
          _buildAgregarOtraApuesta(ctx, isLoading),
        ],
      ),
    );
  }

  /// Fila Subtotal / IVA / Total con alineación derecha.
  Widget _buildAmountRow(
    String label,
    String value, {
    required bool isBold,
    Color valueColor = Colors.black,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
                height: 24 / 20),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: isBold
                ? GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    height: 24 / 16)
                : GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                    height: 24 / 16),
          ),
        ],
      ),
    );
  }

  /// Opción de pago: Saldo en billetera.
  Widget _buildBilleteraOption() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _metodo = _MetodoPago.billetera),
        child: Container(
          width: 336,
          height: 48,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Radio<_MetodoPago>(
                value: _MetodoPago.billetera,
                groupValue: _metodo,
                onChanged: (v) => setState(() => _metodo = v),
                activeColor: const Color(0xFFFFCC00),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                    horizontal: -4, vertical: -4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saldo en billetera',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563)),
                ),
              ),
              // Badge de saldo
              Container(
                height: 33,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      AppAssets.iconDollar,
                      width: 16,
                      height: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '\$ 0',
                      style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Botón wallet dorado
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: const Color(0xFFC7B322),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  AppAssets.iconWallet,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opción de pago: medios externos (PSE, Mastercard, Visa).
  Widget _buildExternoOption() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _metodo = _MetodoPago.externo),
        child: Container(
          width: 336,
          height: 48,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Radio<_MetodoPago>(
                value: _MetodoPago.externo,
                groupValue: _metodo,
                onChanged: (v) => setState(() => _metodo = v),
                activeColor: const Color(0xFFFFCC00),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                    horizontal: -4, vertical: -4),
              ),
              const SizedBox(width: 12),
              // PSE badge
              _PaymentBadge(
                  label: 'PSE',
                  bg: const Color(0xFF007DC5),
                  fg: Colors.white),
              const SizedBox(width: 8),
              // Mastercard badge
              _PaymentBadge(
                  label: 'MC',
                  bg: const Color(0xFFEB5C29),
                  fg: Colors.white),
              const SizedBox(width: 8),
              // Visa badge
              _PaymentBadge(
                  label: 'VISA',
                  bg: const Color(0xFF1A1F71),
                  fg: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón verde "Confirmar y pagar" — deshabilitado si no hay método elegido.
  Widget _buildConfirmButton(BuildContext ctx, bool isLoading) {
    final canPay = _metodo != null && !isLoading;
    return Container(
      height: 87,
      alignment: Alignment.center,
      child: SizedBox(
        width: 371,
        height: 57,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: canPay
                ? const Color(0xFF43B75D)
                : const Color(0xFFD1D5DB),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26)),
            elevation: 0,
          ),
          onPressed: canPay
              ? () {
                  // TEMPORAL_MOCK: registra la apuesta usando el mock actual.
                  // TODO: cuando backend entregue contrato de pago, integrar
                  // el gateway correspondiente según [_metodo] (_MetodoPago.billetera
                  // o _MetodoPago.externo). NO hardcodear URL de Codesa/SuperFlex.
                  ctx
                      .read<DomingueroCubit>()
                      .registrarApuestas(widget.fechaSorteo);
                }
              : null,
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white))
              : Text(
                  'Confirmar y pagar',
                  style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: canPay
                          ? Colors.white
                          : const Color(0xFF9CA3AF)),
                ),
        ),
      ),
    );
  }

  /// Link "Agregar otra apuesta" con separador amarillo superior.
  Widget _buildAgregarOtraApuesta(BuildContext ctx, bool isLoading) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              widget.onAgregarOtraApuesta();
              Navigator.of(ctx).pop();
            },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: Color(0xFFFFCC00), width: 1)),
        ),
        alignment: Alignment.center,
        child: Text(
          'Agregar otra apuesta',
          style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1372AE),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF1372AE),
              height: 24 / 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Badge de método de pago externo ──────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg),
      ),
    );
  }
}

// ── Diálogo comprobante ───────────────────────────────────────────────────────

class _ComprobanteDialog extends StatelessWidget {
  const _ComprobanteDialog(
      {required this.resultados, required this.onClose});

  final List<DomingueroBetResult> resultados;
  final VoidCallback onClose;

  static String _fmtDate(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'mayo', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  static String _fmtDateTime(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}/${p(d.month)}/${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  static String _fmt(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '\$$buf';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF43B75D), size: 56),
              const SizedBox(height: 12),
              Text('¡Apuesta registrada!',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2C2E6F))),
              const SizedBox(height: 4),
              Text(
                  'Tu jugada quedó confirmada para el sorteo del domingo',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF4B5563)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: resultados
                        .map((r) => _buildComprobante(r))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1372AE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: onClose,
                  child: Text('Cerrar',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComprobante(DomingueroBetResult r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF43B75D).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Comprobante #${r.betId}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF4B5563))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1372AE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Tiraje ${r.tiraje} de 2',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1372AE))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _compRow('Modalidad', r.modalidad.label),
          _compRow('Número apostado', r.numero),
          _compRow('Sorteo', 'Chontico Noche Festivo'),
          _compRow('Fecha sorteo', _fmtDate(r.fechaSorteo)),
          _compRow('Fecha registro', _fmtDateTime(r.fechaRegistro)),
          _compRow('Valor apuesta', _fmt(r.valorApuesta)),
          _compRow('Premio en caso de acierto', _fmt(r.premio),
              highlight: true),
        ],
      ),
    );
  }

  Widget _compRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF4B5563))),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? const Color(0xFF1450EF)
                      : Colors.black)),
        ],
      ),
    );
  }
}

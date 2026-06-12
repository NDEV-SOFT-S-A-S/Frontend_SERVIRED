import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/login_redirect_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/otp_verification_screen.dart';
import '../../../home/presentation/widgets/navbar_widget.dart';
import '../../domain/entities/chance_millonario_entities.dart';
import '../cubit/chance_millonario_cubit.dart';
import '../cubit/chance_millonario_state.dart';
import '../helpers/chance_millonario_validator.dart';

// ── HU-CM001: Chance Millonario ──────────────────────────────────────────────
// Modalidad fija de 4 cifras, 5 números, 2 loterías diferentes del día.
// Valor fijo: $6.000. Acumulado mínimo: $1.000.000.000.
// El catálogo de loterías y el acumulado se cargan dinámicamente vía
// ChanceMillonarioCubit (mock activo hasta tener contrato de API).

// Presentación de cada lotería — asset y nombre en dos líneas, orden y assets
// exactos de Figma 1095:14179 y 1095:14187. La fuente de verdad del catálogo
// es el backend (state.loterias); este mapa solo resuelve el logo local.
const _kLoteriaAssets = <String, ({String asset, String display})>{
  'risaralda': (
    asset: AppAssets.logoRisaralda,
    display: 'Lotería del\nRisaralda'
  ),
  'meta': (asset: AppAssets.logoLoteriaMeta, display: 'Lotería del\nMeta'),
  'quindio': (
    asset: AppAssets.logoLoteriaQuindio,
    display: 'Lotería del\nQuindío'
  ),
  'cauca': (asset: AppAssets.logoLoteriaCauca, display: 'Lotería del\nCauca'),
  'medellin': (
    asset: AppAssets.logoLoteriaMedellin,
    display: 'Lotería de\nMedellín'
  ),
  'extra-medellin': (
    asset: AppAssets.logoLoteriaExtraMedellin,
    display: 'Extra Lotería\nde Medellín'
  ),
  'manizales': (
    asset: AppAssets.logoLoteriaManizales,
    display: 'Lotería de\nManizales'
  ),
  'cundinamarca': (
    asset: AppAssets.logoLoteriaCundinamarca,
    display: 'Lotería de\nCundinamarca'
  ),
  'boyaca': (asset: AppAssets.logoLoteriaBoyaca, display: 'Lotería de\nBoyacá'),
  'bogota': (asset: AppAssets.logoLoteriaBogota, display: 'Lotería de\nBogotá'),
  'valle': (asset: AppAssets.logoValle, display: 'Lotería del\nValle'),
  'tolima': (
    asset: AppAssets.logoLoteriaTolima,
    display: 'Lotería del\nTolima'
  ),
  'huila': (asset: AppAssets.logoLoteriaHuila, display: 'Lotería del\nHuila'),
  'santander': (
    asset: AppAssets.logoLoteriaSantander,
    display: 'Lotería de\nSantander'
  ),
};

// HU-CM001 RN-1: valor fijo de la apuesta = $6.000 (fallback si la info
// del backend aún no ha cargado).
const int _kBetValueFallback = 6000;

// IVA = monto × 19 / 119 — mismo patrón que Chance Tradicional (resolución
// G-000004). El valor $579 que muestra el Figma es un placeholder de diseño.
int _ivaDe(int total) => (total * 19 / 119).round();

// ── Screen wrapper — provee ChanceMillonarioCubit ─────────────────────────────

class ChanceMillonarioScreen extends StatelessWidget {
  const ChanceMillonarioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ChanceMillonarioCubit>()..loadJuego(),
      child: const _ChanceMillonarioView(),
    );
  }
}

class _ChanceMillonarioView extends StatefulWidget {
  const _ChanceMillonarioView();

  @override
  State<_ChanceMillonarioView> createState() => _ChanceMillonarioViewState();
}

class _ChanceMillonarioViewState extends State<_ChanceMillonarioView> {
  // 5 controladores para los 5 números de 4 cifras (HU-CM001 Entradas)
  final List<TextEditingController> _numCtrl =
      List.generate(5, (_) => TextEditingController());
  final List<String?> _numErrors = List.filled(5, null, growable: false);

  // Números que no se pueden jugar. Valor de prueba mientras no haya API.
  static const Set<String> _kNumerosQuemados = {'1111'};
  static bool _esNumeroQuemado(String num) =>
      _kNumerosQuemados.contains(num.trim());

  // true para cada campo cuyo número está quemado
  final List<bool> _numQuemado = List.filled(5, false, growable: false);

  // E2: error general cuando faltan números completos
  String? _numerosError;

  // Loterías seleccionadas por id — exactamente 2 distintas (HU-CM001 RN-2)
  final Set<String> _selectedLoterias = {};
  String? _loteriasError;

  @override
  void dispose() {
    for (final c in _numCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // Completa SOLO los campos vacíos o inválidos con números aleatorios de 4 cifras.
  // Los campos que ya tienen un valor válido (4 dígitos, sin error, no quemado)
  // NO se modifican — HU-CM001: el usuario puede mezclar entrada manual y automática.
  void _autoNumero() {
    final rand = math.Random();
    setState(() {
      for (int i = 0; i < 5; i++) {
        final current = _numCtrl[i].text.trim();
        final alreadyValid = current.length == 4 &&
            ChanceMillonarioValidator.validarNumero(current) == null &&
            !_esNumeroQuemado(current);

        if (alreadyValid) continue; // conserva el número del usuario

        String candidate;
        do {
          candidate = rand.nextInt(10000).toString().padLeft(4, '0');
        } while (_esNumeroQuemado(candidate));

        _numCtrl[i].text = candidate;
        _numErrors[i] = null;
        _numQuemado[i] = false;
      }
      _numerosError = null;
    });
  }

  // Genera 12 números únicos válidos (no quemados) para el modal de sugerencias.
  List<String> _generateSuggestions() {
    final rand = math.Random();
    final seen = <String>{};
    while (seen.length < 12) {
      final candidate = rand.nextInt(10000).toString().padLeft(4, '0');
      if (!_esNumeroQuemado(candidate)) seen.add(candidate);
    }
    return seen.toList();
  }

  // Abre el modal de sugerencias — Figma 1095:19350.
  // Al seleccionar una sugerencia llena únicamente el campo [fieldIndex].
  void _showSuggestionsModal(BuildContext ctx, int fieldIndex) {
    final suggestions = _generateSuggestions();
    final isMobile = MediaQuery.sizeOf(ctx).width < 600;

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: isMobile
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _SuggestionsModal(
          suggestions: suggestions,
          isMobile: isMobile,
          onSelect: (numero) {
            Navigator.pop(dialogCtx);
            setState(() {
              _numCtrl[fieldIndex].text = numero;
              _numErrors[fieldIndex] = null;
              _numQuemado[fieldIndex] = false;
              _numerosError = null;
            });
          },
          onClose: () => Navigator.pop(dialogCtx),
        ),
      ),
    );
  }

  // Selección de lotería — máximo 2 distintas (HU-CM001 E3)
  void _toggleLoteria(String id) {
    setState(() {
      _loteriasError = null;
      if (_selectedLoterias.contains(id)) {
        _selectedLoterias.remove(id);
      } else if (_selectedLoterias.length < 2) {
        _selectedLoterias.add(id);
      }
    });
  }

  // Validaciones HU-CM001 E1 + E2 + E3 + números quemados antes de registrar
  bool _validate() {
    bool valid = true;
    for (int i = 0; i < 5; i++) {
      _numErrors[i] = ChanceMillonarioValidator.validarNumero(_numCtrl[i].text);
      if (_numErrors[i] != null) valid = false;
      // Verifica número quemado solo cuando tiene 4 cifras (sin error de formato)
      _numQuemado[i] = _numErrors[i] == null &&
          _numCtrl[i].text.trim().length == 4 &&
          _esNumeroQuemado(_numCtrl[i].text);
      if (_numQuemado[i]) valid = false;
    }
    _numerosError = ChanceMillonarioValidator.validarNumeros(
      _numCtrl.map((c) => c.text).toList(),
    );
    if (_numerosError != null) valid = false;

    _loteriasError =
        ChanceMillonarioValidator.validarLoterias(_selectedLoterias);
    if (_loteriasError != null) valid = false;

    setState(() {});
    return valid;
  }

  // Paso 7-8 HU-CM001: valida y abre el resumen de transacción.
  // La apuesta NO se registra hasta que el usuario confirme dentro del modal.
  void _onConfirmar(BuildContext ctx) {
    if (!_validate()) return;
    final state = ctx.read<ChanceMillonarioCubit>().state;
    _showTransactionSummaryModal(ctx, state);
  }

  // Paso 9-10 HU-CM001: registra la apuesta tras confirmar en el resumen.
  void _onRegistrar(BuildContext ctx) {
    final lotIds = _selectedLoterias.toList();
    ctx.read<ChanceMillonarioCubit>().registrarApuesta(
          numeros: _numCtrl.map((c) => c.text.trim()).toList(),
          loteria1Id: lotIds[0],
          loteria2Id: lotIds[1],
        );
  }

  // Modal de resumen de transacción — Figma 1095:13902.
  // La apuesta solo queda registrada cuando el usuario presiona
  // "Confirmar y pagar" dentro del modal (HU-CM001 postcondiciones).
  void _showTransactionSummaryModal(
    BuildContext ctx,
    ChanceMillonarioState state,
  ) {
    final betValue = state.info?.valorApuesta ?? _kBetValueFallback;
    // HU-CM001 RN-1: el valor a pagar es $6.000 fijo. No se suma IVA al total.
    const iva = 0;
    final total = betValue;
    final isMobile = MediaQuery.sizeOf(ctx).width < 600;

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: isMobile
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _TransactionSummaryModal(
          betValue: betValue,
          iva: iva,
          total: total,
          isMobile: isMobile,
          // Solo aquí (dentro del modal) se dispara el registro real.
          onConfirmar: () {
            Navigator.pop(dialogCtx);
            _onRegistrar(ctx);
          },
          // Cierra el modal sin registrar — el usuario puede seguir editando.
          onAgregarApuesta: () => Navigator.pop(dialogCtx),
          onClose: () => Navigator.pop(dialogCtx),
        ),
      ),
    );
  }

  void _onNuevaApuesta(BuildContext context) {
    setState(() {
      for (final c in _numCtrl) {
        c.clear();
      }
      for (int i = 0; i < 5; i++) {
        _numErrors[i] = null;
        _numQuemado[i] = false;
      }
      _numerosError = null;
      _selectedLoterias.clear();
      _loteriasError = null;
    });
    context.read<ChanceMillonarioCubit>().nuevaApuesta();
  }

  static String _fmt(int amount) {
    if (amount == 0) return '\$0';
    final s = amount.toString();
    final buf = StringBuffer('\$');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static double _navH(double w, bool loggedIn) {
    if (w < 720) return 64.0;
    return loggedIn ? 120.0 : 104.0;
  }

  bool get _canConfirm =>
      _numCtrl.every((c) => c.text.trim().length == 4) &&
      _selectedLoterias.length == 2 &&
      !_numQuemado.any((q) => q);

  // ── Auth modal (mismo patrón que ChanceTradicionalScreen) ─────────────────

  void _showLoginModal(BuildContext ctx) {
    if (MediaQuery.sizeOf(ctx).width < 600) {
      LoginRedirectService.save(AppRoutes.chanceMillonario);
      ctx.push(AppRoutes.login);
      return;
    }
    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: SingleChildScrollView(
          child: LoginFormWidget(
            onClose: () => Navigator.pop(dialogContext),
            onLoginSuccess: () => Navigator.pop(dialogContext),
            onRegisterRequested: () => Navigator.pop(dialogContext),
            onRecoveryRequested: (identifier) {
              Navigator.pop(dialogContext);
              dialogContext.push(
                AppRoutes.otpVerification,
                extra: {
                  'destination': identifier,
                  'flow': OtpFlow.passwordRecovery,
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // E4/E6: errores de registro se muestran y el formulario queda editable.
  void _handleStateChange(BuildContext context, ChanceMillonarioState state) {
    if (state.status == ChanceMillonarioStatus.errorRegistro &&
        state.errorMessage != null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      context.read<ChanceMillonarioCubit>().dismissRegistroError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChanceMillonarioCubit, ChanceMillonarioState>(
      listenWhen: (p, c) =>
          p.status != c.status || p.errorMessage != c.errorMessage,
      listener: _handleStateChange,
      builder: (context, cmState) {
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
                        if (!loggedIn)
                          _buildAuthRequired(context)
                        else
                          _buildBody(sw, cmState),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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

  // ── Cuerpo según estado del cubit (SPEC-FE-001 §12) ───────────────────────

  Widget _buildBody(double screenW, ChanceMillonarioState state) {
    switch (state.status) {
      case ChanceMillonarioStatus.initial:
      case ChanceMillonarioStatus.cargando:
        return _buildLoading();
      case ChanceMillonarioStatus.errorCarga:
        // E5: no se permite registrar la apuesta
        return _buildInfoBox(
          icon: Icons.error_outline_rounded,
          title: 'No fue posible cargar las loterías disponibles',
          message: state.errorMessage ??
              'No fue posible cargar las loterías disponibles. Intente nuevamente más tarde',
          actionLabel: 'Reintentar',
          onAction: () => context.read<ChanceMillonarioCubit>().loadJuego(),
        );
      case ChanceMillonarioStatus.noDisponible:
        // E7: juego no disponible para fecha o región
        return _buildInfoBox(
          icon: Icons.event_busy_rounded,
          title: 'Juego no disponible',
          message:
              'Chance Millonario no está disponible para la fecha o región actual. No es posible realizar apuestas en este momento.',
        );
      case ChanceMillonarioStatus.sinLoterias:
        // A4: sin sorteos para el día
        return _buildInfoBox(
          icon: Icons.calendar_today_rounded,
          title: 'Sin sorteos disponibles',
          message:
              'No hay loterías o sorteos disponibles para la fecha seleccionada. Intenta en la próxima fecha habilitada.',
          actionLabel: 'Reintentar',
          onAction: () => context.read<ChanceMillonarioCubit>().loadJuego(),
        );
      case ChanceMillonarioStatus.cargado:
      case ChanceMillonarioStatus.registrando:
      case ChanceMillonarioStatus.exito:
      case ChanceMillonarioStatus.errorRegistro:
        return _buildContent(screenW, state);
    }
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 120),
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFF1372AE)),
      ),
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: const Color(0xFF2C2E6F)),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2E6F),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1372AE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: onAction,
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Auth required (mismo patrón que ChanceTradicionalScreen) ──────────────

  Widget _buildAuthRequired(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  AppAssets.bannerChanceMillonario,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.lock_outline_rounded,
                    size: 80,
                    color: Color(0xFF2C2E6F),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Inicia sesión para jugar',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2E6F),
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Debes estar autenticado para realizar apuestas en Chance Millonario.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1372AE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () => _showLoginModal(ctx),
                  child: Text(
                    'Iniciar sesión',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Contenido principal ───────────────────────────────────────────────────

  Widget _buildContent(double screenW, ChanceMillonarioState state) {
    final isDesktop = screenW >= 1024;

    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: _buildLeftCard(isDesktop),
              ),
            ),
            const SizedBox(width: 24),
            Flexible(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 779),
                child: _buildRightCard(state),
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
          _buildLeftCard(isDesktop),
          const SizedBox(height: 24),
          _buildRightCard(state),
        ],
      ),
    );
  }

  // ── Left card ─────────────────────────────────────────────────────────────
  // Figma 1095:14166 — 779px, white, rounded-30, padding-20

  Widget _buildLeftCard(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBanner(),
          const SizedBox(height: 16),
          _buildTitle(),
          const SizedBox(height: 16),
          _buildStep1(isDesktop),
        ],
      ),
    );
  }

  // Banner — 746×150, rounded=16, BoxFit.cover (Figma 1095:16829)
  Widget _buildBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: Image.asset(
          AppAssets.bannerChanceMillonario,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFFD4AF37)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'CHANCE\nMILLONARIO',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // "Sigue los pasos para realizar tu chance" — Inter Bold 22px, #2C2E6F
  Widget _buildTitle() {
    return Center(
      child: Text(
        'Sigue los pasos para realizar tu chance',
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF2C2E6F),
          height: 28 / 22,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Paso 1 — selección de números (Figma 1095:14170 + 1095:16743)
  Widget _buildStep1(bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "1. Elige tus número" — Inter Regular 16px, #4B5563 (Figma 1095:14171)
        Text(
          '1. Elige tus número',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 10),

        // Botón Automático — #FECA0C, h=28, rounded=4 (Figma 1095:14172)
        _AutomaticoBtn(onTap: _autoNumero),
        const SizedBox(height: 10),

        // Layout: izquierda "4 Cifras" + derecha 5 inputs
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCifrasLabel(),
                  const SizedBox(width: 40),
                  Expanded(child: _buildNumberInputsColumn()),
                ],
              )
            : Column(
                children: [
                  _buildCifrasLabel(),
                  const SizedBox(height: 12),
                  _buildNumberInputsColumn(),
                ],
              ),

        // E2: mensaje general — exactamente 5 números de 4 cifras
        if (_numerosError != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              _numerosError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  // Botón "4 Cifras" (estático) — 144×36, #FFCC00, rounded=14 (Figma 1095:16747)
  Widget _buildCifrasLabel() {
    return Container(
      width: 144,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFFECA0C),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '4 Cifras',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1372AE),
          height: 24 / 20,
        ),
      ),
    );
  }

  // Columna derecha — 5 pares (input + display 4C balotas) (Figma 1095:16748)
  Widget _buildNumberInputsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Ingresa 5 números de 4 cifras" — Poppins SemiBold 14px (Figma 1095:16750)
        Text(
          'Ingresa 5 números de 4 cifras',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4B5563),
            height: 24 / 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        for (int i = 0; i < 5; i++) ...[
          _buildNumberInput(i),
          if (_numErrors[i] != null) ...[
            const SizedBox(height: 2),
            Text(
              _numErrors[i]!,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (_numQuemado[i]) ...[
            const SizedBox(height: 2),
            _buildMensajeQuemado(i),
          ],
          const SizedBox(height: 8),
          _buildBalotas4C(i),
          if (i < 4) const SizedBox(height: 8),
        ],
      ],
    );
  }

  // Input field — 421×45, border grey-300, rounded=14, shadow (Figma 1095:16751)
  // Estado quemado (Figma 1095:16883): borde + texto rojo #EE443F
  Widget _buildNumberInput(int index) {
    final isQuemado = _numQuemado[index];
    final hasError = _numErrors[index] != null;
    final borderColor = (hasError || isQuemado)
        ? const Color(0xFFEE443F)
        : const Color(0xFFD1D5DB);
    final textColor =
        isQuemado ? const Color(0xFFEE443F) : const Color(0xFF4B5563);

    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: TextField(
        controller: _numCtrl[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: '?',
          hintStyle: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9CA3AF),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        // Validación en tiempo real + detección de número quemado
        onChanged: (value) => setState(() {
          _numErrors[index] = value.isEmpty
              ? null
              : ChanceMillonarioValidator.validarNumero(value);
          _numQuemado[index] = _numErrors[index] == null &&
              value.trim().length == 4 &&
              _esNumeroQuemado(value);
          _numerosError = null;
        }),
      ),
    );
  }

  // Display "4C" + 4 balotas — Figma 1095:20264: grey-100, h=44, w=300, p=10, gap=10/5
  // Estado quemado (Figma Balotas propiedad1="4c error"): fondo #FAC5C3, texto "*"
  Widget _buildBalotas4C(int numIndex) {
    final text = _numCtrl[numIndex].text.trim();
    final isQuemado = _numQuemado[numIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 4),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '4C',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 10),
          for (int d = 0; d < 4; d++) ...[
            _Balota(
              digit: d < text.length ? text[d] : '?',
              isHighlight: !isQuemado && d < text.length,
              isQuemado: isQuemado && d < text.length,
            ),
            if (d < 3) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }

  // ── Right card ────────────────────────────────────────────────────────────
  // Figma 1095:14176 — 780px, white, rounded-30, padding-20

  Widget _buildRightCard(ChanceMillonarioState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "2. Selecciona dos loterías" (Figma 1095:14178)
          Text(
            '2. Selecciona dos loterías',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),

          // Grid 7×2 de tarjetas de lotería — catálogo dinámico del día
          // (Figma 1095:14179 + 1095:14187)
          _buildLoteriaGrid(state.loterias),

          if (_loteriasError != null) ...[
            const SizedBox(height: 6),
            Text(
              _loteriasError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: 16),

          // "Así va tu juego" (Figma 1095:14196)
          Center(
            child: Text(
              'Así va tu juego',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C2E6F),
                height: 28 / 22,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resumen (Figma 1095:20304) — 537px centrado (items-center del card)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 537),
              child: _buildResumen(state),
            ),
          ),
        ],
      ),
    );
  }

  // Grid de loterías — 7 columnas, celdas 87×87, gap ~18px
  Widget _buildLoteriaGrid(List<LoteriaDelDia> loterias) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const cols = 7;
        const sidePadding = 10.0;
        const gap = 14.0;
        final available = constraints.maxWidth - 2 * sidePadding;
        final cellW = (available - gap * (cols - 1)) / cols;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: sidePadding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final loteria in loterias)
                SizedBox(
                  width: cellW,
                  height: cellW, // cuadrado, como en Figma (87×87)
                  child: _LoteriaCell(
                    name:
                        _kLoteriaAssets[loteria.id]?.display ?? loteria.nombre,
                    asset: _kLoteriaAssets[loteria.id]?.asset ?? '',
                    isSelected: _selectedLoterias.contains(loteria.id),
                    onTap: () => _toggleLoteria(loteria.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Resumen de apuesta (Figma 1095:14197) ─────────────────────────────────

  Widget _buildResumen(ChanceMillonarioState state) {
    final betValue = state.info?.valorApuesta ?? _kBetValueFallback;
    final acumulado = state.info?.acumulado ?? 0;

    LoteriaDelDia? byId(String id) {
      for (final l in state.loterias) {
        if (l.id == id) return l;
      }
      return null;
    }

    final lotIds = _selectedLoterias.toList();
    final lot1Name = lotIds.isNotEmpty ? byId(lotIds[0])?.nombre : null;
    final lot2Name = lotIds.length > 1 ? byId(lotIds[1])?.nombre : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Tu apuesta" — Poppins SemiBold 14px, #4B5563 (Figma I1095:14197;1035:16635)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'Tu apuesta',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Fila de números — border-top #FFCC00, justify-center (Figma I1095:20304;1035:16636)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFFFCC00), width: 1),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Números',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  for (int i = 0; i < 5; i++) ...[
                    Text(
                      _numCtrl[i].text.trim().isEmpty
                          ? '????'
                          : _numCtrl[i].text.trim(),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFCC00),
                      ),
                    ),
                    if (i < 4) const SizedBox(width: 16),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Fila de loterías — border-bottom #FFCC00, justify-center (Figma I1095:20304;1035:16643)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFFFCC00), width: 1),
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'Lotería '),
                        TextSpan(
                          text: lot1Name ?? '****',
                          style: const TextStyle(color: Color(0xFFFFCC00)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      children: [
                        const TextSpan(text: 'Lotería '),
                        TextSpan(
                          text: lot2Name ?? '****',
                          style: const TextStyle(color: Color(0xFFFFCC00)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _fmt(betValue),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // IVA (Figma I1095:14197;1035:16647–16649)
        _buildSummaryRow('IVA', _fmt(_ivaDe(betValue))),

        // Valor apuesta (Figma I1095:14197;1035:16650–16652)
        _buildSummaryRow('Valor apuesta', _fmt(betValue)),

        const SizedBox(height: 16),

        // Confirmar y pagar — verde #43b75d, h=57, rounded=26 (Figma)
        if (state.status == ChanceMillonarioStatus.exito &&
            state.resultado != null)
          _buildComprobante(state.resultado!)
        else
          _buildConfirmButton(
            isLoading: state.status == ChanceMillonarioStatus.registrando,
          ),

        const SizedBox(height: 20),

        // "Acumulado pago para mutual*" (Figma I1095:14197;1035:16655)
        Center(
          child: Text(
            'Acumulado pago para mutual*',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1372AE),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Caja del acumulado vigente — #155CFA, h=80, rounded=16
        // (Figma I1095:14197;1035:16657). HU-CM001 A1: el acumulado se
        // muestra de forma prominente; mínimo $1.000 millones.
        _buildPrizeBox(acumulado),
      ],
    );
  }

  // Mensaje "número quemado" — Figma 1095:17247
  // Inter Bold 14px: texto red-300 (#F4827E) + link "Sugerencias" azul subrayado.
  // Al tocar "Sugerencias" se abre el modal de sugerencias (Figma 1095:19350).
  Widget _buildMensajeQuemado(int index) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Te invitamos a elegir otro número   ',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF4827E),
            height: 28 / 14,
          ),
        ),
        GestureDetector(
          onTap: () => _showSuggestionsModal(context, index),
          child: Text(
            'Sugerencias',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1372AE),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF1372AE),
              height: 28 / 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton({required bool isLoading}) {
    final enabled = _canConfirm && !isLoading;
    // Figma I1095:20304;1035:16653: wrapper w-full h-87, button w-371 h-57 centrado
    return SizedBox(
      width: double.infinity,
      height: 87,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 371),
          child: SizedBox(
            width: double.infinity,
            height: 57,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _canConfirm
                    ? const Color(0xFF43B75D)
                    : const Color(0xFFBDD7EE),
                disabledBackgroundColor: _canConfirm
                    ? const Color(0xFF43B75D).withValues(alpha: 0.7)
                    : const Color(0xFFBDD7EE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: enabled ? () => _onConfirmar(context) : null,
              child: isLoading
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Text(
                      'Confirmar y pagar',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _canConfirm
                            ? Colors.white
                            : const Color(0xFF6B99B9),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Comprobante de la apuesta registrada (HU-CM001 flujo normal paso 10:
  // registro + descuento de saldo + comprobante con los datos de la jugada)
  Widget _buildComprobante(ChanceMillonarioBetResult resultado) {
    String p(int n) => n.toString().padLeft(2, '0');
    final f = resultado.fechaRegistro;
    final fecha =
        '${p(f.day)}/${p(f.month)}/${f.year} ${p(f.hour)}:${p(f.minute)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF43B75D)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF43B75D), size: 32),
          const SizedBox(height: 8),
          Text(
            '¡Apuesta registrada exitosamente!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B5E20),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Comprobante ${resultado.betId}\n$fecha',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Chance Millonario · ${resultado.numeros.join(' · ')}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF2E7D32),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            '${resultado.loteria1.nombre} · ${resultado.loteria2.nombre} · ${_fmt(resultado.valorApuesta)}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF2E7D32),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _onNuevaApuesta(context),
            child: Text(
              'Realizar otra apuesta',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Caja del acumulado — Figma I1095:20304;1035:16657: w-492 h-80, centrado en w-537
  Widget _buildPrizeBox(int acumulado) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 492),
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF155CFA),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_fmt(acumulado)} COP',
              style: GoogleFonts.inter(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFE30C),
                shadows: const [
                  Shadow(color: Color(0xFFCEFFD8), blurRadius: 4),
                  Shadow(
                    color: Color(0xFFFFCC00),
                    offset: Offset(0, -3),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

// Botón Automático — h=28, #FECA0C, rounded=4 (Figma 1095:14172)
class _AutomaticoBtn extends StatelessWidget {
  const _AutomaticoBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFECA0C),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.refreshCircular,
              width: 16,
              height: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Automático',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1372AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Balota individual — Figma 1095:20266
// Llenada:  #FFCC00 bg, texto #1372AE
// Placeholder: #D1D5DB bg, texto #9CA3AF
// Quemada (Figma "4c error"): #FAC5C3 bg, texto "*" #EE443F, opacidad 0.9
class _Balota extends StatelessWidget {
  const _Balota({
    required this.digit,
    this.isHighlight = false,
    this.isQuemado = false,
  });

  final String digit;
  final bool isHighlight;
  final bool isQuemado;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String displayText;

    if (isQuemado) {
      bgColor = const Color(0xFFFAC5C3);
      textColor = const Color(0xFFEE443F);
      displayText = '*';
    } else if (isHighlight) {
      bgColor = const Color(0xFFFFCC00);
      textColor = const Color(0xFF1372AE);
      displayText = digit;
    } else {
      bgColor = const Color(0xFFD1D5DB);
      textColor = const Color(0xFF9CA3AF);
      displayText = digit;
    }

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Opacity(
        opacity: isQuemado ? 0.9 : 1.0,
        child: Text(
          displayText,
          style: GoogleFonts.inter(
            fontSize: isQuemado ? 18 : 16,
            fontWeight: FontWeight.w700,
            color: textColor,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Modal de resumen de transacción — Figma 1095:13902 ───────────────────────
// Se muestra ANTES de registrar la apuesta. La apuesta solo se registra cuando
// el usuario presiona "Confirmar y pagar" dentro del modal (HU-CM001 pasos 7-10).

enum _MetodoPago { billetera, tarjeta }

class _TransactionSummaryModal extends StatefulWidget {
  const _TransactionSummaryModal({
    required this.betValue,
    required this.iva,
    required this.total,
    required this.isMobile,
    required this.onConfirmar,
    required this.onAgregarApuesta,
    required this.onClose,
  });

  final int betValue;
  final int iva;
  final int total;
  final bool isMobile;
  final VoidCallback onConfirmar;
  final VoidCallback onAgregarApuesta;
  final VoidCallback onClose;

  @override
  State<_TransactionSummaryModal> createState() =>
      _TransactionSummaryModalState();
}

class _TransactionSummaryModalState extends State<_TransactionSummaryModal> {
  _MetodoPago _metodo = _MetodoPago.billetera;

  static String _fmt(int amount) {
    if (amount == 0) return '\$0';
    final s = amount.toString();
    final buf = StringBuffer('\$');
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      constraints: widget.isMobile ? null : const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildCloseRow(),
            _buildTitle(),
            _buildInfoText(),
            _buildAmountSection(),
            _buildPaymentMethodSection(),
            _buildConfirmButton(),
            _buildAgregarLink(),
          ],
        ),
      ),
    );

    if (widget.isMobile) {
      return SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: inner,
        ),
      );
    }
    return Center(child: inner);
  }

  // Fila superior con botón de cierre — Figma 1095:13903
  Widget _buildCloseRow() {
    return SizedBox(
      height: 31,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF6B7280),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.close,
                size: 15,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Resumen de transacción" — Figma 1095:13908: Inter Bold 24px #1372AE
  Widget _buildTitle() {
    return SizedBox(
      height: 44,
      child: Center(
        child: Text(
          'Resumen de transacción',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1372AE),
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Texto informativo — Figma 1095:13910: Inter Regular 14px #4B5563
  Widget _buildInfoText() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        '¡Gracias por hacer tu apuesta en nuestra plataforma! '
        'con cada apuesta recibes una ñapa automática que aumenta el valor de tu premio.',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: const Color(0xFF4B5563),
          height: 24 / 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Filas Subtotal / IVA / Total — Figma I1095:13911;664:10018–10023 / 670:10480
  Widget _buildAmountSection() {
    return Column(
      children: [
        _buildAmountRow(
          label: 'Subtotal',
          value: _fmt(widget.betValue),
          valueColor: Colors.black,
          valueBold: false,
        ),
        const SizedBox(height: 8),
        _buildAmountRow(
          label: 'IVA',
          value: _fmt(widget.iva),
          valueColor: Colors.black,
          valueBold: false,
        ),
        const SizedBox(height: 8),
        _buildAmountRow(
          label: 'Total a pagar',
          value: _fmt(widget.total),
          valueColor: const Color(0xFF1372AE),
          valueBold: true,
        ),
      ],
    );
  }

  Widget _buildAmountRow({
    required String label,
    required String value,
    required Color valueColor,
    required bool valueBold,
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
              height: 24 / 20,
            ),
          ),
          const SizedBox(width: 18),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
              height: 24 / 16,
            ),
          ),
        ],
      ),
    );
  }

  // Sección métodos de pago — Figma I1095:13911;670:10484 en adelante
  Widget _buildPaymentMethodSection() {
    return Column(
      children: [
        // "Elige un método de pago" con borde superior amarillo
        // Figma I1095:13911;670:10484
        _buildSeparatorHeader('Elige un método de pago'),
        const SizedBox(height: 8),
        // Opción saldo en billetera — Figma I1095:13911;682:6347
        _buildWalletOption(),
        const SizedBox(height: 8),
        // Opción tarjetas/PSE — Figma I1095:13911;682:6419
        _buildCardOption(),
      ],
    );
  }

  Widget _buildSeparatorHeader(String text) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF4B5563),
          height: 24 / 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Radio visual — círculo vacío o relleno según selección
  Widget _buildRadio(bool selected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF1372AE) : const Color(0xFF9CA3AF),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1372AE),
              ),
            )
          : null,
    );
  }

  Widget _buildWalletOption() {
    final selected = _metodo == _MetodoPago.billetera;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 371),
        child: GestureDetector(
          onTap: () => setState(() => _metodo = _MetodoPago.billetera),
          child: Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: const Color(0xFF1372AE),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                _buildRadio(selected),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    'Saldo en billetera',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                ),
                // Chip de saldo — Figma I1095:13911;682:6331
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.attach_money,
                        size: 16,
                        color: Color(0xFF111827),
                      ),
                      Text(
                        '0',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Botón billetera — Figma I1095:13911;682:6342: #C7B322
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC7B322),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardOption() {
    final selected = _metodo == _MetodoPago.tarjeta;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 371),
        child: GestureDetector(
          onTap: () => setState(() => _metodo = _MetodoPago.tarjeta),
          child: Container(
            width: double.infinity,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(
                      color: const Color(0xFF1372AE),
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              children: [
                _buildRadio(selected),
                const SizedBox(width: 18),
                // Logo PSE — Figma I1095:13911;682:6422
                Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00529B),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PSE',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Visa placeholder — Figma I1095:13911;682:6424
                Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F71),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'VISA',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Mastercard placeholder — Figma I1095:13911;682:6431
                SizedBox(
                  width: 40,
                  height: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEB001B),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFFF79E1B).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
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

  // Botón "Confirmar y pagar" — Figma I1095:13911;664:10025: #43B75D h=57 rounded=26
  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 15),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 371),
          child: SizedBox(
            width: double.infinity,
            height: 57,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43B75D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              onPressed: widget.onConfirmar,
              child: Text(
                'Confirmar y pagar',
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
    );
  }

  // "Agregar otra apuesta" — Figma I1095:13911;682:6435-6436
  // Cierra el modal sin registrar para que el usuario edite la jugada.
  Widget _buildAgregarLink() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFFFCC00), width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: widget.onAgregarApuesta,
        child: Text(
          'Agregar otra apuesta',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1372AE),
            decoration: TextDecoration.underline,
            decorationColor: const Color(0xFF1372AE),
            height: 24 / 16,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Modal de sugerencias de número — Figma 1095:19350 ────────────────────────
// Container blanco rounded-16, px-20/py-10. Muestra 12 sugerencias en grid
// 3×4 (Wrap responsive). Cada sugerencia: 4 balotas amarillas + border-b azul.
// Al seleccionar: llena solo el campo del índice activo y cierra el modal.

class _SuggestionsModal extends StatelessWidget {
  const _SuggestionsModal({
    required this.suggestions,
    required this.isMobile,
    required this.onSelect,
    required this.onClose,
  });

  final List<String> suggestions;
  final bool isMobile;
  final ValueChanged<String> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      constraints: isMobile ? null : const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila cierre — Figma 1095:19351
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6B7280),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Título — Figma 1095:19355: Inter Bold 16px #1372AE
            Text(
              'Puedes elegir estas opciones de número:',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1372AE),
                height: 28 / 16,
              ),
            ),
            const SizedBox(height: 4),
            // Subtítulo — Figma 1095:19356: Inter Medium 14px #4B5563
            Text(
              'También puedes elegir un número automático',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4B5563),
                height: 28 / 14,
              ),
            ),
            const SizedBox(height: 10),
            // Grid de sugerencias — Figma: 3 columnas gap-17, runGap-10
            // Wrap responde en mobile: pasa a 2 columnas cuando el ancho lo requiere.
            Wrap(
              spacing: 17,
              runSpacing: 10,
              children: [
                for (final numero in suggestions)
                  _SugerenciaItem(
                    numero: numero,
                    onTap: () => onSelect(numero),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (isMobile) {
      return SafeArea(
        child: Align(alignment: Alignment.bottomCenter, child: inner),
      );
    }
    return Center(child: inner);
  }
}

// Sugerencia individual — Figma "sugerencia de número":
// w=147 h=40, border-b 1px #1372AE, 4 balotas amarillas gap-5px.
class _SugerenciaItem extends StatelessWidget {
  const _SugerenciaItem({
    required this.numero,
    required this.onTap,
  });

  final String numero;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 147,
        height: 40,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF1372AE), width: 1),
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < 4; i++) ...[
              _SugerenciaBalota(
                digit: i < numero.length ? numero[i] : '0',
              ),
              if (i < 3) const SizedBox(width: 5),
            ],
          ],
        ),
      ),
    );
  }
}

// Balota de sugerencia — Figma: w=32.284 h=29.26, rounded-80, bg #FFCC00,
// texto Inter Bold 22px #1372AE (secondary-500).
class _SugerenciaBalota extends StatelessWidget {
  const _SugerenciaBalota({required this.digit});
  final String digit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 29,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC00),
        borderRadius: BorderRadius.circular(80),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1372AE),
          height: 1,
        ),
      ),
    );
  }
}

// Celda de lotería — 87×87 (mismo patrón que ChanceTradicionalScreen._LoteriaCell)
// Figma: fondo blanco, borde grey-300/amarillo, logo arriba 63%, nombre abajo
class _LoteriaCell extends StatelessWidget {
  const _LoteriaCell({
    required this.name,
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFFFFCC00) : const Color(0xFF1372AE),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFCC00).withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoH = constraints.maxHeight * 0.63;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: logoH,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: asset.isEmpty
                        ? const Icon(
                            Icons.image_not_supported_outlined,
                            color: Color(0xFFD1D5DB),
                          )
                        : Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFD1D5DB),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F5886),
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

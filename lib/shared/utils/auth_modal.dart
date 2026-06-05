import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/register_step1_screen.dart';

/// Abre el flujo de inicio de sesión.
/// Mobile (<600px): navega a pantalla completa (AppRoutes.login).
/// Desktop/web: muestra modal card con LoginFormWidget.
///
/// No muestra pasos intermedios ni mensajes previos.
void showLoginRequired(BuildContext context) {
  if (MediaQuery.sizeOf(context).width < 600) {
    context.push(AppRoutes.login);
    return;
  }
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: LoginFormWidget(
          onClose: () => Navigator.pop(dialogContext),
          onLoginSuccess: () => Navigator.pop(dialogContext),
          onRegisterRequested: () {
            Navigator.pop(dialogContext);
            _showRegisterModal(context);
          },
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

void _showRegisterModal(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: RegisterFlowWidget(
          onClose: () => Navigator.pop(dialogContext),
          onLoginRequested: () {
            Navigator.pop(dialogContext);
            showLoginRequired(context);
          },
        ),
      ),
    ),
  );
}

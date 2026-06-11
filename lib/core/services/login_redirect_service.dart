/// Servicio singleton en memoria para recordar la ruta destino antes de
/// redirigir al usuario al login (flujo mobile con push a LoginScreen).
///
/// Uso:
///   1. Antes de `context.push(AppRoutes.login)`:
///        LoginRedirectService.save(AppRoutes.pataMillonaria);
///   2. En LoginScreen.onLoginSuccess:
///        final dest = LoginRedirectService.consume();
///        context.go(dest ?? AppRoutes.home);
///
/// La ruta se consume una sola vez (consume-once) para evitar redirecciones
/// incorrectas en logins posteriores.
class LoginRedirectService {
  LoginRedirectService._();

  static String? _pendingRedirect;

  /// Guarda la ruta destino que se usará después de un login exitoso.
  static void save(String path) => _pendingRedirect = path;

  /// Retorna y elimina la ruta guardada (consume-once).
  /// Retorna null si no hay ninguna ruta pendiente.
  static String? consume() {
    final path = _pendingRedirect;
    _pendingRedirect = null;
    return path;
  }

  /// Indica si existe una ruta pendiente.
  static bool get hasPending => _pendingRedirect != null;

  /// Limpia la ruta pendiente sin retornarla (útil en logout).
  static void clear() => _pendingRedirect = null;
}

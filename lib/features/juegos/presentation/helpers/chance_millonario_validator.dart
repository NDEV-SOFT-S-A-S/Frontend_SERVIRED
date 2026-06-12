// Validaciones de formulario de Chance Millonario (HU-CM001 E1, E2, E3).
// Separadas de la pantalla para poder probarlas con unit tests.

abstract final class ChanceMillonarioValidator {
  /// E1: cada número debe tener exactamente 4 cifras (0000–9999,
  /// conservando ceros a la izquierda). Retorna el mensaje de error o null.
  static String? validarNumero(String numero) {
    final n = numero.trim();
    if (n.length != 4 || int.tryParse(n) == null) {
      return 'El número debe tener exactamente 4 cifras';
    }
    return null;
  }

  /// E2: deben ingresarse exactamente 5 números de 4 cifras.
  static String? validarNumeros(List<String> numeros) {
    final completos = numeros.where((n) => validarNumero(n) == null).length;
    if (numeros.length != 5 || completos != 5) {
      return 'Debes ingresar exactamente 5 números de 4 cifras';
    }
    return null;
  }

  /// E3: deben seleccionarse exactamente 2 loterías o sorteos diferentes.
  static String? validarLoterias(Set<String> loteriaIds) {
    if (loteriaIds.length != 2) {
      return 'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día';
    }
    return null;
  }
}

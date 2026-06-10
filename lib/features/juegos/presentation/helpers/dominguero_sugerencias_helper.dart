import 'dart:math' as math;

import '../../domain/entities/dominguero_entities.dart';

/// TEMPORAL_MOCK: generador local de sugerencias de números disponibles.
///
/// TODO: reemplazar por llamada al endpoint de sugerencias cuando el backend
/// entregue el contrato de API.
/// Endpoint esperado: GET <API_BASE_URL>/api/dominguero/sugerencias?modalidad=3C
///
/// La clave de [usosPorNumero] sigue el formato '${modalidad.tag}_${numero}',
/// igual que el resto del mock de Dominguero.
class DomingueroSugerenciasMock {
  // Números pre-agotados del mock — nunca se sugieren.
  static const Set<String> _preAgotados3C = {'111'};
  static const Set<String> _preAgotados4C = {'1111'};

  static List<String> generar({
    required ModalidadDominguero modalidad,
    required String? numeroEnError,
    required Map<String, int> usosPorNumero,
    int cantidad = 12,
  }) {
    final digits = modalidad.digits;
    final maxVal = digits == 3 ? 999 : 9999;
    final preAgotados = digits == 3 ? _preAgotados3C : _preAgotados4C;
    final sugerencias = <String>[];
    final rng = math.Random();

    int intentos = 0;
    while (sugerencias.length < cantidad && intentos < 500) {
      intentos++;
      final num =
          rng.nextInt(maxVal + 1).toString().padLeft(digits, '0');
      if (num == numeroEnError) continue;
      if (preAgotados.contains(num)) continue;
      final key = '${modalidad.tag}_$num';
      if ((usosPorNumero[key] ?? 0) >= 2) continue;
      if (sugerencias.contains(num)) continue;
      sugerencias.add(num);
    }
    return sugerencias;
  }
}

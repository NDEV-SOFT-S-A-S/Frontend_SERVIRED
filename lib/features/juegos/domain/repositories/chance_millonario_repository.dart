import '../entities/chance_millonario_entities.dart';

abstract class ChanceMillonarioRepository {
  /// Disponibilidad del juego para el día/región y acumulado vigente (E7, A1).
  Future<ChanceMillonarioInfo> getInfoJuego();

  /// Catálogo de loterías y sorteos autorizados para el día de la apuesta (E5, A4).
  Future<List<LoteriaDelDia>> getLoteriasDelDia();

  /// Registra y paga la apuesta. El saldo solo se descuenta si el registro
  /// es exitoso (HU-CM001 postcondiciones, E4, E6).
  Future<ChanceMillonarioBetResult> registrarApuesta({
    required List<String> numeros,
    required String loteria1Id,
    required String loteria2Id,
  });
}

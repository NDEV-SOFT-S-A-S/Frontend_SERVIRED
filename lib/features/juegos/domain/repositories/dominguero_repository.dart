import '../entities/dominguero_entities.dart';

abstract class DomingueroRepository {
  Future<TirajeDisponibilidad> verificarTiraje({
    required String numero,
    required ModalidadDominguero modalidad,
  });

  Future<DomingueroBetResult> registrarApuesta({
    required String numero,
    required ModalidadDominguero modalidad,
    required DateTime fechaSorteo,
  });

  // Inline pre-validación: disponibilidad sin reservar tiraje.
  // Mock síncrono; real usará endpoint propio cuando exista contrato.
  Future<bool> isNumeroDisponible({
    required String numero,
    required ModalidadDominguero modalidad,
  });
}

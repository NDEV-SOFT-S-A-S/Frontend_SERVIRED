import '../entities/dominguero_entities.dart';
import '../repositories/dominguero_repository.dart';

class RegistrarApuestaDomingueroUseCase {
  const RegistrarApuestaDomingueroUseCase(this._repository);

  final DomingueroRepository _repository;

  Future<DomingueroBetResult> call({
    required String numero,
    required ModalidadDominguero modalidad,
    required DateTime fechaSorteo,
  }) =>
      _repository.registrarApuesta(
        numero: numero,
        modalidad: modalidad,
        fechaSorteo: fechaSorteo,
      );
}

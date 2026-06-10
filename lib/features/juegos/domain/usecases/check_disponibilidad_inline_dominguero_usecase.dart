import '../entities/dominguero_entities.dart';
import '../repositories/dominguero_repository.dart';

class CheckDisponibilidadInlineDomingueroUseCase {
  const CheckDisponibilidadInlineDomingueroUseCase(this._repo);

  final DomingueroRepository _repo;

  Future<bool> call({
    required String numero,
    required ModalidadDominguero modalidad,
  }) =>
      _repo.isNumeroDisponible(numero: numero, modalidad: modalidad);
}

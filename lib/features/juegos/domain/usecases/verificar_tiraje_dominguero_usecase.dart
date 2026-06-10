import '../entities/dominguero_entities.dart';
import '../repositories/dominguero_repository.dart';

class VerificarTirajeDomingueroUseCase {
  const VerificarTirajeDomingueroUseCase(this._repository);

  final DomingueroRepository _repository;

  Future<TirajeDisponibilidad> call({
    required String numero,
    required ModalidadDominguero modalidad,
  }) =>
      _repository.verificarTiraje(numero: numero, modalidad: modalidad);
}

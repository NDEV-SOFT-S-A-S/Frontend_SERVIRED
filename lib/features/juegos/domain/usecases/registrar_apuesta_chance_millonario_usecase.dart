import '../entities/chance_millonario_entities.dart';
import '../repositories/chance_millonario_repository.dart';

class RegistrarApuestaChanceMillonarioUseCase {
  const RegistrarApuestaChanceMillonarioUseCase(this._repository);

  final ChanceMillonarioRepository _repository;

  Future<ChanceMillonarioBetResult> call({
    required List<String> numeros,
    required String loteria1Id,
    required String loteria2Id,
  }) =>
      _repository.registrarApuesta(
        numeros: numeros,
        loteria1Id: loteria1Id,
        loteria2Id: loteria2Id,
      );
}

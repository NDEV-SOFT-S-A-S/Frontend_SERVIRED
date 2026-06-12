import '../entities/chance_millonario_entities.dart';
import '../repositories/chance_millonario_repository.dart';

class GetInfoChanceMillonarioUseCase {
  const GetInfoChanceMillonarioUseCase(this._repository);

  final ChanceMillonarioRepository _repository;

  Future<ChanceMillonarioInfo> call() => _repository.getInfoJuego();
}

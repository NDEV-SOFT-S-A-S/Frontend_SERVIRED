import '../entities/chance_millonario_entities.dart';
import '../repositories/chance_millonario_repository.dart';

class GetLoteriasChanceMillonarioUseCase {
  const GetLoteriasChanceMillonarioUseCase(this._repository);

  final ChanceMillonarioRepository _repository;

  Future<List<LoteriaDelDia>> call() => _repository.getLoteriasDelDia();
}

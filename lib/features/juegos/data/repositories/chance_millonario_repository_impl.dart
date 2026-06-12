import '../../domain/entities/chance_millonario_entities.dart';
import '../../domain/repositories/chance_millonario_repository.dart';
import '../datasources/chance_millonario_remote_datasource.dart';
import '../models/chance_millonario_models.dart';

class ChanceMillonarioRepositoryImpl implements ChanceMillonarioRepository {
  const ChanceMillonarioRepositoryImpl({required this.remoteDataSource});

  final ChanceMillonarioRemoteDataSource remoteDataSource;

  @override
  Future<ChanceMillonarioInfo> getInfoJuego() async {
    final response = await remoteDataSource.getInfoJuego();
    return response.toEntity();
  }

  @override
  Future<List<LoteriaDelDia>> getLoteriasDelDia() async {
    final response = await remoteDataSource.getLoteriasDelDia();
    return response.map((m) => m.toEntity()).toList();
  }

  @override
  Future<ChanceMillonarioBetResult> registrarApuesta({
    required List<String> numeros,
    required String loteria1Id,
    required String loteria2Id,
  }) async {
    final response = await remoteDataSource.registrarApuesta(
      RegistrarApuestaCmRequest(
        numeros: numeros,
        loteria1Id: loteria1Id,
        loteria2Id: loteria2Id,
      ),
    );
    return response.toEntity();
  }
}

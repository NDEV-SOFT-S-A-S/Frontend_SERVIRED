import '../../domain/entities/dominguero_entities.dart';
import '../../domain/repositories/dominguero_repository.dart';
import '../datasources/dominguero_remote_datasource.dart';
import '../models/dominguero_models.dart';

class DomingueroRepositoryImpl implements DomingueroRepository {
  const DomingueroRepositoryImpl({required this.remoteDataSource});

  final DomingueroRemoteDataSource remoteDataSource;

  @override
  Future<TirajeDisponibilidad> verificarTiraje({
    required String numero,
    required ModalidadDominguero modalidad,
  }) async {
    final response = await remoteDataSource.verificarTiraje(
      VerificarTirajeRequest(numero: numero, modalidad: modalidad),
    );
    return response.toEntity(modalidad);
  }

  @override
  Future<DomingueroBetResult> registrarApuesta({
    required String numero,
    required ModalidadDominguero modalidad,
    required DateTime fechaSorteo,
  }) async {
    final response = await remoteDataSource.registrarApuesta(
      RegistrarApuestaRequest(
          numero: numero, modalidad: modalidad, fechaSorteo: fechaSorteo),
    );
    return response.toEntity(modalidad);
  }

  @override
  Future<bool> isNumeroDisponible({
    required String numero,
    required ModalidadDominguero modalidad,
  }) =>
      remoteDataSource.checkDisponibilidadInline(numero, modalidad);
}

import 'package:dio/dio.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/dominguero_entities.dart';
import '../models/dominguero_models.dart';

// BLOQUEO: No existe contrato de API del backend para el módulo Dominguero.
// Endpoints esperados (pendiente documentación oficial del equipo backend):
//   POST <API_BASE_URL>/api/dominguero/verificar-tiraje
//   POST <API_BASE_URL>/api/dominguero/registrar-apuesta
// Para activar llamadas reales: compilar con --dart-define=USE_MOCK=false
// una vez que el backend entregue los contratos y el ambiente esté disponible.

abstract class DomingueroRemoteDataSource {
  Future<VerificarTirajeResponse> verificarTiraje(VerificarTirajeRequest request);
  Future<RegistrarApuestaResponse> registrarApuesta(RegistrarApuestaRequest request);
  // Inline check: valida disponibilidad sin bloquear tiraje.
  // Mock usa la misma tabla que verificarTiraje; real usará endpoint propio.
  Future<bool> checkDisponibilidadInline(
      String numero, ModalidadDominguero modalidad);
}

class DomingueroRemoteDataSourceImpl implements DomingueroRemoteDataSource {
  const DomingueroRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  // defaultValue: true — mock activo por defecto hasta que exista contrato de API.
  static const bool _useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  @override
  Future<VerificarTirajeResponse> verificarTiraje(
      VerificarTirajeRequest request) async {
    if (_useMock) return _mockVerificarTiraje(request);
    try {
      final res = await dio.post(
        '/api/dominguero/verificar-tiraje',
        data: request.toJson(),
      );
      return VerificarTirajeResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<bool> checkDisponibilidadInline(
      String numero, ModalidadDominguero modalidad) async {
    if (_useMock) {
      final key = '${numero}_${modalidad.tag}';
      return (_mockTirajes[key] ?? 0) < 2;
    }
    // TODO: conectar endpoint inline cuando backend entregue contrato.
    return true;
  }

  @override
  Future<RegistrarApuestaResponse> registrarApuesta(
      RegistrarApuestaRequest request) async {
    if (_useMock) return _mockRegistrarApuesta(request);
    try {
      final res = await dio.post(
        '/api/dominguero/registrar-apuesta',
        data: request.toJson(),
      );
      return RegistrarApuestaResponse.fromJson(
          res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  static ApiException _mapDio(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException.timeout();
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException.network();
    }
    if (e.response != null) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] as String? : null;
      final code = data is Map ? data['code'] as String? : null;
      return ApiException(
        message: msg ?? 'Error del servidor.',
        statusCode: e.response?.statusCode,
        code: code,
      );
    }
    return ApiException.unknown();
  }

  // ── Mock ──────────────────────────────────────────────────────────────────
  // Simula el comportamiento del backend: estado de tirajes persiste en sesión.
  // El mapa _mockTirajes es estático para simular concurrencia entre pantallas.
  // ELIMINAR cuando el contrato de API del backend esté disponible.

  // TEMPORAL_MOCK: números con ambos tirajes ocupados para pruebas del estado de error.
  // Formato de clave: '${numero}_${modalidad.tag}'  — igual que verificarTiraje.
  // Eliminar/reemplazar cuando el backend entregue contratos de API.
  static final _mockTirajes = <String, int>{
    '111_3C': 2,    // 3 Cifras, 111 → agotado (E3)
    '1111_4C': 2,   // 4 Cifras, 1111 → agotado (E3)
  };

  static Future<VerificarTirajeResponse> _mockVerificarTiraje(
      VerificarTirajeRequest req) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final key = '${req.numero}_${req.modalidad.tag}';
    final tomados = _mockTirajes[key] ?? 0;
    return VerificarTirajeResponse(
      numero: req.numero,
      modalidad: req.modalidad.tag,
      disponible: tomados < 2,
      tirajeSiguiente: tomados < 2 ? tomados + 1 : 0,
      tirajesTomados: tomados,
    );
  }

  static Future<RegistrarApuestaResponse> _mockRegistrarApuesta(
      RegistrarApuestaRequest req) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final key = '${req.numero}_${req.modalidad.tag}';
    final tomados = _mockTirajes[key] ?? 0;
    if (tomados >= 2) {
      throw const ApiException(
        message:
            'Este número ya no está disponible en el ciclo actual. Por favor elige otro número',
        code: 'TIRAJE_AGOTADO',
      );
    }
    _mockTirajes[key] = tomados + 1;
    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return RegistrarApuestaResponse(
      betId: 'DOM-${now.millisecondsSinceEpoch}',
      numero: req.numero,
      modalidad: req.modalidad.tag,
      tiraje: tomados + 1,
      fechaRegistro:
          '${p(now.day)}/${p(now.month)}/${now.year} ${p(now.hour)}:${p(now.minute)}',
      fechaSorteo:
          '${p(req.fechaSorteo.day)}/${p(req.fechaSorteo.month)}/${req.fechaSorteo.year}',
      valorApuesta: 2000,
      premio: req.modalidad.premio,
    );
  }
}

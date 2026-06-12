import 'package:dio/dio.dart';
import '../../../../core/network/api_exception.dart';
import '../models/chance_millonario_models.dart';

// BLOQUEO: No existe contrato de API del backend para el módulo Chance
// Millonario. Endpoints esperados (pendiente documentación oficial del
// equipo backend de SERVIRED — el frontend NUNCA llama a Codesa/SuperFlex
// directamente, según lineamientos de conexión):
//   GET  <API_BASE_URL>/api/chance-millonario/info
//   GET  <API_BASE_URL>/api/chance-millonario/loterias-del-dia
//   POST <API_BASE_URL>/api/chance-millonario/registrar-apuesta
// Para activar llamadas reales: compilar con --dart-define=USE_MOCK=false
// una vez que el backend entregue los contratos y el ambiente esté disponible.

abstract class ChanceMillonarioRemoteDataSource {
  Future<InfoJuegoResponse> getInfoJuego();
  Future<List<LoteriaDelDiaModel>> getLoteriasDelDia();
  Future<RegistrarApuestaCmResponse> registrarApuesta(
      RegistrarApuestaCmRequest request);
}

class ChanceMillonarioRemoteDataSourceImpl
    implements ChanceMillonarioRemoteDataSource {
  const ChanceMillonarioRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  // defaultValue: true — mock activo por defecto hasta que exista contrato de API.
  static const bool _useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: true);

  @override
  Future<InfoJuegoResponse> getInfoJuego() async {
    if (_useMock) return _mockInfoJuego();
    try {
      final res = await dio.get('/api/chance-millonario/info');
      return InfoJuegoResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<List<LoteriaDelDiaModel>> getLoteriasDelDia() async {
    if (_useMock) return _mockLoteriasDelDia();
    try {
      final res = await dio.get('/api/chance-millonario/loterias-del-dia');
      final list = res.data as List;
      return list
          .map((e) => LoteriaDelDiaModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  @override
  Future<RegistrarApuestaCmResponse> registrarApuesta(
      RegistrarApuestaCmRequest request) async {
    if (_useMock) return _mockRegistrarApuesta(request);
    try {
      final res = await dio.post(
        '/api/chance-millonario/registrar-apuesta',
        data: request.toJson(),
      );
      return RegistrarApuestaCmResponse.fromJson(
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
  // Simula el comportamiento esperado del backend de SERVIRED.
  // ELIMINAR cuando el contrato de API del backend esté disponible.

  // HU-CM001 RN-5: acumulado mínimo de arranque $1.000 millones.
  // Los porcentajes de incremento diario están pendientes de definición por
  // el área de producto, por lo que el mock retorna el valor mínimo.
  static const int _mockAcumulado = 1000000000;
  static const int _mockValorApuesta = 6000;

  // TEMPORAL_MOCK: saldo simulado del usuario para probar E4
  // (saldo insuficiente). Se descuenta solo cuando el registro es exitoso,
  // igual que hará el backend. Con $30.000 alcanzan 5 apuestas de $6.000.
  static int _mockSaldo = 30000;

  // Catálogo de loterías/sorteos del día — mismo orden del Figma 1095:14179
  // y 1095:14187 (fila 1 y fila 2).
  static const _mockLoterias = <({String id, String nombre})>[
    (id: 'risaralda', nombre: 'Lotería del Risaralda'),
    (id: 'meta', nombre: 'Lotería del Meta'),
    (id: 'quindio', nombre: 'Lotería del Quindío'),
    (id: 'cauca', nombre: 'Lotería del Cauca'),
    (id: 'medellin', nombre: 'Lotería de Medellín'),
    (id: 'extra-medellin', nombre: 'Extra Lotería de Medellín'),
    (id: 'manizales', nombre: 'Lotería de Manizales'),
    (id: 'cundinamarca', nombre: 'Lotería de Cundinamarca'),
    (id: 'boyaca', nombre: 'Lotería de Boyacá'),
    (id: 'bogota', nombre: 'Lotería de Bogotá'),
    (id: 'valle', nombre: 'Lotería del Valle'),
    (id: 'tolima', nombre: 'Lotería del Tolima'),
    (id: 'huila', nombre: 'Lotería del Huila'),
    (id: 'santander', nombre: 'Lotería de Santander'),
  ];

  static Future<InfoJuegoResponse> _mockInfoJuego() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    // E7: cambiar a disponible: false para probar el estado
    // "juego no disponible para la fecha o región actual".
    return const InfoJuegoResponse(
      disponible: true,
      acumulado: _mockAcumulado,
      valorApuesta: _mockValorApuesta,
    );
  }

  static Future<List<LoteriaDelDiaModel>> _mockLoteriasDelDia() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // A4: retornar lista vacía para probar "no hay sorteos disponibles".
    return _mockLoterias
        .map((l) => LoteriaDelDiaModel(id: l.id, nombre: l.nombre))
        .toList();
  }

  static Future<RegistrarApuestaCmResponse> _mockRegistrarApuesta(
      RegistrarApuestaCmRequest req) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));

    // E4: saldo insuficiente — no se descuenta ningún valor.
    if (_mockSaldo < _mockValorApuesta) {
      throw const ApiException(
        message: 'Saldo insuficiente para realizar la apuesta',
        code: 'SALDO_INSUFICIENTE',
      );
    }

    LoteriaDelDiaModel byId(String id) {
      final l = _mockLoterias.firstWhere(
        (e) => e.id == id,
        orElse: () => throw const ApiException(
          message:
              'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día',
          code: 'LOTERIA_INVALIDA',
        ),
      );
      return LoteriaDelDiaModel(id: l.id, nombre: l.nombre);
    }

    // Postcondición HU-CM001: el saldo se descuenta solo si el registro
    // fue exitoso.
    _mockSaldo -= _mockValorApuesta;

    final now = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return RegistrarApuestaCmResponse(
      betId: 'CM-${now.millisecondsSinceEpoch}',
      numeros: req.numeros,
      loteria1: byId(req.loteria1Id),
      loteria2: byId(req.loteria2Id),
      valorApuesta: _mockValorApuesta,
      fechaRegistro:
          '${p(now.day)}/${p(now.month)}/${now.year} ${p(now.hour)}:${p(now.minute)}',
      acumuladoVigente: _mockAcumulado,
    );
  }
}

import '../../domain/entities/chance_millonario_entities.dart';

class LoteriaDelDiaModel {
  const LoteriaDelDiaModel({required this.id, required this.nombre});

  final String id;
  final String nombre;

  factory LoteriaDelDiaModel.fromJson(Map<String, dynamic> json) =>
      LoteriaDelDiaModel(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
      );

  LoteriaDelDia toEntity() => LoteriaDelDia(id: id, nombre: nombre);
}

class InfoJuegoResponse {
  const InfoJuegoResponse({
    required this.disponible,
    required this.acumulado,
    required this.valorApuesta,
  });

  final bool disponible;
  final int acumulado;
  final int valorApuesta;

  factory InfoJuegoResponse.fromJson(Map<String, dynamic> json) =>
      InfoJuegoResponse(
        disponible: json['disponible'] as bool,
        acumulado: json['acumulado'] as int,
        valorApuesta: json['valorApuesta'] as int,
      );

  ChanceMillonarioInfo toEntity() => ChanceMillonarioInfo(
        disponible: disponible,
        acumulado: acumulado,
        valorApuesta: valorApuesta,
      );
}

class RegistrarApuestaCmRequest {
  const RegistrarApuestaCmRequest({
    required this.numeros,
    required this.loteria1Id,
    required this.loteria2Id,
  });

  final List<String> numeros;
  final String loteria1Id;
  final String loteria2Id;

  Map<String, dynamic> toJson() => {
        'numeros': numeros,
        'loteria1Id': loteria1Id,
        'loteria2Id': loteria2Id,
      };
}

class RegistrarApuestaCmResponse {
  const RegistrarApuestaCmResponse({
    required this.betId,
    required this.numeros,
    required this.loteria1,
    required this.loteria2,
    required this.valorApuesta,
    required this.fechaRegistro,
    required this.acumuladoVigente,
  });

  final String betId;
  final List<String> numeros;
  final LoteriaDelDiaModel loteria1;
  final LoteriaDelDiaModel loteria2;
  final int valorApuesta;
  final String fechaRegistro; // dd/MM/yyyy HH:mm (lineamientos de conexión)
  final int acumuladoVigente;

  factory RegistrarApuestaCmResponse.fromJson(Map<String, dynamic> json) =>
      RegistrarApuestaCmResponse(
        betId: json['betId'] as String,
        numeros: (json['numeros'] as List).cast<String>(),
        loteria1: LoteriaDelDiaModel.fromJson(
            json['loteria1'] as Map<String, dynamic>),
        loteria2: LoteriaDelDiaModel.fromJson(
            json['loteria2'] as Map<String, dynamic>),
        valorApuesta: json['valorApuesta'] as int,
        fechaRegistro: json['fechaRegistro'] as String,
        acumuladoVigente: json['acumuladoVigente'] as int,
      );

  ChanceMillonarioBetResult toEntity() => ChanceMillonarioBetResult(
        betId: betId,
        numeros: numeros,
        loteria1: loteria1.toEntity(),
        loteria2: loteria2.toEntity(),
        valorApuesta: valorApuesta,
        fechaRegistro: _parseDate(fechaRegistro),
        acumuladoVigente: acumuladoVigente,
      );

  // Acepta "dd/MM/yyyy HH:mm" o "dd/MM/yyyy" o ISO 8601
  static DateTime _parseDate(String s) {
    final parts = s.split('/');
    if (parts.length == 3) {
      final rest = parts[2].split(' ');
      var hour = 0;
      var minute = 0;
      if (rest.length > 1) {
        final hm = rest[1].split(':');
        hour = int.parse(hm[0]);
        minute = int.parse(hm[1]);
      }
      return DateTime(
        int.parse(rest[0]),
        int.parse(parts[1]),
        int.parse(parts[0]),
        hour,
        minute,
      );
    }
    return DateTime.parse(s);
  }
}

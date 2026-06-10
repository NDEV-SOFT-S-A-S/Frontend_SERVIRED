import '../../domain/entities/dominguero_entities.dart';

class VerificarTirajeRequest {
  const VerificarTirajeRequest({required this.numero, required this.modalidad});

  final String numero;
  final ModalidadDominguero modalidad;

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'modalidad': modalidad.tag,
      };
}

class VerificarTirajeResponse {
  const VerificarTirajeResponse({
    required this.numero,
    required this.modalidad,
    required this.disponible,
    required this.tirajeSiguiente,
    required this.tirajesTomados,
  });

  final String numero;
  final String modalidad;
  final bool disponible;
  final int tirajeSiguiente;
  final int tirajesTomados;

  factory VerificarTirajeResponse.fromJson(Map<String, dynamic> json) =>
      VerificarTirajeResponse(
        numero: json['numero'] as String,
        modalidad: json['modalidad'] as String,
        disponible: json['disponible'] as bool,
        tirajeSiguiente: json['tirajeSiguiente'] as int,
        tirajesTomados: json['tirajesTomados'] as int,
      );

  TirajeDisponibilidad toEntity(ModalidadDominguero mod) => TirajeDisponibilidad(
        numero: numero,
        modalidad: mod,
        disponible: disponible,
        tirajeSiguiente: tirajeSiguiente,
        tirajesTomados: tirajesTomados,
      );
}

class RegistrarApuestaRequest {
  const RegistrarApuestaRequest({
    required this.numero,
    required this.modalidad,
    required this.fechaSorteo,
  });

  final String numero;
  final ModalidadDominguero modalidad;
  final DateTime fechaSorteo;

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'modalidad': modalidad.tag,
        'fechaSorteo': _fmtDate(fechaSorteo),
      };

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class RegistrarApuestaResponse {
  const RegistrarApuestaResponse({
    required this.betId,
    required this.numero,
    required this.modalidad,
    required this.tiraje,
    required this.fechaRegistro,
    required this.fechaSorteo,
    required this.valorApuesta,
    required this.premio,
  });

  final String betId;
  final String numero;
  final String modalidad;
  final int tiraje;
  final String fechaRegistro;
  final String fechaSorteo;
  final int valorApuesta;
  final int premio;

  factory RegistrarApuestaResponse.fromJson(Map<String, dynamic> json) =>
      RegistrarApuestaResponse(
        betId: json['betId'] as String,
        numero: json['numero'] as String,
        modalidad: json['modalidad'] as String,
        tiraje: json['tiraje'] as int,
        fechaRegistro: json['fechaRegistro'] as String,
        fechaSorteo: json['fechaSorteo'] as String,
        valorApuesta: json['valorApuesta'] as int,
        premio: json['premio'] as int,
      );

  DomingueroBetResult toEntity(ModalidadDominguero mod) => DomingueroBetResult(
        betId: betId,
        numero: numero,
        modalidad: mod,
        tiraje: tiraje,
        fechaRegistro: _parseDate(fechaRegistro),
        fechaSorteo: _parseDate(fechaSorteo),
        valorApuesta: valorApuesta,
        premio: premio,
      );

  // Acepta "dd/MM/yyyy HH:mm" o "dd/MM/yyyy" o ISO 8601
  static DateTime _parseDate(String s) {
    final parts = s.split('/');
    if (parts.length == 3) {
      final dayPart = parts[0];
      final monthPart = parts[1];
      final rest = parts[2].split(' ');
      return DateTime(
        int.parse(rest[0]),
        int.parse(monthPart),
        int.parse(dayPart),
      );
    }
    return DateTime.parse(s);
  }
}

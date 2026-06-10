import 'package:equatable/equatable.dart';

enum ModalidadDominguero { tresC, cuatroC }

extension ModalidadDomingueroX on ModalidadDominguero {
  int get digits => this == ModalidadDominguero.tresC ? 3 : 4;
  int get premio => this == ModalidadDominguero.tresC ? 1000000 : 8000000;
  String get label => this == ModalidadDominguero.tresC ? '3 Cifras' : '4 Cifras';
  String get tag => this == ModalidadDominguero.tresC ? '3C' : '4C';
  // HU: Dominguero 3C = +49% vs chance tradicional; 4C = +32%
  String get napaText => this == ModalidadDominguero.tresC
      ? 'Tienes una ñapa de 49%'
      : 'Tienes una ñapa de 32%';
}

class TirajeDisponibilidad extends Equatable {
  const TirajeDisponibilidad({
    required this.numero,
    required this.modalidad,
    required this.disponible,
    required this.tirajeSiguiente,
    required this.tirajesTomados,
  });

  final String numero;
  final ModalidadDominguero modalidad;
  final bool disponible;
  final int tirajeSiguiente; // 1 o 2 (solo válido cuando disponible == true)
  final int tirajesTomados;  // 0, 1 o 2

  @override
  List<Object?> get props =>
      [numero, modalidad, disponible, tirajeSiguiente, tirajesTomados];
}

class DomingueroBetResult extends Equatable {
  const DomingueroBetResult({
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
  final ModalidadDominguero modalidad;
  final int tiraje;           // 1 o 2
  final DateTime fechaRegistro;
  final DateTime fechaSorteo;
  final int valorApuesta;     // siempre 2000
  final int premio;           // 1000000 o 8000000

  @override
  List<Object?> get props =>
      [betId, numero, modalidad, tiraje, fechaRegistro, fechaSorteo, valorApuesta, premio];
}

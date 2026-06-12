import 'package:equatable/equatable.dart';

// HU-CM001: Chance Millonario — modalidad paramutual de doble acierto de
// 4 cifras. 5 números, 2 loterías diferentes del día, $6.000 por apuesta.

/// Lotería o sorteo autorizado disponible para el día de la apuesta.
/// El catálogo se carga dinámicamente según la fecha (HU-CM001 nota funcional).
class LoteriaDelDia extends Equatable {
  const LoteriaDelDia({required this.id, required this.nombre});

  final String id;
  final String nombre;

  @override
  List<Object?> get props => [id, nombre];
}

/// Información del juego para el día: disponibilidad (E7) y acumulado vigente.
/// El acumulado mínimo de arranque es $1.000 millones (HU-CM001 RN-5).
class ChanceMillonarioInfo extends Equatable {
  const ChanceMillonarioInfo({
    required this.disponible,
    required this.acumulado,
    required this.valorApuesta,
  });

  final bool disponible;
  final int acumulado;
  final int valorApuesta; // $6.000 fijo (HU-CM001 RN-1)

  @override
  List<Object?> get props => [disponible, acumulado, valorApuesta];
}

/// Comprobante de la apuesta registrada (HU-CM001 postcondición:
/// la apuesta queda registrada solo cuando el pago es confirmado y se
/// genera el comprobante).
class ChanceMillonarioBetResult extends Equatable {
  const ChanceMillonarioBetResult({
    required this.betId,
    required this.numeros,
    required this.loteria1,
    required this.loteria2,
    required this.valorApuesta,
    required this.fechaRegistro,
    required this.acumuladoVigente,
  });

  final String betId;
  final List<String> numeros; // 5 números de 4 cifras, ceros a la izquierda
  final LoteriaDelDia loteria1;
  final LoteriaDelDia loteria2;
  final int valorApuesta;
  final DateTime fechaRegistro;
  final int acumuladoVigente;

  @override
  List<Object?> get props => [
        betId,
        numeros,
        loteria1,
        loteria2,
        valorApuesta,
        fechaRegistro,
        acumuladoVigente,
      ];
}

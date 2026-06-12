import 'package:equatable/equatable.dart';
import '../../domain/entities/chance_millonario_entities.dart';

enum ChanceMillonarioStatus {
  initial,
  cargando, // Cargando info del juego y catálogo de loterías
  cargado, // Formulario listo para apostar
  sinLoterias, // A4: no hay loterías/sorteos disponibles para el día
  noDisponible, // E7: juego no disponible para la fecha o región actual
  errorCarga, // E5: error cargando el catálogo de loterías
  registrando, // Registrando y pagando la apuesta en backend
  exito, // Apuesta registrada — comprobante generado
  errorRegistro, // E4/E6: error al registrar (saldo insuficiente u otro)
}

class ChanceMillonarioState extends Equatable {
  const ChanceMillonarioState({
    this.status = ChanceMillonarioStatus.initial,
    this.info,
    this.loterias = const [],
    this.resultado,
    this.errorMessage,
  });

  final ChanceMillonarioStatus status;
  final ChanceMillonarioInfo? info;
  final List<LoteriaDelDia> loterias;
  final ChanceMillonarioBetResult? resultado;
  final String? errorMessage;

  ChanceMillonarioState copyWith({
    ChanceMillonarioStatus? status,
    ChanceMillonarioInfo? info,
    List<LoteriaDelDia>? loterias,
    ChanceMillonarioBetResult? resultado,
    String? errorMessage,
    bool clearError = false,
    bool clearResultado = false,
  }) {
    return ChanceMillonarioState(
      status: status ?? this.status,
      info: info ?? this.info,
      loterias: loterias ?? this.loterias,
      resultado: clearResultado ? null : (resultado ?? this.resultado),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, info, loterias, resultado, errorMessage];
}

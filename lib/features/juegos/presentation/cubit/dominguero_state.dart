import 'package:equatable/equatable.dart';
import '../../domain/entities/dominguero_entities.dart';

enum DomingueroStatus {
  initial,
  verificando,   // Consultando disponibilidad de tiraje al backend
  resumenListo,  // Tirajes verificados — esperando confirmación del usuario
  registrando,   // Registrando apuesta(s) en backend
  exito,         // Apuesta(s) registradas exitosamente
  error,
}

class DomingueroLineaVerificada extends Equatable {
  const DomingueroLineaVerificada({
    required this.numero,
    required this.modalidad,
    required this.tiraje,
  });

  final String numero;
  final ModalidadDominguero modalidad;
  final int tiraje; // 1 o 2

  @override
  List<Object?> get props => [numero, modalidad, tiraje];
}

class DomingueroState extends Equatable {
  const DomingueroState({
    this.status = DomingueroStatus.initial,
    this.lineasVerificadas = const [],
    this.resultados = const [],
    this.errorMessage,
    this.errorNumero,
    this.numeroBloqueadoInline,
  });

  final DomingueroStatus status;
  final List<DomingueroLineaVerificada> lineasVerificadas;
  final List<DomingueroBetResult> resultados;
  final String? errorMessage;
  final String? errorNumero; // número específico que causó el error al confirmar

  // Inline check: número actualmente en el input que está agotado (E3 preview).
  // Se limpia al cambiar modalidad, limpiar el campo o ingresar un número disponible.
  final String? numeroBloqueadoInline;

  DomingueroState copyWith({
    DomingueroStatus? status,
    List<DomingueroLineaVerificada>? lineasVerificadas,
    List<DomingueroBetResult>? resultados,
    String? errorMessage,
    String? errorNumero,
    String? numeroBloqueadoInline,
    bool clearError = false,
    bool clearInlineError = false,
  }) {
    return DomingueroState(
      status: status ?? this.status,
      lineasVerificadas: lineasVerificadas ?? this.lineasVerificadas,
      resultados: resultados ?? this.resultados,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorNumero: clearError ? null : (errorNumero ?? this.errorNumero),
      numeroBloqueadoInline: clearInlineError
          ? null
          : (numeroBloqueadoInline ?? this.numeroBloqueadoInline),
    );
  }

  @override
  List<Object?> get props => [
        status,
        lineasVerificadas,
        resultados,
        errorMessage,
        errorNumero,
        numeroBloqueadoInline,
      ];
}

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/dominguero_entities.dart';
import '../../domain/usecases/verificar_tiraje_dominguero_usecase.dart';
import '../../domain/usecases/registrar_apuesta_dominguero_usecase.dart';
import '../../domain/usecases/check_disponibilidad_inline_dominguero_usecase.dart';
import 'dominguero_state.dart';

class DomingueroCubit extends Cubit<DomingueroState> {
  DomingueroCubit({
    required VerificarTirajeDomingueroUseCase verificarTirajeUseCase,
    required RegistrarApuestaDomingueroUseCase registrarApuestaUseCase,
    required CheckDisponibilidadInlineDomingueroUseCase checkInlineUseCase,
  })  : _verificar = verificarTirajeUseCase,
        _registrar = registrarApuestaUseCase,
        _checkInline = checkInlineUseCase,
        super(const DomingueroState());

  final VerificarTirajeDomingueroUseCase _verificar;
  final RegistrarApuestaDomingueroUseCase _registrar;
  final CheckDisponibilidadInlineDomingueroUseCase _checkInline;

  // Verifica disponibilidad de tiraje para cada línea contra el backend.
  // Per HU: la validación debe hacerse en tiempo real al confirmar, no al ingresar el número.
  Future<void> verificarLineas(
    List<({String numero, ModalidadDominguero modalidad})> lineas,
  ) async {
    if (lineas.isEmpty) return;
    emit(state.copyWith(
      status: DomingueroStatus.verificando,
      clearError: true,
    ));
    try {
      final verificadas = <DomingueroLineaVerificada>[];
      for (final linea in lineas) {
        final result = await _verificar(
          numero: linea.numero,
          modalidad: linea.modalidad,
        );
        if (!result.disponible) {
          // E3: ambos tirajes del número están agotados
          emit(state.copyWith(
            status: DomingueroStatus.error,
            errorMessage:
                'Este número ya no está disponible en el ciclo actual. Por favor elige otro número',
            errorNumero: linea.numero,
          ));
          return;
        }
        verificadas.add(DomingueroLineaVerificada(
          numero: linea.numero,
          modalidad: linea.modalidad,
          tiraje: result.tirajeSiguiente,
        ));
      }
      emit(state.copyWith(
        status: DomingueroStatus.resumenListo,
        lineasVerificadas: verificadas,
        clearError: true,
      ));
    } catch (e) {
      // E6: error al consultar disponibilidad del tiraje
      final msg = e is ApiException
          ? e.message
          : 'No fue posible verificar la disponibilidad del número. Intente nuevamente';
      emit(state.copyWith(
        status: DomingueroStatus.error,
        errorMessage: msg,
      ));
    }
  }

  // Registra todas las apuestas verificadas.
  // Per HU: el tiraje solo queda ocupado si el registro es confirmado exitosamente.
  // No descuenta saldo ni ocupa tiraje si el registro falla.
  Future<void> registrarApuestas(DateTime fechaSorteo) async {
    if (state.lineasVerificadas.isEmpty) return;
    emit(state.copyWith(status: DomingueroStatus.registrando));
    try {
      final resultados = <DomingueroBetResult>[];
      for (final linea in state.lineasVerificadas) {
        final result = await _registrar(
          numero: linea.numero,
          modalidad: linea.modalidad,
          fechaSorteo: fechaSorteo,
        );
        resultados.add(result);
      }
      emit(state.copyWith(
        status: DomingueroStatus.exito,
        resultados: resultados,
        clearError: true,
      ));
    } catch (e) {
      // E7: error al registrar la apuesta
      final msg = e is ApiException
          ? e.message
          : 'No se pudo registrar la apuesta. Intente nuevamente';
      emit(state.copyWith(
        status: DomingueroStatus.error,
        errorMessage: msg,
      ));
    }
  }

  // Inline pre-validación del número actual en el input (sin bloquear tiraje).
  // Se llama en onChanged cuando el texto alcanza la longitud correcta.
  // No modifica status; solo actualiza numeroBloqueadoInline.
  //
  // [usosLocales]: cuántas veces aparece ya este numero+modalidad en las líneas
  // agregadas por el usuario en la sesión actual.
  // TEMPORAL_MOCK: la regla de máximo 2 usos viene del backend en producción.
  // Reemplazar cuando exista contrato de API real.
  Future<void> checkInline(
    String numero,
    ModalidadDominguero modalidad, {
    int usosLocales = 0,
  }) async {
    // Regla de negocio: un número puede jugarse máximo 2 veces por ciclo.
    // Si el usuario ya lo agregó 2 veces en esta sesión, es el 3er intento.
    if (usosLocales >= 2) {
      emit(state.copyWith(numeroBloqueadoInline: numero));
      return;
    }
    final disponible =
        await _checkInline(numero: numero, modalidad: modalidad);
    if (disponible) {
      emit(state.copyWith(clearInlineError: true));
    } else {
      emit(state.copyWith(numeroBloqueadoInline: numero));
    }
  }

  // Limpia el error inline (cambio de modalidad, campo borrado, número corregido).
  void clearInline() {
    if (state.numeroBloqueadoInline != null) {
      emit(state.copyWith(clearInlineError: true));
    }
  }

  void reset() => emit(const DomingueroState());
}

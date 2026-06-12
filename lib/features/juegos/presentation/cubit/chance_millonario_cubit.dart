import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/usecases/get_info_chance_millonario_usecase.dart';
import '../../domain/usecases/get_loterias_chance_millonario_usecase.dart';
import '../../domain/usecases/registrar_apuesta_chance_millonario_usecase.dart';
import 'chance_millonario_state.dart';

class ChanceMillonarioCubit extends Cubit<ChanceMillonarioState> {
  ChanceMillonarioCubit({
    required GetInfoChanceMillonarioUseCase getInfoUseCase,
    required GetLoteriasChanceMillonarioUseCase getLoteriasUseCase,
    required RegistrarApuestaChanceMillonarioUseCase registrarApuestaUseCase,
  })  : _getInfo = getInfoUseCase,
        _getLoterias = getLoteriasUseCase,
        _registrar = registrarApuestaUseCase,
        super(const ChanceMillonarioState());

  final GetInfoChanceMillonarioUseCase _getInfo;
  final GetLoteriasChanceMillonarioUseCase _getLoterias;
  final RegistrarApuestaChanceMillonarioUseCase _registrar;

  /// Carga la info del juego (disponibilidad + acumulado vigente) y el
  /// catálogo de loterías del día (HU-CM001 flujo normal pasos 2 y 6).
  Future<void> loadJuego() async {
    emit(state.copyWith(
      status: ChanceMillonarioStatus.cargando,
      clearError: true,
      clearResultado: true,
    ));
    try {
      final info = await _getInfo();

      // E7: juego no disponible para la fecha o región del usuario.
      if (!info.disponible) {
        emit(state.copyWith(
          status: ChanceMillonarioStatus.noDisponible,
          info: info,
          errorMessage:
              'Chance Millonario no está disponible para la fecha o región actual',
        ));
        return;
      }

      final loterias = await _getLoterias();

      // A4: no hay loterías o sorteos disponibles para el día.
      if (loterias.isEmpty) {
        emit(state.copyWith(
          status: ChanceMillonarioStatus.sinLoterias,
          info: info,
          loterias: const [],
        ));
        return;
      }

      emit(state.copyWith(
        status: ChanceMillonarioStatus.cargado,
        info: info,
        loterias: loterias,
        clearError: true,
      ));
    } catch (_) {
      // E5: error en el servicio de carga de loterías disponibles.
      // Mensaje fijo de la HU; no se exponen detalles técnicos (SPEC-FE-001 §12).
      emit(state.copyWith(
        status: ChanceMillonarioStatus.errorCarga,
        errorMessage:
            'No fue posible cargar las loterías disponibles. Intente nuevamente más tarde',
      ));
    }
  }

  /// Registra y paga la apuesta. La apuesta solo queda registrada si el
  /// pago se confirma; el saldo solo se descuenta si el registro fue
  /// exitoso (HU-CM001 postcondiciones — garantizado por backend/mock).
  Future<void> registrarApuesta({
    required List<String> numeros,
    required String loteria1Id,
    required String loteria2Id,
  }) async {
    emit(state.copyWith(
      status: ChanceMillonarioStatus.registrando,
      clearError: true,
    ));
    try {
      final resultado = await _registrar(
        numeros: numeros,
        loteria1Id: loteria1Id,
        loteria2Id: loteria2Id,
      );
      emit(state.copyWith(
        status: ChanceMillonarioStatus.exito,
        resultado: resultado,
        clearError: true,
      ));
    } catch (e) {
      // E4: saldo insuficiente — mensaje exacto de la HU.
      // E6: error al registrar — mensaje exacto de la HU.
      final msg = (e is ApiException && e.code == 'SALDO_INSUFICIENTE')
          ? 'Saldo insuficiente para realizar la apuesta'
          : 'No se pudo registrar la apuesta. Intente nuevamente';
      emit(state.copyWith(
        status: ChanceMillonarioStatus.errorRegistro,
        errorMessage: msg,
      ));
    }
  }

  /// Vuelve al formulario tras un error de registro, conservando
  /// loterías e info ya cargadas.
  void dismissRegistroError() {
    if (state.status == ChanceMillonarioStatus.errorRegistro) {
      emit(state.copyWith(
        status: ChanceMillonarioStatus.cargado,
        clearError: true,
      ));
    }
  }

  /// Inicia una nueva apuesta tras un registro exitoso (A3 — el formulario
  /// vuelve a quedar editable), sin recargar el catálogo.
  void nuevaApuesta() {
    emit(state.copyWith(
      status: ChanceMillonarioStatus.cargado,
      clearError: true,
      clearResultado: true,
    ));
  }
}

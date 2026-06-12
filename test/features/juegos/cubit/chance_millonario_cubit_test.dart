import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:servired_app/core/network/api_exception.dart';
import 'package:servired_app/features/juegos/domain/entities/chance_millonario_entities.dart';
import 'package:servired_app/features/juegos/domain/usecases/get_info_chance_millonario_usecase.dart';
import 'package:servired_app/features/juegos/domain/usecases/get_loterias_chance_millonario_usecase.dart';
import 'package:servired_app/features/juegos/domain/usecases/registrar_apuesta_chance_millonario_usecase.dart';
import 'package:servired_app/features/juegos/presentation/cubit/chance_millonario_cubit.dart';
import 'package:servired_app/features/juegos/presentation/cubit/chance_millonario_state.dart';

class MockGetInfoUseCase extends Mock
    implements GetInfoChanceMillonarioUseCase {}

class MockGetLoteriasUseCase extends Mock
    implements GetLoteriasChanceMillonarioUseCase {}

class MockRegistrarApuestaUseCase extends Mock
    implements RegistrarApuestaChanceMillonarioUseCase {}

const _info = ChanceMillonarioInfo(
  disponible: true,
  acumulado: 1000000000,
  valorApuesta: 6000,
);

const _infoNoDisponible = ChanceMillonarioInfo(
  disponible: false,
  acumulado: 1000000000,
  valorApuesta: 6000,
);

const _loterias = [
  LoteriaDelDia(id: 'bogota', nombre: 'Lotería de Bogotá'),
  LoteriaDelDia(id: 'medellin', nombre: 'Lotería de Medellín'),
];

const _numeros = ['1234', '0000', '9999', '0042', '5555'];

final _resultado = ChanceMillonarioBetResult(
  betId: 'CM-1',
  numeros: _numeros,
  loteria1: _loterias[0],
  loteria2: _loterias[1],
  valorApuesta: 6000,
  fechaRegistro: DateTime(2026, 6, 11, 10, 30),
  acumuladoVigente: 1000000000,
);

void main() {
  late MockGetInfoUseCase getInfo;
  late MockGetLoteriasUseCase getLoterias;
  late MockRegistrarApuestaUseCase registrar;

  setUp(() {
    getInfo = MockGetInfoUseCase();
    getLoterias = MockGetLoteriasUseCase();
    registrar = MockRegistrarApuestaUseCase();
  });

  ChanceMillonarioCubit buildCubit() => ChanceMillonarioCubit(
        getInfoUseCase: getInfo,
        getLoteriasUseCase: getLoterias,
        registrarApuestaUseCase: registrar,
      );

  group('ChanceMillonarioCubit - loadJuego', () {
    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite [cargando, cargado] con info y loterías cuando la carga es exitosa',
      build: buildCubit,
      act: (cubit) {
        when(() => getInfo()).thenAnswer((_) async => _info);
        when(() => getLoterias()).thenAnswer((_) async => _loterias);
        cubit.loadJuego();
      },
      expect: () => [
        const ChanceMillonarioState(status: ChanceMillonarioStatus.cargando),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.cargado,
          info: _info,
          loterias: _loterias,
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite noDisponible cuando el juego no está habilitado (E7)',
      build: buildCubit,
      act: (cubit) {
        when(() => getInfo()).thenAnswer((_) async => _infoNoDisponible);
        cubit.loadJuego();
      },
      expect: () => [
        const ChanceMillonarioState(status: ChanceMillonarioStatus.cargando),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.noDisponible,
          info: _infoNoDisponible,
          errorMessage:
              'Chance Millonario no está disponible para la fecha o región actual',
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite sinLoterias cuando el catálogo del día está vacío (A4)',
      build: buildCubit,
      act: (cubit) {
        when(() => getInfo()).thenAnswer((_) async => _info);
        when(() => getLoterias()).thenAnswer((_) async => const []);
        cubit.loadJuego();
      },
      expect: () => [
        const ChanceMillonarioState(status: ChanceMillonarioStatus.cargando),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.sinLoterias,
          info: _info,
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite errorCarga con el mensaje exacto de la HU cuando falla el servicio (E5)',
      build: buildCubit,
      act: (cubit) {
        when(() => getInfo()).thenThrow(ApiException.network());
        cubit.loadJuego();
      },
      expect: () => [
        const ChanceMillonarioState(status: ChanceMillonarioStatus.cargando),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.errorCarga,
          errorMessage:
              'No fue posible cargar las loterías disponibles. Intente nuevamente más tarde',
        ),
      ],
    );
  });

  group('ChanceMillonarioCubit - registrarApuesta', () {
    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite [registrando, exito] con comprobante cuando el registro es exitoso',
      build: buildCubit,
      seed: () => const ChanceMillonarioState(
        status: ChanceMillonarioStatus.cargado,
        info: _info,
        loterias: _loterias,
      ),
      act: (cubit) {
        when(() => registrar(
              numeros: _numeros,
              loteria1Id: 'bogota',
              loteria2Id: 'medellin',
            )).thenAnswer((_) async => _resultado);
        cubit.registrarApuesta(
          numeros: _numeros,
          loteria1Id: 'bogota',
          loteria2Id: 'medellin',
        );
      },
      expect: () => [
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.registrando,
          info: _info,
          loterias: _loterias,
        ),
        ChanceMillonarioState(
          status: ChanceMillonarioStatus.exito,
          info: _info,
          loterias: _loterias,
          resultado: _resultado,
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite errorRegistro con mensaje de saldo insuficiente (E4)',
      build: buildCubit,
      seed: () => const ChanceMillonarioState(
        status: ChanceMillonarioStatus.cargado,
        info: _info,
        loterias: _loterias,
      ),
      act: (cubit) {
        when(() => registrar(
              numeros: _numeros,
              loteria1Id: 'bogota',
              loteria2Id: 'medellin',
            )).thenThrow(const ApiException(
          message: 'Saldo insuficiente para realizar la apuesta',
          code: 'SALDO_INSUFICIENTE',
        ));
        cubit.registrarApuesta(
          numeros: _numeros,
          loteria1Id: 'bogota',
          loteria2Id: 'medellin',
        );
      },
      expect: () => [
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.registrando,
          info: _info,
          loterias: _loterias,
        ),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.errorRegistro,
          info: _info,
          loterias: _loterias,
          errorMessage: 'Saldo insuficiente para realizar la apuesta',
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'emite errorRegistro con el mensaje exacto de la HU ante error genérico (E6)',
      build: buildCubit,
      seed: () => const ChanceMillonarioState(
        status: ChanceMillonarioStatus.cargado,
        info: _info,
        loterias: _loterias,
      ),
      act: (cubit) {
        when(() => registrar(
              numeros: _numeros,
              loteria1Id: 'bogota',
              loteria2Id: 'medellin',
            )).thenThrow(ApiException.timeout());
        cubit.registrarApuesta(
          numeros: _numeros,
          loteria1Id: 'bogota',
          loteria2Id: 'medellin',
        );
      },
      expect: () => [
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.registrando,
          info: _info,
          loterias: _loterias,
        ),
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.errorRegistro,
          info: _info,
          loterias: _loterias,
          errorMessage: 'No se pudo registrar la apuesta. Intente nuevamente',
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'dismissRegistroError vuelve a cargado conservando loterías e info',
      build: buildCubit,
      seed: () => const ChanceMillonarioState(
        status: ChanceMillonarioStatus.errorRegistro,
        info: _info,
        loterias: _loterias,
        errorMessage: 'Saldo insuficiente para realizar la apuesta',
      ),
      act: (cubit) => cubit.dismissRegistroError(),
      expect: () => [
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.cargado,
          info: _info,
          loterias: _loterias,
        ),
      ],
    );

    blocTest<ChanceMillonarioCubit, ChanceMillonarioState>(
      'nuevaApuesta limpia el comprobante y vuelve a cargado (A3)',
      build: buildCubit,
      seed: () => ChanceMillonarioState(
        status: ChanceMillonarioStatus.exito,
        info: _info,
        loterias: _loterias,
        resultado: _resultado,
      ),
      act: (cubit) => cubit.nuevaApuesta(),
      expect: () => [
        const ChanceMillonarioState(
          status: ChanceMillonarioStatus.cargado,
          info: _info,
          loterias: _loterias,
        ),
      ],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:servired_app/features/juegos/presentation/helpers/chance_millonario_validator.dart';

void main() {
  group('ChanceMillonarioValidator.validarNumero (HU-CM001 E1)', () {
    test('acepta número de exactamente 4 cifras', () {
      expect(ChanceMillonarioValidator.validarNumero('1234'), isNull);
    });

    test('acepta 0000 y conserva ceros a la izquierda', () {
      expect(ChanceMillonarioValidator.validarNumero('0000'), isNull);
      expect(ChanceMillonarioValidator.validarNumero('0042'), isNull);
    });

    test('acepta 9999 (límite superior)', () {
      expect(ChanceMillonarioValidator.validarNumero('9999'), isNull);
    });

    test('rechaza números con menos de 4 cifras', () {
      expect(
        ChanceMillonarioValidator.validarNumero('123'),
        'El número debe tener exactamente 4 cifras',
      );
    });

    test('rechaza números con más de 4 cifras', () {
      expect(
        ChanceMillonarioValidator.validarNumero('12345'),
        'El número debe tener exactamente 4 cifras',
      );
    });

    test('rechaza campo vacío', () {
      expect(
        ChanceMillonarioValidator.validarNumero(''),
        'El número debe tener exactamente 4 cifras',
      );
    });

    test('rechaza valores no numéricos', () {
      expect(
        ChanceMillonarioValidator.validarNumero('12a4'),
        'El número debe tener exactamente 4 cifras',
      );
    });
  });

  group('ChanceMillonarioValidator.validarNumeros (HU-CM001 E2)', () {
    test('acepta exactamente 5 números válidos', () {
      expect(
        ChanceMillonarioValidator.validarNumeros(
            ['1234', '0000', '9999', '0042', '5555']),
        isNull,
      );
    });

    test('rechaza menos de 5 números', () {
      expect(
        ChanceMillonarioValidator.validarNumeros(['1234', '5678']),
        'Debes ingresar exactamente 5 números de 4 cifras',
      );
    });

    test('rechaza 5 números si alguno está incompleto', () {
      expect(
        ChanceMillonarioValidator.validarNumeros(
            ['1234', '0000', '99', '0042', '5555']),
        'Debes ingresar exactamente 5 números de 4 cifras',
      );
    });

    test('rechaza más de 5 números', () {
      expect(
        ChanceMillonarioValidator.validarNumeros(
            ['1234', '0000', '9999', '0042', '5555', '7777']),
        'Debes ingresar exactamente 5 números de 4 cifras',
      );
    });
  });

  group('ChanceMillonarioValidator.validarLoterias (HU-CM001 E3)', () {
    test('acepta exactamente 2 loterías diferentes', () {
      expect(
        ChanceMillonarioValidator.validarLoterias({'bogota', 'medellin'}),
        isNull,
      );
    });

    test('rechaza menos de 2 loterías', () {
      expect(
        ChanceMillonarioValidator.validarLoterias({'bogota'}),
        'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día',
      );
    });

    test('rechaza selección vacía', () {
      expect(
        ChanceMillonarioValidator.validarLoterias({}),
        'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día',
      );
    });

    test('rechaza más de 2 loterías', () {
      expect(
        ChanceMillonarioValidator.validarLoterias(
            {'bogota', 'medellin', 'valle'}),
        'Debes seleccionar exactamente 2 loterías o sorteos diferentes del día',
      );
    });
  });
}

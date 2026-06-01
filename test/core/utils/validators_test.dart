import 'package:flutter_test/flutter_test.dart';
import 'package:servired_app/core/constants/document_type.dart';
import 'package:servired_app/core/utils/validators.dart';

void main() {
  group('Validators.documentNumber', () {
    test('Cédula vacía retorna error', () {
      expect(
        Validators.documentNumber('', DocumentType.cedulaCiudadania),
        isNotNull,
      );
    });

    test('Cédula válida no retorna error', () {
      expect(
        Validators.documentNumber('1234567890', DocumentType.cedulaCiudadania),
        isNull,
      );
    });

    test('Cédula con letras retorna error', () {
      expect(
        Validators.documentNumber('ABC123', DocumentType.cedulaCiudadania),
        isNotNull,
      );
    });
  });

  group('Validators.birthDate - HU-LOG001 edad mínima 18 años', () {
    test('Menor de 18 retorna error', () {
      final birthDate = DateTime.now().subtract(const Duration(days: 365 * 17));
      expect(Validators.birthDate(birthDate), isNotNull);
    });

    test('Mayor de 18 no retorna error', () {
      final birthDate = DateTime.now().subtract(const Duration(days: 365 * 20));
      expect(Validators.birthDate(birthDate), isNull);
    });

    test('Fecha nula retorna error', () {
      expect(Validators.birthDate(null), isNotNull);
    });
  });

  group('Validators.otp', () {
    test('OTP de 6 dígitos es válido', () {
      expect(Validators.otp('123456'), isNull);
    });

    test('OTP de 5 dígitos es inválido', () {
      expect(Validators.otp('12345'), isNotNull);
    });

    test('OTP con letras es inválido', () {
      expect(Validators.otp('12345A'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('Contraseña de menos de 8 caracteres es inválida', () {
      expect(Validators.password('1234567'), isNotNull);
    });

    test('Contraseña de 8 caracteres es válida', () {
      expect(Validators.password('12345678'), isNull);
    });
  });
}

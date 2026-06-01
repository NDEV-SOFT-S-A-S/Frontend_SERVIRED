import '../constants/app_constants.dart';
import '../constants/document_type.dart';

class Validators {
  Validators._();

  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName es obligatorio.' : 'Este campo es obligatorio.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es obligatoria.';
    if (value.length < AppConstants.minPasswordLength) {
      return 'La contraseña debe tener al menos ${AppConstants.minPasswordLength} caracteres.';
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return 'La contraseña no puede exceder ${AppConstants.maxPasswordLength} caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String? original) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña.';
    if (value != original) return 'Las contraseñas no coinciden.';
    return null;
  }

  static String? documentNumber(String? value, DocumentType? type) {
    if (value == null || value.trim().isEmpty) return 'El número de documento es obligatorio.';
    final trimmed = value.trim();
    return switch (type) {
      DocumentType.cedulaCiudadania => _validateNumeric(trimmed, min: 6, max: 10),
      DocumentType.cedulaExtranjeria => _validateAlphanumeric(trimmed, min: 6, max: 15),
      DocumentType.pasaporte => _validateAlphanumeric(trimmed, min: 5, max: 20),
      DocumentType.pep ||
      DocumentType.ppt =>
        _validateAlphanumeric(trimmed, min: 6, max: 20),
      DocumentType.carnetDiplomatico => _validateAlphanumeric(trimmed, min: 5, max: 20),
      _ => null,
    };
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo electrónico es obligatorio.';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$');
    if (!regex.hasMatch(value.trim())) return 'Ingresa un correo electrónico válido.';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'El número de teléfono es obligatorio.';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return 'Ingresa un número de teléfono válido.';
    return null;
  }

  // HU-LOG001: edad mínima 18 años
  static String? birthDate(DateTime? value) {
    if (value == null) return 'La fecha de nacimiento es obligatoria.';
    final today = DateTime.now();
    var age = today.year - value.year;
    if (today.month < value.month ||
        (today.month == value.month && today.day < value.day)) {
      age--;
    }
    if (age < AppConstants.minAge) {
      return 'Debes tener al menos ${AppConstants.minAge} años para registrarte.';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresa el código de verificación.';
    if (value.trim().length != AppConstants.otpLength) {
      return 'El código debe tener ${AppConstants.otpLength} dígitos.';
    }
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'El código solo debe contener números.';
    }
    return null;
  }

  static String? _validateNumeric(String value, {required int min, required int max}) {
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'Solo se permiten números.';
    if (value.length < min) return 'Mínimo $min dígitos.';
    if (value.length > max) return 'Máximo $max dígitos.';
    return null;
  }

  static String? _validateAlphanumeric(String value, {required int min, required int max}) {
    if (value.length < min) return 'Mínimo $min caracteres.';
    if (value.length > max) return 'Máximo $max caracteres.';
    return null;
  }
}

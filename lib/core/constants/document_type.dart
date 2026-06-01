import 'app_constants.dart';

enum DocumentType {
  cedulaCiudadania(AppConstants.docCedulaCiudadania, 'Cédula de ciudadanía'),
  cedulaExtranjeria(AppConstants.docCedulaExtranjeria, 'Cédula de extranjería'),
  pep(AppConstants.docPEP, 'Permiso Especial de Permanencia'),
  ppt(AppConstants.docPPT, 'Permiso por Protección Temporal'),
  pasaporte(AppConstants.docPasaporte, 'Pasaporte'),
  carnetDiplomatico(AppConstants.docCarnetDiplomatico, 'Carnet diplomático');

  const DocumentType(this.code, this.label);

  final String code;
  final String label;

  static DocumentType? fromCode(String code) {
    for (final type in DocumentType.values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

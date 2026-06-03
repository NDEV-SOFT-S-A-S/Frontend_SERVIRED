class AppConstants {
  AppConstants._();

  // Timeouts de red (ms)
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Claves de almacenamiento seguro
  static const String kAuthToken = 'auth_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserId = 'user_id';

  // Longitudes de campos según HU-LOG001
  static const int otpLength = 6;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 20;

  // Tipos de documento (HU-LOG001)
  static const String docCedulaCiudadania = 'CC';
  static const String docCedulaExtranjeria = 'CE';
  static const String docPEP = 'PEP';
  static const String docPPT = 'PPT';
  static const String docPasaporte = 'PA';
  static const String docCarnetDiplomatico = 'CD';

  // Edad mínima requerida (HU-LOG001)
  static const int minAge = 18;
}

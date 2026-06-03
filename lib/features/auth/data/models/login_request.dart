class LoginRequest {
  const LoginRequest({
    required this.documentType,
    required this.documentNumber,
    required this.password,
  });

  final String documentType;
  final String documentNumber;
  final String password;

  Map<String, dynamic> toJson() => {
        'document_type': documentType,
        'document_number': documentNumber,
        'password': password,
      };
}

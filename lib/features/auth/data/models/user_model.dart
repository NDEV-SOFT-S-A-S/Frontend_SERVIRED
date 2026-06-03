import '../../domain/entities/user_entity.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.documentType,
    required this.documentNumber,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.birthDate,
    this.gender,
    this.nationality,
  });

  final String id;
  final String documentType;
  final String documentNumber;
  final String fullName;
  final String email;
  final String phone;
  final String birthDate;
  final String? gender;
  final String? nationality;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        documentType: json['document_type'] as String,
        documentNumber: json['document_number'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        birthDate: json['birth_date'] as String,
        gender: json['gender'] as String?,
        nationality: json['nationality'] as String?,
      );

  UserEntity toEntity() => UserEntity(
        id: id,
        documentType: documentType,
        documentNumber: documentNumber,
        fullName: fullName,
        email: email,
        phone: phone,
        birthDate: DateTime.parse(birthDate),
        gender: gender,
        nationality: nationality,
      );
}

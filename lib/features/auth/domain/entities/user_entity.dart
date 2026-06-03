import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  const UserEntity({
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
  final DateTime birthDate;
  final String? gender;
  final String? nationality;

  @override
  List<Object?> get props => [
        id,
        documentType,
        documentNumber,
        fullName,
        email,
        phone,
        birthDate,
        gender,
        nationality,
      ];
}

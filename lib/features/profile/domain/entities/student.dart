import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/phone_number.dart';

/// A student's gender, constrained to the three accepted values (R1.6).
enum Gender {
  male,
  female,
  other;

  /// The canonical wire/storage representation, e.g. `"male"`.
  String get wireName => name;
}

/// Parsing helpers that enforce validity for [Gender] at the boundary.
extension GenderX on Gender {
  /// Parses a wire/storage string into a [Gender]; throws on unknown input.
  static Gender parse(String value) => Gender.values.firstWhere(
        (Gender g) => g.wireName == value,
        orElse: () => throw ArgumentError.value(value, 'value', 'Unknown Gender'),
      );

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static Gender? tryParse(String value) {
    for (final Gender g in Gender.values) {
      if (g.wireName == value) return g;
    }
    return null;
  }
}

/// A registered student's profile (R1.6).
///
/// Pure domain entity (no backend types). Field bounds (name/city 1..100,
/// height 50..250, DOB in the past, photo JPEG/PNG <= 5MB) are enforced by the
/// validator, not here.
class Student extends Equatable {
  const Student({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.city,
    required this.heightCm,
    required this.profilePhotoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String fullName;
  final PhoneNumber phone;
  final Gender gender;
  final DateTime dateOfBirth;
  final String city;
  final int heightCm;

  /// Storage reference to the uploaded profile photo (empty when none).
  final String profilePhotoPath;

  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => <Object?>[
        uid,
        fullName,
        phone,
        gender,
        dateOfBirth,
        city,
        heightCm,
        profilePhotoPath,
        createdAt,
        updatedAt,
      ];
}

import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/phone_number.dart';

/// A student's gender.
///
/// Constrained to the three accepted values; any value outside this set is
/// rejected at the boundary via [GenderX.parse] (R1.6).
enum Gender {
  male,
  female,
  other;

  /// The canonical wire/storage representation, e.g. `"male"`.
  String get wireName {
    switch (this) {
      case Gender.male:
        return 'male';
      case Gender.female:
        return 'female';
      case Gender.other:
        return 'other';
    }
  }
}

/// Parsing helpers that enforce validity for [Gender] at the boundary.
extension GenderX on Gender {
  /// Parses a wire/storage string into a [Gender].
  ///
  /// Accepts exactly `male`, `female`, or `other`. Throws an [ArgumentError]
  /// for any unknown value.
  static Gender parse(String value) {
    for (final gender in Gender.values) {
      if (gender.wireName == value) {
        return gender;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown Gender');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static Gender? tryParse(String value) {
    for (final gender in Gender.values) {
      if (gender.wireName == value) {
        return gender;
      }
    }
    return null;
  }
}

/// A registered student's profile (R1.6).
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only ([DateTime], [PhoneNumber], [Gender]), so it is unaffected
/// by a future change of backend. Field bounds (full name 1..100, city 1..100,
/// height 50..250, date of birth strictly in the past, photo format/size) are
/// enforced by the registration validator and use case rather than by this
/// value holder.
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

  /// The student's unique identifier (matches the authenticated user's uid).
  final String uid;

  /// The student's full name (expected 1..100 characters).
  final String fullName;

  /// The student's phone number.
  final PhoneNumber phone;

  /// The student's gender.
  final Gender gender;

  /// The student's date of birth (expected strictly in the past).
  final DateTime dateOfBirth;

  /// The student's city (expected 1..100 characters).
  final String city;

  /// The student's height in centimetres (expected 50..250).
  final int heightCm;

  /// The storage reference to the uploaded profile photo (JPEG/PNG, <= 5MB).
  final String profilePhotoPath;

  /// When the profile was created.
  final DateTime createdAt;

  /// When the profile was last updated.
  final DateTime updatedAt;

  /// Returns a copy of this student with the given fields replaced.
  Student copyWith({
    String? fullName,
    PhoneNumber? phone,
    Gender? gender,
    DateTime? dateOfBirth,
    String? city,
    int? heightCm,
    String? profilePhotoPath,
    DateTime? updatedAt,
  }) {
    return Student(
      uid: uid,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      city: city ?? this.city,
      heightCm: heightCm ?? this.heightCm,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  @override
  String toString() => 'Student('
      'uid: $uid, '
      'fullName: $fullName, '
      'phone: $phone, '
      'gender: $gender, '
      'dateOfBirth: $dateOfBirth, '
      'city: $city, '
      'heightCm: $heightCm, '
      'profilePhotoPath: $profilePhotoPath, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt)';
}

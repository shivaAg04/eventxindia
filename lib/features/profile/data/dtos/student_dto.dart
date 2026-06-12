import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/student.dart';

/// Firebase data-transfer object for a `students/{uid}` document.
///
/// This is the only place Firebase types (`DocumentSnapshot`, `Timestamp`)
/// touch the [Student] shape. The DTO parses a Firestore document into plain
/// Dart fields ([fromFirestore]), serialises back to a Firestore-ready map
/// ([toFirestore]), and converts to/from the pure domain [Student] entity
/// ([toEntity]/[StudentDto.fromEntity]) — mapping the storage `gender`
/// wire-name to/from [Gender], the `phone` string to/from [PhoneNumber], and
/// Firestore `Timestamp`s to/from [DateTime] (design "DTO / Mapper Pattern").
class StudentDto {
  const StudentDto({
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

  /// The student's unique identifier (matches the document id).
  final String uid;

  /// The student's full name.
  final String fullName;

  /// The student's phone number in canonical string form (E.164).
  final String phone;

  /// The student's gender wire-name (`male` | `female` | `other`).
  final String gender;

  /// The student's date of birth.
  final DateTime dateOfBirth;

  /// The student's city.
  final String city;

  /// The student's height in centimetres.
  final int heightCm;

  /// The Storage reference to the uploaded profile photo.
  final String profilePhotoPath;

  /// When the profile was created.
  final DateTime createdAt;

  /// When the profile was last updated.
  final DateTime updatedAt;

  /// Parses a Firestore `students/{uid}` document into a [StudentDto].
  factory StudentDto.fromFirestore(DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return StudentDto(
      uid: data['uid'] as String? ?? doc.id,
      fullName: data['fullName'] as String,
      phone: data['phone'] as String,
      gender: data['gender'] as String,
      dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate(),
      city: data['city'] as String,
      heightCm: (data['heightCm'] as num).toInt(),
      profilePhotoPath: data['profilePhotoPath'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Builds a DTO from a pure domain [Student] entity (outbound mapping).
  factory StudentDto.fromEntity(Student student) {
    return StudentDto(
      uid: student.uid,
      fullName: student.fullName,
      phone: student.phone.e164,
      gender: student.gender.wireName,
      dateOfBirth: student.dateOfBirth,
      city: student.city,
      heightCm: student.heightCm,
      profilePhotoPath: student.profilePhotoPath,
      createdAt: student.createdAt,
      updatedAt: student.updatedAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map (Firebase `Timestamp`s).
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'uid': uid,
      'fullName': fullName,
      'phone': phone,
      'gender': gender,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'city': city,
      'heightCm': heightCm,
      'profilePhotoPath': profilePhotoPath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts this DTO to a pure domain [Student] entity (inbound mapping).
  Student toEntity() {
    return Student(
      uid: uid,
      fullName: fullName,
      phone: PhoneNumber.parse(phone),
      gender: GenderX.parse(gender),
      dateOfBirth: dateOfBirth,
      city: city,
      heightCm: heightCm,
      profilePhotoPath: profilePhotoPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

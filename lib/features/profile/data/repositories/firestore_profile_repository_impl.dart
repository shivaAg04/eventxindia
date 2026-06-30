import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/write_retry.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/student.dart';
import '../../domain/entities/vendor.dart';
import '../../domain/repositories/profile_repository.dart';

/// Firestore-backed implementation of [ProfileRepository].
///
/// Persists student and vendor profiles to the `students/{uid}` and
/// `vendors/{uid}` collections (R14.2, R14.3). Creating a profile also writes
/// the `users/{uid}` role record in the same batch (R3.4) so the session
/// resolves to a role once registration completes. All writes go through the
/// pure [withRetry] policy (`maxAttempts = 3`) so a failed write is retried up
/// to three times and commits no partial data on total failure (R14.6).
///
/// Firestore access and `Map` <-> entity mapping both live here: Firebase types
/// (`DocumentSnapshot`, `Timestamp`) are confined to this class and never cross
/// back to the use-case layer.
@LazySingleton(as: ProfileRepository)
class FirestoreProfileRepositoryImpl implements ProfileRepository {
  const FirestoreProfileRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _studentsCollection = 'students';
  static const String _vendorsCollection = 'vendors';
  static const String _usersCollection = 'users';

  @override
  Future<Result<Student, Failure>> createStudent(Student student) {
    return withRetry<Student>(kDefaultMaxWriteAttempts, () async {
      final Map<String, dynamic> data = _studentToMap(student);
      await (_firestore.batch()
            ..set(_firestore.collection(_studentsCollection).doc(student.uid),
                data)
            ..set(_firestore.collection(_usersCollection).doc(student.uid),
                _userRecord(student.uid, 'student', data)))
          .commit();
      return student;
    });
  }

  @override
  Future<Result<Student, Failure>> getStudent(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection(_studentsCollection).doc(uid).get();
      if (!doc.exists) {
        return const Result<Student, Failure>.err(NotFoundFailure());
      }
      return Result<Student, Failure>.ok(_studentFromDoc(doc));
    } catch (_) {
      return const Result<Student, Failure>.err(PersistenceFailure());
    }
  }

  @override
  Future<Result<Vendor, Failure>> createVendor(Vendor vendor) {
    return withRetry<Vendor>(kDefaultMaxWriteAttempts, () async {
      final Map<String, dynamic> data = _vendorToMap(vendor);
      await (_firestore.batch()
            ..set(_firestore.collection(_vendorsCollection).doc(vendor.uid),
                data)
            ..set(_firestore.collection(_usersCollection).doc(vendor.uid),
                _userRecord(vendor.uid, 'vendor', data)))
          .commit();
      return vendor;
    });
  }

  @override
  Future<Result<Vendor, Failure>> getVendor(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _firestore.collection(_vendorsCollection).doc(uid).get();
      if (!doc.exists) {
        return const Result<Vendor, Failure>.err(NotFoundFailure());
      }
      return Result<Vendor, Failure>.ok(_vendorFromDoc(doc));
    } catch (_) {
      return const Result<Vendor, Failure>.err(PersistenceFailure());
    }
  }

  /// The minimal `users/{uid}` role record written alongside a profile. The
  /// role drives session resolution and authorization; the phone is copied from
  /// the profile payload when present.
  Map<String, dynamic> _userRecord(
    String uid,
    String role,
    Map<String, dynamic> profile,
  ) {
    return <String, dynamic>{
      'uid': uid,
      'role': role,
      if (profile['phone'] != null) 'phone': profile['phone'],
    };
  }

  Map<String, dynamic> _studentToMap(Student student) {
    return <String, dynamic>{
      'uid': student.uid,
      'fullName': student.fullName,
      'phone': student.phone.e164,
      'gender': student.gender.wireName,
      'dateOfBirth': Timestamp.fromDate(student.dateOfBirth),
      'city': student.city,
      'heightCm': student.heightCm,
      'profilePhotoPath': student.profilePhotoPath,
      'createdAt': Timestamp.fromDate(student.createdAt),
      'updatedAt': Timestamp.fromDate(student.updatedAt),
    };
  }

  Student _studentFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;
    return Student(
      uid: data['uid'] as String? ?? doc.id,
      fullName: data['fullName'] as String,
      phone: PhoneNumber.parse(data['phone'] as String),
      gender: GenderX.parse(data['gender'] as String),
      dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate(),
      city: data['city'] as String,
      heightCm: (data['heightCm'] as num).toInt(),
      profilePhotoPath: data['profilePhotoPath'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _vendorToMap(Vendor vendor) {
    return <String, dynamic>{
      'uid': vendor.uid,
      'fullName': vendor.fullName,
      'agencyName': vendor.agencyName,
      'phone': vendor.phone.e164,
      'city': vendor.city,
      'address': vendor.address,
      'approvalStatus': vendor.approvalStatus.wireName,
      if (vendor.aadhaarOrPan != null) 'aadhaarOrPan': vendor.aadhaarOrPan,
      if (vendor.website != null) 'website': vendor.website,
      if (vendor.socialLinks.isNotEmpty) 'socialLinks': vendor.socialLinks,
      'createdAt': Timestamp.fromDate(vendor.createdAt),
      'updatedAt': Timestamp.fromDate(vendor.updatedAt),
    };
  }

  Vendor _vendorFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data()!;
    return Vendor(
      uid: data['uid'] as String? ?? doc.id,
      fullName: data['fullName'] as String,
      agencyName: data['agencyName'] as String,
      phone: PhoneNumber.parse(data['phone'] as String),
      city: data['city'] as String,
      address: data['address'] as String,
      approvalStatus: ApprovalStatusX.parse(data['approvalStatus'] as String),
      aadhaarOrPan: data['aadhaarOrPan'] as String?,
      website: data['website'] as String?,
      socialLinks: (data['socialLinks'] as List<dynamic>?)?.cast<String>() ??
          const <String>[],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}

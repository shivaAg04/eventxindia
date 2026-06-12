import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';

/// Thin Firestore data source for student and vendor profile documents.
///
/// Confines Firestore access for the profile feature to a single injectable
/// wrapper over [FirebaseFirestore]: it reads/writes the `students/{uid}` and
/// `vendors/{uid}` documents (R14.2, R14.3) and returns raw
/// [DocumentSnapshot]s. DTO/entity mapping and the write-retry policy live in
/// the repository implementation.
@injectable
class FirestoreProfileDataSource extends FirestoreDataSource {
  FirestoreProfileDataSource(super.firestore);

  static const String _studentsCollection = 'students';
  static const String _vendorsCollection = 'vendors';

  DocumentReference<Map<String, dynamic>> _studentDoc(String uid) =>
      firestore.collection(_studentsCollection).doc(uid);

  DocumentReference<Map<String, dynamic>> _vendorDoc(String uid) =>
      firestore.collection(_vendorsCollection).doc(uid);

  /// Writes the student document at `students/{uid}` and returns the stored
  /// snapshot.
  Future<DocumentSnapshot<Map<String, dynamic>>> setStudent(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final DocumentReference<Map<String, dynamic>> ref = _studentDoc(uid);
    await ref.set(data);
    return ref.get();
  }

  /// Reads the student document at `students/{uid}`.
  Future<DocumentSnapshot<Map<String, dynamic>>> getStudent(String uid) =>
      _studentDoc(uid).get();

  /// Writes the vendor document at `vendors/{uid}` and returns the stored
  /// snapshot.
  Future<DocumentSnapshot<Map<String, dynamic>>> setVendor(
    String uid,
    Map<String, dynamic> data,
  ) async {
    final DocumentReference<Map<String, dynamic>> ref = _vendorDoc(uid);
    await ref.set(data);
    return ref.get();
  }

  /// Reads the vendor document at `vendors/{uid}`.
  Future<DocumentSnapshot<Map<String, dynamic>>> getVendor(String uid) =>
      _vendorDoc(uid).get();
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/application_dto.dart';

/// Thrown by [FirestoreApplicationDataSource.createIfAbsent] when a document
/// with the same composite id already exists.
///
/// The repository translates this into a domain failure that signals a
/// duplicate application (R9.2) rather than silently overwriting the existing
/// record.
class ApplicationAlreadyExistsException implements Exception {
  const ApplicationAlreadyExistsException(this.applicationId);

  /// The composite id `"{eventId}_{studentId}"` that already exists.
  final String applicationId;

  @override
  String toString() =>
      'ApplicationAlreadyExistsException(applicationId: $applicationId)';
}

/// Thrown by [FirestoreApplicationDataSource.getById] when no document exists
/// for the requested id.
class ApplicationNotFoundException implements Exception {
  const ApplicationNotFoundException(this.applicationId);

  /// The composite id `"{eventId}_{studentId}"` that was not found.
  final String applicationId;

  @override
  String toString() =>
      'ApplicationNotFoundException(applicationId: $applicationId)';
}

/// Firestore-backed data source for the `applications` collection.
///
/// Each application is stored under the composite document id
/// `"{eventId}_{studentId}"` (R9.6). This data source owns all direct Firestore
/// access for applications; it returns/accepts [ApplicationDto]s and keeps
/// Firebase types confined to the data layer.
@injectable
class FirestoreApplicationDataSource extends FirestoreDataSource {
  FirestoreApplicationDataSource(super.firestore);

  /// The name of the Firestore collection holding application documents.
  static const String collectionName = 'applications';

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(collectionName);

  /// Creates the application document only when no document with the same
  /// composite id already exists.
  ///
  /// Runs inside a Firestore transaction so the existence check and the write
  /// are atomic: this enforces the "at most one application per student per
  /// event" dedupe rule (R9.2) without overwriting an existing record. Throws
  /// [ApplicationAlreadyExistsException] when the document already exists.
  Future<void> createIfAbsent(ApplicationDto dto) {
    final DocumentReference<Map<String, dynamic>> ref =
        _collection.doc(dto.applicationId);
    return firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await txn.get(ref);
      if (snapshot.exists) {
        throw ApplicationAlreadyExistsException(dto.applicationId);
      }
      txn.set(ref, dto.toFirestore());
    });
  }

  /// Updates the application document identified by `dto.applicationId`.
  ///
  /// Used to persist a status decision (Approved/Rejected) and the new
  /// `updatedAt` timestamp (R9.3, R9.4).
  Future<void> update(ApplicationDto dto) {
    return _collection.doc(dto.applicationId).update(dto.toFirestore());
  }

  /// Reads a single application document by its composite id.
  ///
  /// Throws [ApplicationNotFoundException] when no such document exists.
  Future<ApplicationDto> getById(String applicationId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc =
        await _collection.doc(applicationId).get();
    if (!doc.exists) {
      throw ApplicationNotFoundException(applicationId);
    }
    return ApplicationDto.fromFirestore(doc);
  }

  /// Streams the applications submitted to [eventId].
  Stream<List<ApplicationDto>> watchByEvent(String eventId) {
    return _collection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(_mapSnapshot);
  }

  /// Streams the applications submitted by [studentId].
  Stream<List<ApplicationDto>> watchByStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_mapSnapshot);
  }

  List<ApplicationDto> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map(ApplicationDto.fromFirestore)
        .toList(growable: false);
  }
}

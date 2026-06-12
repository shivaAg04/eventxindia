import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/attendance_dto.dart';

/// The Firestore collection that stores attendance records (R10.10).
const String kAttendanceCollection = 'attendance';

/// Cloud Firestore data source for attendance records.
///
/// Owns all direct access to the `attendance` collection, where each document
/// id is the composite key `"{eventId}_{studentId}"` so a student has at most
/// one attendance record per event (R10.5, R10.10). It speaks [AttendanceDto]
/// only — Firebase types stay confined here and in the DTO — and performs no
/// retry or error mapping itself; the repository layers the write-retry policy
/// (R14.6) on top.
@injectable
class FirestoreAttendanceDataSource extends FirestoreDataSource {
  const FirestoreAttendanceDataSource(super.firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(kAttendanceCollection);

  /// Creates the check-in document for [dto], failing if a record with the same
  /// composite id already exists so a repeated check-in is rejected rather than
  /// overwriting (R10.1, R10.5, R10.10).
  ///
  /// Uses `create` (a `set` with `SetOptions` is not atomic-create) via a
  /// transaction that asserts the document does not yet exist. Returns the
  /// persisted record re-read as a DTO.
  Future<AttendanceDto> createCheckIn(AttendanceDto dto) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _collection.doc(dto.attendanceId);
    await firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await txn.get(ref);
      if (snapshot.exists) {
        throw StateError(
          'Attendance record ${dto.attendanceId} already exists.',
        );
      }
      txn.set(ref, dto.toFirestore());
    });
    return _readById(dto.attendanceId);
  }

  /// Persists the completed check-out for [dto], merging the check-out fields
  /// into the existing document without clobbering server-owned fields such as
  /// `accrued` (which the DTO never serialises) (R10.6, R10.9, R10.10).
  Future<AttendanceDto> updateCheckOut(AttendanceDto dto) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _collection.doc(dto.attendanceId);
    await ref.set(dto.toFirestore(), SetOptions(merge: true));
    return _readById(dto.attendanceId);
  }

  /// Reads the attendance record identified by [attendanceId], or `null` when
  /// no such document exists.
  Future<AttendanceDto?> getById(String attendanceId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(attendanceId).get();
    if (!snapshot.exists) {
      return null;
    }
    return AttendanceDto.fromFirestore(snapshot);
  }

  /// Streams the attendance records belonging to [studentId] (R4.4).
  Stream<List<AttendanceDto>> watchByStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_mapSnapshots);
  }

  /// Streams the attendance records recorded for [eventId].
  Stream<List<AttendanceDto>> watchByEvent(String eventId) {
    return _collection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(_mapSnapshots);
  }

  Future<AttendanceDto> _readById(String attendanceId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(attendanceId).get();
    return AttendanceDto.fromFirestore(snapshot);
  }

  List<AttendanceDto> _mapSnapshots(
    QuerySnapshot<Map<String, dynamic>> query,
  ) =>
      query.docs.map(AttendanceDto.fromFirestore).toList(growable: false);
}

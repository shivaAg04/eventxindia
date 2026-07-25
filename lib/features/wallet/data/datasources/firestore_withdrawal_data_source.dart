import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/withdrawal_request_dto.dart';

/// The Firestore collection that stores wallet withdrawal requests.
const String kWithdrawalsCollection = 'withdrawals';

/// Cloud Firestore data source for withdrawal requests.
///
/// Owns all direct access to the `withdrawals` collection, speaking
/// [WithdrawalRequestDto] only so Firebase types stay confined here and in the
/// DTO. Lists are sorted newest-first client-side to avoid requiring a
/// composite index for the `studentId` filter.
@injectable
class FirestoreWithdrawalDataSource extends FirestoreDataSource {
  const FirestoreWithdrawalDataSource(super.firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(kWithdrawalsCollection);

  /// Creates the withdrawal document for [dto] and returns it re-read.
  Future<WithdrawalRequestDto> create(WithdrawalRequestDto dto) async {
    await _collection.doc(dto.id).set(dto.toFirestore());
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(dto.id).get();
    return WithdrawalRequestDto.fromFirestore(snapshot);
  }

  /// Updates the status (and decision time) of the request [id].
  Future<void> updateStatus(
    String id,
    String status,
    DateTime decidedAt,
  ) {
    return _collection.doc(id).update(<String, dynamic>{
      'status': status,
      'decidedAt': Timestamp.fromDate(decidedAt),
    });
  }

  /// Streams the requests made by [studentId], newest first.
  Stream<List<WithdrawalRequestDto>> watchByStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_mapSorted);
  }

  /// Streams every request across all students, newest first.
  Stream<List<WithdrawalRequestDto>> watchAll() {
    return _collection.snapshots().map(_mapSorted);
  }

  List<WithdrawalRequestDto> _mapSorted(
    QuerySnapshot<Map<String, dynamic>> query,
  ) {
    final List<WithdrawalRequestDto> dtos = query.docs
        .map(WithdrawalRequestDto.fromFirestore)
        .toList(growable: true)
      ..sort(
        (WithdrawalRequestDto a, WithdrawalRequestDto b) =>
            b.createdAt.compareTo(a.createdAt),
      );
    return dtos;
  }
}

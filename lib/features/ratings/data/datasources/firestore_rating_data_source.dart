import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/rating_dto.dart';

/// The Firestore collection that stores student ratings.
const String kRatingsCollection = 'ratings';

/// Cloud Firestore data source for student ratings.
///
/// Owns all direct access to the `ratings` collection, where each document id
/// is the composite key `"{eventId}_{studentId}"` so a student has at most one
/// rating per event (one-time rule). It speaks [RatingDto] only — Firebase
/// types stay confined here and in the DTO — and performs no retry or error
/// mapping itself; the repository layers the write-retry policy on top.
@injectable
class FirestoreRatingDataSource extends FirestoreDataSource {
  const FirestoreRatingDataSource(super.firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(kRatingsCollection);

  /// Creates the rating document for [dto], failing if a rating with the same
  /// composite id already exists so a repeated rating is rejected rather than
  /// overwriting (one-time rule). Returns the persisted rating re-read.
  Future<RatingDto> create(RatingDto dto) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _collection.doc(dto.ratingId);
    await firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await txn.get(ref);
      if (snapshot.exists) {
        throw StateError('Rating ${dto.ratingId} already exists.');
      }
      txn.set(ref, dto.toFirestore());
    });
    return _readById(dto.ratingId);
  }

  /// Reads the rating identified by [ratingId], or `null` when none exists.
  Future<RatingDto?> getById(String ratingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(ratingId).get();
    if (!snapshot.exists) {
      return null;
    }
    return RatingDto.fromFirestore(snapshot);
  }

  /// Streams the ratings a single student has received.
  Stream<List<RatingDto>> watchByStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(_mapSnapshots);
  }

  /// Streams the ratings recorded for a single event.
  Stream<List<RatingDto>> watchByEvent(String eventId) {
    return _collection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map(_mapSnapshots);
  }

  Future<RatingDto> _readById(String ratingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(ratingId).get();
    return RatingDto.fromFirestore(snapshot);
  }

  List<RatingDto> _mapSnapshots(
    QuerySnapshot<Map<String, dynamic>> query,
  ) =>
      query.docs.map(RatingDto.fromFirestore).toList(growable: false);
}

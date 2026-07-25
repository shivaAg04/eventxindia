import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventxindia/core/value_objects/rating.dart';
import 'package:eventxindia/features/ratings/data/dtos/rating_dto.dart';
import 'package:eventxindia/features/ratings/domain/entities/rating_entry.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> snapshot(
    String id, {
    Map<String, dynamic>? data,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref =
        firestore.collection('ratings').doc(id);
    if (data != null) {
      await ref.set(data);
    }
    return ref.get();
  }

  final RatingEntry entry = RatingEntry(
    ratingId: 'e1_s1',
    eventId: 'e1',
    studentId: 's1',
    vendorId: 'v1',
    stars: Rating(4),
    createdAt: DateTime(2026, 7, 25, 10, 30),
  );

  test('entity -> firestore -> entity round-trips', () async {
    final Map<String, dynamic> map = RatingDto.fromEntity(entry).toFirestore();
    final RatingDto parsed = RatingDto.fromFirestore(
      await snapshot('e1_s1', data: map),
    );
    final RatingEntry back = parsed.toEntity();

    expect(back.ratingId, entry.ratingId);
    expect(back.eventId, entry.eventId);
    expect(back.studentId, entry.studentId);
    expect(back.vendorId, entry.vendorId);
    expect(back.stars, entry.stars);
    expect(back.createdAt, entry.createdAt);
  });

  test('fromFirestore falls back to doc id when ratingId field is absent',
      () async {
    final RatingDto dto = RatingDto.fromFirestore(
      await snapshot('e9_s9', data: <String, dynamic>{
        'eventId': 'e9',
        'studentId': 's9',
        'vendorId': 'v9',
        'stars': 5,
        'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      }),
    );
    expect(dto.ratingId, 'e9_s9');
    expect(dto.toEntity().stars, Rating(5));
  });
}

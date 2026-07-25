import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/rating.dart';
import 'package:eventxindia/features/ratings/domain/entities/rating_entry.dart';
import 'package:eventxindia/features/ratings/domain/repositories/rating_repository.dart';
import 'package:eventxindia/features/ratings/domain/usecases/rate_student.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake repository keyed by ratingId.
class _FakeRatingRepository implements RatingRepository {
  final Map<String, RatingEntry> store = <String, RatingEntry>{};

  @override
  Future<Result<RatingEntry, Failure>> submit(RatingEntry rating) async {
    store[rating.ratingId] = rating;
    return Result<RatingEntry, Failure>.ok(rating);
  }

  @override
  Future<Result<RatingEntry?, Failure>> getById(String ratingId) async {
    return Result<RatingEntry?, Failure>.ok(store[ratingId]);
  }

  @override
  Stream<List<RatingEntry>> watchByStudent(String studentId) =>
      const Stream<List<RatingEntry>>.empty();

  @override
  Stream<List<RatingEntry>> watchByEvent(String eventId) =>
      const Stream<List<RatingEntry>>.empty();
}

void main() {
  late _FakeRatingRepository repo;
  late RateStudent rateStudent;

  setUp(() {
    repo = _FakeRatingRepository();
    rateStudent = RateStudent(
      repository: repo,
      now: () => DateTime(2026, 7, 25, 10),
    );
  });

  test('creates a rating and stamps it', () async {
    final Result<RatingEntry, Failure> result = await rateStudent(
      eventId: 'e1',
      studentId: 's1',
      vendorId: 'v1',
      stars: Rating(4),
    );

    expect(result.isOk, isTrue);
    final RatingEntry rating = result.valueOrNull!;
    expect(rating.ratingId, 'e1_s1');
    expect(rating.stars, Rating(4));
    expect(rating.vendorId, 'v1');
    expect(rating.createdAt, DateTime(2026, 7, 25, 10));
    expect(repo.store['e1_s1'], isNotNull);
  });

  test('rejects a second rating for the same event+student (one-time)',
      () async {
    await rateStudent(
      eventId: 'e1',
      studentId: 's1',
      vendorId: 'v1',
      stars: Rating(4),
    );

    final Result<RatingEntry, Failure> second = await rateStudent(
      eventId: 'e1',
      studentId: 's1',
      vendorId: 'v1',
      stars: Rating(2),
    );

    expect(second.isErr, isTrue);
    expect(second.failureOrNull, isA<StateTransitionFailure>());
    // The original rating is preserved (not overwritten).
    expect(repo.store['e1_s1']!.stars, Rating(4));
  });
}

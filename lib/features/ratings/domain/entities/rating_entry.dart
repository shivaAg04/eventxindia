import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/rating.dart';

/// A vendor's star rating of a student for a single event.
///
/// Pure domain entity (no backend types). The id is the composite
/// `"{eventId}_{studentId}"`, which doubles as the dedupe key that enforces
/// **one rating per student per event** — a rating is one-time, submitted only
/// after the student's check-out is complete, and cannot be changed afterwards.
class RatingEntry extends Equatable {
  const RatingEntry({
    required this.ratingId,
    required this.eventId,
    required this.studentId,
    required this.vendorId,
    required this.stars,
    required this.createdAt,
  });

  /// Creates a brand-new rating for [studentId] on [eventId], stamping
  /// [createdAt] with [now] and deriving the composite [ratingId].
  factory RatingEntry.create({
    required String eventId,
    required String studentId,
    required String vendorId,
    required Rating stars,
    required DateTime now,
  }) {
    return RatingEntry(
      ratingId: buildId(eventId: eventId, studentId: studentId),
      eventId: eventId,
      studentId: studentId,
      vendorId: vendorId,
      stars: stars,
      createdAt: now,
    );
  }

  /// The composite identifier `"{eventId}_{studentId}"` (matches the doc id).
  final String ratingId;

  /// The event this rating is for.
  final String eventId;

  /// The rated student.
  final String studentId;

  /// The vendor who gave the rating (the event's owner).
  final String vendorId;

  /// The star score (1..5).
  final Rating stars;

  /// When the rating was created.
  final DateTime createdAt;

  /// Builds the composite rating id from [eventId] and [studentId].
  static String buildId({
    required String eventId,
    required String studentId,
  }) =>
      '${eventId}_$studentId';

  @override
  List<Object?> get props =>
      <Object?>[ratingId, eventId, studentId, vendorId, stars, createdAt];
}

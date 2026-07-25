import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/value_objects/rating.dart';
import '../../domain/entities/rating_entry.dart';

/// Firebase data-transfer object for a `ratings/{eventId}_{studentId}` document.
///
/// The only place Firebase types (`DocumentSnapshot`, `Timestamp`) touch the
/// [RatingEntry] shape. `stars` is stored as a plain `int`; the domain [Rating]
/// value object is reconstructed on the way in ([toEntity]) so validity is
/// re-enforced at the boundary.
class RatingDto {
  const RatingDto({
    required this.ratingId,
    required this.eventId,
    required this.studentId,
    required this.vendorId,
    required this.stars,
    required this.createdAt,
  });

  final String ratingId;
  final String eventId;
  final String studentId;
  final String vendorId;
  final int stars;
  final DateTime createdAt;

  /// Parses a Firestore `ratings/{id}` document into a [RatingDto].
  factory RatingDto.fromFirestore(fs.DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return RatingDto(
      ratingId: data['ratingId'] as String? ?? doc.id,
      eventId: data['eventId'] as String,
      studentId: data['studentId'] as String,
      vendorId: data['vendorId'] as String,
      stars: (data['stars'] as num).toInt(),
      createdAt: (data['createdAt'] as fs.Timestamp).toDate(),
    );
  }

  /// Builds a DTO from a pure domain [RatingEntry] (outbound mapping).
  factory RatingDto.fromEntity(RatingEntry rating) {
    return RatingDto(
      ratingId: rating.ratingId,
      eventId: rating.eventId,
      studentId: rating.studentId,
      vendorId: rating.vendorId,
      stars: rating.stars.stars,
      createdAt: rating.createdAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map.
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'ratingId': ratingId,
      'eventId': eventId,
      'studentId': studentId,
      'vendorId': vendorId,
      'stars': stars,
      'createdAt': fs.Timestamp.fromDate(createdAt),
    };
  }

  /// Converts this DTO to a pure domain [RatingEntry] (inbound mapping).
  RatingEntry toEntity() {
    return RatingEntry(
      ratingId: ratingId,
      eventId: eventId,
      studentId: studentId,
      vendorId: vendorId,
      stars: Rating(stars),
      createdAt: createdAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/value_objects/money.dart';
import '../../domain/entities/earnings.dart';
import '../mappers/money_mapper.dart';

/// The Firestore-document shape of a student's earnings.
///
/// Mirrors the `earnings/{studentId}` document (design "Data Models"):
///
/// ```
/// {
///   studentId: string,
///   total: decimal,                  // sum of credited payPerHead, default 0
///   perEvent: { [eventId]: decimal }, // credited amount per completed event
///   updatedAt: Timestamp
/// }
/// ```
///
/// This DTO is the *only* place Firestore types (`DocumentSnapshot`) touch the
/// earnings feature; [toEntity] converts the parsed values into the pure domain
/// [Earnings] entity (backend-independence rule). The client never writes
/// earnings — accrual is performed exactly once by the trusted backend
/// (R11.1, R11.2) — so this DTO is inbound-only and exposes no `toFirestore`.
class EarningsDto {
  /// Creates a DTO from already-parsed field values.
  const EarningsDto({
    required this.studentId,
    required this.total,
    required this.perEvent,
  });

  /// Builds a DTO from a Firestore `earnings/{studentId}` document.
  ///
  /// Missing or empty fields degrade to an empty projection: a missing `total`
  /// becomes `0` and a missing `perEvent` becomes an empty map, matching the
  /// state of a student with no completed attendance records (R11.5). The
  /// document id is used as the [studentId] when the field is absent.
  factory EarningsDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};

    final String studentId = (data['studentId'] as String?) ?? doc.id;

    final Money total = MoneyMapper.fromDecimal(data['total'] as num?);

    final Map<String, dynamic> rawPerEvent =
        (data['perEvent'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final Map<String, Money> perEvent = <String, Money>{
      for (final MapEntry<String, dynamic> entry in rawPerEvent.entries)
        entry.key: MoneyMapper.fromDecimal(entry.value as num?),
    };

    return EarningsDto(
      studentId: studentId,
      total: total,
      perEvent: perEvent,
    );
  }

  /// The id of the student these earnings belong to.
  final String studentId;

  /// The estimated earnings total — the sum of credited pay-per-head (R11.3).
  final Money total;

  /// The amount credited for each completed event, keyed by event id (R11.4).
  final Map<String, Money> perEvent;

  /// Converts this DTO into the pure domain [Earnings] entity.
  Earnings toEntity() => Earnings(
        studentId: studentId,
        total: total,
        perEvent: perEvent,
      );
}

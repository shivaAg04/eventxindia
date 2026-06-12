import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/report.dart';

/// Field-level conversion helpers between the Firestore `reports/{reportId}`
/// document shape and the pure domain [Report] types.
///
/// These helpers are the single place where Firebase `Timestamp` values and the
/// wire strings for [SubmitterRole]/[ReportCategory] are translated to/from the
/// pure domain representation (`DateTime` and the enums). Keeping them here lets
/// the [ReportDto] describe the document shape while delegating the actual
/// mapping rules to one reusable location (design "DTO / Mapper Pattern").
class ReportMapper {
  const ReportMapper._();

  /// Converts a Firestore [Timestamp] into a pure [DateTime].
  static DateTime dateTimeFromTimestamp(Timestamp timestamp) =>
      timestamp.toDate();

  /// Converts a pure [DateTime] into a Firestore [Timestamp].
  static Timestamp timestampFromDateTime(DateTime dateTime) =>
      Timestamp.fromDate(dateTime);

  /// Parses the stored `submitterRole` wire string into a [SubmitterRole].
  ///
  /// Throws an [ArgumentError] for any unknown value, surfacing corrupt
  /// documents at the data-layer boundary rather than letting them leak into
  /// the domain.
  static SubmitterRole submitterRoleFromWire(String wire) =>
      SubmitterRoleX.parse(wire);

  /// Serialises a [SubmitterRole] to its canonical wire string.
  static String submitterRoleToWire(SubmitterRole role) => role.wireName;

  /// Parses the stored `category` wire string into a [ReportCategory].
  ///
  /// Throws an [ArgumentError] for any unknown value.
  static ReportCategory categoryFromWire(String wire) =>
      ReportCategoryX.parse(wire);

  /// Serialises a [ReportCategory] to its canonical wire string.
  static String categoryToWire(ReportCategory category) => category.wireName;
}

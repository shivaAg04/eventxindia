import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/report.dart';
import '../mappers/report_mapper.dart';

/// Data-transfer object for the Firestore `reports/{reportId}` document
/// (design "reports/{reportId} → Report entity").
///
/// This is the only type that knows the Firebase document shape for a report:
/// it parses a [DocumentSnapshot] via [ReportDto.fromFirestore], serialises to a
/// Firestore map via [toFirestore], and converts to/from the pure domain
/// [Report] via [toEntity]/[ReportDto.fromEntity]. Firebase `Timestamp` values
/// and the role/category wire strings never escape this layer — the mapping is
/// delegated to [ReportMapper].
class ReportDto {
  const ReportDto({
    required this.reportId,
    required this.submitterId,
    required this.submitterRole,
    required this.category,
    required this.description,
    required this.createdAt,
  });

  /// The report's unique identifier (the document id).
  final String reportId;

  /// The id of the user who submitted the report.
  final String submitterId;

  /// The submitter's role as the stored wire string (`student` | `vendor`).
  final String submitterRole;

  /// The issue category as the stored wire string
  /// (`FakeEvent` | `VendorIssue` | `NoShow` | `Misbehavior`).
  final String category;

  /// The free-text description of the issue.
  final String description;

  /// When the report was created, in Firebase's native [Timestamp] form.
  final Timestamp createdAt;

  /// Builds a [ReportDto] from a Firestore [DocumentSnapshot].
  ///
  /// The document id is used as the [reportId] so reads remain consistent even
  /// if the stored map omits the redundant `reportId` field.
  factory ReportDto.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? const <String, dynamic>{};
    return ReportDto(
      reportId: doc.id,
      submitterId: data['submitterId'] as String,
      submitterRole: data['submitterRole'] as String,
      category: data['category'] as String,
      description: data['description'] as String,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  /// Builds a [ReportDto] from a pure domain [Report].
  factory ReportDto.fromEntity(Report report) => ReportDto(
        reportId: report.reportId,
        submitterId: report.submitterId,
        submitterRole: ReportMapper.submitterRoleToWire(report.submitterRole),
        category: ReportMapper.categoryToWire(report.category),
        description: report.description,
        createdAt: ReportMapper.timestampFromDateTime(report.createdAt),
      );

  /// Serialises this DTO to a Firestore document map.
  ///
  /// The `reportId` is intentionally omitted: it is carried by the document id,
  /// not duplicated inside the document body.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'submitterId': submitterId,
        'submitterRole': submitterRole,
        'category': category,
        'description': description,
        'createdAt': createdAt,
      };

  /// Converts this DTO into a pure domain [Report].
  Report toEntity() => Report(
        reportId: reportId,
        submitterId: submitterId,
        submitterRole: ReportMapper.submitterRoleFromWire(submitterRole),
        category: ReportMapper.categoryFromWire(category),
        description: description,
        createdAt: ReportMapper.dateTimeFromTimestamp(createdAt),
      );
}

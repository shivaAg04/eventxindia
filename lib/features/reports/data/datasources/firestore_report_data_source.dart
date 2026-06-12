import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/report_dto.dart';

/// Thin Firestore data source for the `reports` collection.
///
/// Confines all Firebase query/collection access for reports to one place: it
/// exposes a [submit] write that returns the stored [ReportDto] and a
/// [watchAll] snapshot stream ordered newest-first for the admin reports view
/// (R6.8, R12.6). The repository implementation layers the retry policy and
/// domain mapping on top; this source speaks only DTOs and Firebase types.
@injectable
class FirestoreReportDataSource extends FirestoreDataSource {
  FirestoreReportDataSource(super.firestore);

  /// The name of the Firestore collection backing reports.
  static const String collectionName = 'reports';

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(collectionName);

  /// Writes [dto] to the `reports` collection and returns the stored DTO.
  ///
  /// When [dto] carries a non-empty [ReportDto.reportId] that id is used as the
  /// document id; otherwise Firestore generates one and the generated id is
  /// reflected back on the returned DTO so callers can map it to the entity.
  Future<ReportDto> submit(ReportDto dto) async {
    final DocumentReference<Map<String, dynamic>> ref =
        dto.reportId.isEmpty ? _collection.doc() : _collection.doc(dto.reportId);
    await ref.set(dto.toFirestore());
    return ReportDto(
      reportId: ref.id,
      submitterId: dto.submitterId,
      submitterRole: dto.submitterRole,
      category: dto.category,
      description: dto.description,
      createdAt: dto.createdAt,
    );
  }

  /// Streams every report, newest first, as DTOs.
  Stream<List<ReportDto>> watchAll() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(ReportDto.fromFirestore)
              .toList(growable: false),
        );
  }
}

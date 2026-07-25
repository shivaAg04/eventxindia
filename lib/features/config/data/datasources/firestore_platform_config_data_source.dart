import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../../domain/repositories/platform_config_repository.dart';

/// The Firestore collection + document holding platform configuration.
const String kConfigCollection = 'config';
const String kPlatformConfigDoc = 'platform';

/// The document field storing the commission percentage.
const String kCommissionPercentField = 'commissionPercent';

/// Cloud Firestore data source for the single `config/platform` document.
///
/// Reads default to [kDefaultCommissionPercent] when the document or field is
/// absent, so the platform behaves as a 10% commission until an admin sets it.
/// Speaks only plain Dart ints — Firebase types stay confined here.
@injectable
class FirestorePlatformConfigDataSource extends FirestoreDataSource {
  const FirestorePlatformConfigDataSource(super.firestore);

  DocumentReference<Map<String, dynamic>> get _doc =>
      firestore.collection(kConfigCollection).doc(kPlatformConfigDoc);

  int _read(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final Object? value = snapshot.data()?[kCommissionPercentField];
    if (value is num) {
      return value.toInt();
    }
    return kDefaultCommissionPercent;
  }

  /// Streams the configured commission percentage (default when unset).
  Stream<int> watchCommissionPercent() => _doc.snapshots().map(_read);

  /// Reads the commission percentage once (default when unset).
  Future<int> getCommissionPercent() async => _read(await _doc.get());

  /// Persists [percent] as the current commission percentage.
  Future<void> setCommissionPercent(int percent) async {
    await _doc.set(
      <String, dynamic>{kCommissionPercentField: percent},
      SetOptions(merge: true),
    );
  }
}

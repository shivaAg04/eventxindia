import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/data/firebase_data_source.dart';
import '../dtos/staff_dto.dart';

/// The Firestore collection that stores vendor staff members.
const String kStaffCollection = 'staff';

/// Cloud Firestore data source for the `staff` collection.
///
/// Each document id is the composite key `"{vendorId}_{phone}"` so a vendor has
/// at most one staff entry per phone. Speaks [StaffDto] only — Firebase types
/// stay confined here and in the DTO.
@injectable
class FirestoreStaffDataSource extends FirestoreDataSource {
  const FirestoreStaffDataSource(super.firestore);

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(kStaffCollection);

  /// Creates the staff document for [dto], failing if one with the same
  /// composite id already exists (dedupe by phone within the vendor).
  Future<StaffDto> create(StaffDto dto) async {
    final DocumentReference<Map<String, dynamic>> ref =
        _collection.doc(dto.staffId);
    await firestore.runTransaction((Transaction txn) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await txn.get(ref);
      if (snapshot.exists) {
        throw StateError('Staff ${dto.staffId} already exists.');
      }
      txn.set(ref, dto.toFirestore());
    });
    final DocumentSnapshot<Map<String, dynamic>> stored =
        await ref.get();
    return StaffDto.fromFirestore(stored);
  }

  /// Deletes the staff document identified by [staffId].
  Future<void> delete(String staffId) => _collection.doc(staffId).delete();

  /// Streams every staff document owned by [vendorId].
  Stream<List<StaffDto>> watchByVendor(String vendorId) {
    return _collection
        .where('vendorId', isEqualTo: vendorId)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
            .map((doc) => StaffDto.fromFirestore(doc))
            .toList(growable: false));
  }

  /// Returns the staff invite whose phone matches [phoneE164] (any vendor), or
  /// `null` when none exists.
  Future<StaffDto?> findByPhone(String phoneE164) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _collection
        .where('phone', isEqualTo: phoneE164)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return null;
    }
    return StaffDto.fromFirestore(snap.docs.first);
  }

  /// Links [uid] to the staff invite matching [phoneE164] and provisions the
  /// `users/{uid}` staff record in a single batch. Returns the linked DTO, or
  /// `null` when no invite matches.
  Future<StaffDto?> provisionOnLogin({
    required String uid,
    required String phoneE164,
  }) async {
    final StaffDto? invite = await findByPhone(phoneE164);
    if (invite == null) {
      return null;
    }
    final WriteBatch batch = firestore.batch();
    batch.set(
      _collection.doc(invite.staffId),
      <String, dynamic>{'uid': uid, 'active': true},
      SetOptions(merge: true),
    );
    batch.set(
      firestore.collection('users').doc(uid),
      <String, dynamic>{
        'uid': uid,
        'role': 'staff',
        'vendorId': invite.vendorId,
        'staffRole': invite.role,
        'phone': invite.phone,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return StaffDto(
      staffId: invite.staffId,
      vendorId: invite.vendorId,
      name: invite.name,
      phone: invite.phone,
      role: invite.role,
      uid: uid,
      active: true,
      createdAt: invite.createdAt,
    );
  }
}

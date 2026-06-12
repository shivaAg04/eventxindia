import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../../domain/entities/vendor.dart';

/// Firebase data-transfer object for a `vendors/{uid}` document.
///
/// This is the only place Firebase types (`DocumentSnapshot`, `Timestamp`)
/// touch the [Vendor] shape. The DTO parses a Firestore document into plain
/// Dart fields ([fromFirestore]), serialises back to a Firestore-ready map
/// ([toFirestore]), and converts to/from the pure domain [Vendor] entity
/// ([toEntity]/[VendorDto.fromEntity]) — mapping the `approvalStatus`
/// wire-name to/from [ApprovalStatus], the `phone` string to/from
/// [PhoneNumber], and Firestore `Timestamp`s to/from [DateTime]. Optional
/// fields (`aadhaarOrPan`, `website`, `socialLinks`) are persisted only when
/// present (R2.7).
class VendorDto {
  const VendorDto({
    required this.uid,
    required this.fullName,
    required this.agencyName,
    required this.phone,
    required this.city,
    required this.address,
    required this.approvalStatus,
    required this.createdAt,
    required this.updatedAt,
    this.aadhaarOrPan,
    this.website,
    this.socialLinks = const <String>[],
  });

  /// The vendor's unique identifier (matches the document id).
  final String uid;

  /// The vendor's full name.
  final String fullName;

  /// The vendor's agency name.
  final String agencyName;

  /// The vendor's phone number in canonical string form.
  final String phone;

  /// The vendor's city.
  final String city;

  /// The vendor's address.
  final String address;

  /// The vendor's approval status wire-name (`Pending` | `Approved` |
  /// `Rejected`).
  final String approvalStatus;

  /// The vendor's optional Aadhaar/PAN identifier.
  final String? aadhaarOrPan;

  /// The vendor's optional website.
  final String? website;

  /// The vendor's optional social links.
  final List<String> socialLinks;

  /// When the profile was created.
  final DateTime createdAt;

  /// When the profile was last updated.
  final DateTime updatedAt;

  /// Parses a Firestore `vendors/{uid}` document into a [VendorDto].
  factory VendorDto.fromFirestore(DocumentSnapshot<Object?> doc) {
    final Map<String, dynamic> data = doc.data()! as Map<String, dynamic>;
    return VendorDto(
      uid: data['uid'] as String? ?? doc.id,
      fullName: data['fullName'] as String,
      agencyName: data['agencyName'] as String,
      phone: data['phone'] as String,
      city: data['city'] as String,
      address: data['address'] as String,
      approvalStatus: data['approvalStatus'] as String,
      aadhaarOrPan: data['aadhaarOrPan'] as String?,
      website: data['website'] as String?,
      socialLinks:
          (data['socialLinks'] as List<dynamic>?)?.cast<String>() ??
              const <String>[],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Builds a DTO from a pure domain [Vendor] entity (outbound mapping).
  factory VendorDto.fromEntity(Vendor vendor) {
    return VendorDto(
      uid: vendor.uid,
      fullName: vendor.fullName,
      agencyName: vendor.agencyName,
      phone: vendor.phone.e164,
      city: vendor.city,
      address: vendor.address,
      approvalStatus: vendor.approvalStatus.wireName,
      aadhaarOrPan: vendor.aadhaarOrPan,
      website: vendor.website,
      socialLinks: vendor.socialLinks,
      createdAt: vendor.createdAt,
      updatedAt: vendor.updatedAt,
    );
  }

  /// Serialises this DTO to a Firestore-ready map (Firebase `Timestamp`s).
  ///
  /// Optional fields are written only when present so absent optionals leave
  /// no key in the document (R2.7).
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'uid': uid,
      'fullName': fullName,
      'agencyName': agencyName,
      'phone': phone,
      'city': city,
      'address': address,
      'approvalStatus': approvalStatus,
      if (aadhaarOrPan != null) 'aadhaarOrPan': aadhaarOrPan,
      if (website != null) 'website': website,
      if (socialLinks.isNotEmpty) 'socialLinks': socialLinks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Converts this DTO to a pure domain [Vendor] entity (inbound mapping).
  Vendor toEntity() {
    return Vendor(
      uid: uid,
      fullName: fullName,
      agencyName: agencyName,
      phone: PhoneNumber.parse(phone),
      city: city,
      address: address,
      approvalStatus: ApprovalStatusX.parse(approvalStatus),
      aadhaarOrPan: aadhaarOrPan,
      website: website,
      socialLinks: socialLinks,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

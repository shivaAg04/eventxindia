import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/phone_number.dart';

/// A registered vendor's profile (R2.6–R2.9).
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only ([DateTime], [PhoneNumber], [ApprovalStatus]), so it is
/// unaffected by a future change of backend. Required field bounds (full name
/// 1..100, agency name 1..150, city 1..100, address 1..250) are enforced by
/// the registration validator and use case rather than by this value holder.
///
/// A newly created vendor defaults to [ApprovalStatus.pending] (R2.9); the
/// [Vendor.create] factory enforces this. The optional [aadhaarOrPan],
/// [website], and [socialLinks] fields are stored only when provided (R2.7).
class Vendor extends Equatable {
  const Vendor({
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

  /// Creates a brand-new vendor profile with approval status defaulting to
  /// [ApprovalStatus.pending] (R2.9).
  ///
  /// The [createdAt] and [updatedAt] timestamps are both initialised to [now].
  factory Vendor.create({
    required String uid,
    required String fullName,
    required String agencyName,
    required PhoneNumber phone,
    required String city,
    required String address,
    required DateTime now,
    String? aadhaarOrPan,
    String? website,
    List<String> socialLinks = const <String>[],
  }) {
    return Vendor(
      uid: uid,
      fullName: fullName,
      agencyName: agencyName,
      phone: phone,
      city: city,
      address: address,
      approvalStatus: ApprovalStatus.pending,
      createdAt: now,
      updatedAt: now,
      aadhaarOrPan: aadhaarOrPan,
      website: website,
      socialLinks: socialLinks,
    );
  }

  /// The vendor's unique identifier (matches the authenticated user's uid).
  final String uid;

  /// The vendor's full name (expected 1..100 characters).
  final String fullName;

  /// The vendor's agency name (expected 1..150 characters).
  final String agencyName;

  /// The vendor's phone number (expected exactly 10 national digits).
  final PhoneNumber phone;

  /// The vendor's city (expected 1..100 characters).
  final String city;

  /// The vendor's address (expected 1..250 characters).
  final String address;

  /// The vendor's approval status; defaults to [ApprovalStatus.pending] on
  /// creation and is mutable only by an admin / trusted backend (R2.9, R6.1).
  final ApprovalStatus approvalStatus;

  /// The vendor's optional Aadhaar or PAN identifier (R2.7).
  final String? aadhaarOrPan;

  /// The vendor's optional website (R2.7).
  final String? website;

  /// The vendor's optional social links; empty when none provided (R2.7).
  final List<String> socialLinks;

  /// When the profile was created.
  final DateTime createdAt;

  /// When the profile was last updated.
  final DateTime updatedAt;

  /// Returns a copy of this vendor with the given fields replaced.
  Vendor copyWith({
    String? fullName,
    String? agencyName,
    PhoneNumber? phone,
    String? city,
    String? address,
    ApprovalStatus? approvalStatus,
    String? aadhaarOrPan,
    String? website,
    List<String>? socialLinks,
    DateTime? updatedAt,
  }) {
    return Vendor(
      uid: uid,
      fullName: fullName ?? this.fullName,
      agencyName: agencyName ?? this.agencyName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aadhaarOrPan: aadhaarOrPan ?? this.aadhaarOrPan,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        uid,
        fullName,
        agencyName,
        phone,
        city,
        address,
        approvalStatus,
        aadhaarOrPan,
        website,
        socialLinks,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() => 'Vendor('
      'uid: $uid, '
      'fullName: $fullName, '
      'agencyName: $agencyName, '
      'phone: $phone, '
      'city: $city, '
      'address: $address, '
      'approvalStatus: $approvalStatus, '
      'aadhaarOrPan: $aadhaarOrPan, '
      'website: $website, '
      'socialLinks: $socialLinks, '
      'createdAt: $createdAt, '
      'updatedAt: $updatedAt)';
}

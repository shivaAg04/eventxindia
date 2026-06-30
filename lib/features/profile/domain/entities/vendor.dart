import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/phone_number.dart';

/// A registered vendor's profile (R2.6–R2.9).
///
/// Pure domain entity (no backend types). Field bounds and the optional
/// [aadhaarOrPan]/[website]/[socialLinks] (R2.7) are enforced by the validator,
/// not here. New vendors default to [ApprovalStatus.pending] via [Vendor.create]
/// and are mutable only by an admin / trusted backend (R2.9, R6.1).
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

  /// Creates a brand-new vendor with [ApprovalStatus.pending] (R2.9), stamping
  /// both timestamps with [now].
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

  final String uid;
  final String fullName;
  final String agencyName;
  final PhoneNumber phone;
  final String city;
  final String address;

  /// Approval status; defaults to pending and is admin-mutable only (R2.9, R6.1).
  final ApprovalStatus approvalStatus;

  /// Optional fields, persisted only when provided (R2.7).
  final String? aadhaarOrPan;
  final String? website;
  final List<String> socialLinks;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Returns a copy with [approvalStatus] and/or [updatedAt] replaced — used by
  /// the admin approval flow (R6.1).
  Vendor copyWith({ApprovalStatus? approvalStatus, DateTime? updatedAt}) {
    return Vendor(
      uid: uid,
      fullName: fullName,
      agencyName: agencyName,
      phone: phone,
      city: city,
      address: address,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      aadhaarOrPan: aadhaarOrPan,
      website: website,
      socialLinks: socialLinks,
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
}

import 'package:equatable/equatable.dart';

/// The role of the user who submitted a [Report].
///
/// A report may originate from either a student or a vendor. The submitter's
/// role determines which [ReportCategory] values are permissible (R12.1,
/// R12.2): students may file [ReportCategory.fakeEvent] or
/// [ReportCategory.vendorIssue]; vendors may file [ReportCategory.noShow] or
/// [ReportCategory.misbehavior]. Any value outside this set is rejected at the
/// boundary via [SubmitterRoleX.parse].
enum SubmitterRole {
  student,
  vendor;

  /// The canonical wire/storage representation, e.g. `"student"`.
  String get wireName {
    switch (this) {
      case SubmitterRole.student:
        return 'student';
      case SubmitterRole.vendor:
        return 'vendor';
    }
  }
}

/// Parsing helpers that enforce validity for [SubmitterRole] at the boundary.
extension SubmitterRoleX on SubmitterRole {
  /// Parses a wire/storage string into a [SubmitterRole].
  ///
  /// Accepts exactly `student` or `vendor`. Throws an [ArgumentError] for any
  /// unknown value.
  static SubmitterRole parse(String value) {
    for (final role in SubmitterRole.values) {
      if (role.wireName == value) {
        return role;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown SubmitterRole');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static SubmitterRole? tryParse(String value) {
    for (final role in SubmitterRole.values) {
      if (role.wireName == value) {
        return role;
      }
    }
    return null;
  }
}

/// The category of an issue described by a [Report].
///
/// Categories are partitioned by the role permitted to use them:
/// [fakeEvent] and [vendorIssue] are student-only categories (R12.1), while
/// [noShow] and [misbehavior] are vendor-only categories (R12.2). The set of
/// categories allowed for a given [SubmitterRole] is exposed via
/// [ReportCategoryX.allowedFor]; any category outside that set must be rejected
/// by the report validator (R12.3).
enum ReportCategory {
  /// A student's report that an event was fake.
  fakeEvent,

  /// A student's report of an issue with a vendor.
  vendorIssue,

  /// A vendor's report that a student did not show up.
  noShow,

  /// A vendor's report of student misbehavior.
  misbehavior;

  /// The canonical wire/storage representation, e.g. `"FakeEvent"`.
  String get wireName {
    switch (this) {
      case ReportCategory.fakeEvent:
        return 'FakeEvent';
      case ReportCategory.vendorIssue:
        return 'VendorIssue';
      case ReportCategory.noShow:
        return 'NoShow';
      case ReportCategory.misbehavior:
        return 'Misbehavior';
    }
  }
}

/// Parsing and role-permission helpers for [ReportCategory].
extension ReportCategoryX on ReportCategory {
  /// The categories permitted for a submitter with the given [role] (R12.1,
  /// R12.2).
  static List<ReportCategory> allowedFor(SubmitterRole role) {
    switch (role) {
      case SubmitterRole.student:
        return const <ReportCategory>[
          ReportCategory.fakeEvent,
          ReportCategory.vendorIssue,
        ];
      case SubmitterRole.vendor:
        return const <ReportCategory>[
          ReportCategory.noShow,
          ReportCategory.misbehavior,
        ];
    }
  }

  /// Whether this category may be submitted by a user with the given [role].
  bool isAllowedFor(SubmitterRole role) => allowedFor(role).contains(this);

  /// Parses a wire/storage string into a [ReportCategory].
  ///
  /// Accepts exactly `FakeEvent`, `VendorIssue`, `NoShow`, or `Misbehavior`.
  /// Throws an [ArgumentError] for any unknown value.
  static ReportCategory parse(String value) {
    for (final category in ReportCategory.values) {
      if (category.wireName == value) {
        return category;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown ReportCategory');
  }

  /// Parses [value], returning `null` instead of throwing for unknown input.
  static ReportCategory? tryParse(String value) {
    for (final category in ReportCategory.values) {
      if (category.wireName == value) {
        return category;
      }
    }
    return null;
  }
}

/// A record submitted by a student or vendor describing an issue for admin
/// review (R12).
///
/// A report captures who raised it ([submitterId] and [submitterRole]), the
/// [category] of the issue, a free-text [description] (expected 1..1000
/// characters), and a [createdAt] timestamp. The role/category compatibility
/// rule (R12.1–12.3) and the description-length rule (R12.4) are enforced by
/// the report validator and submit use case rather than by this value holder.
///
/// This is a pure domain entity: it carries no backend types and uses plain
/// Dart values only, so it is unaffected by a future change of backend.
class Report extends Equatable {
  const Report({
    required this.reportId,
    required this.submitterId,
    required this.submitterRole,
    required this.category,
    required this.description,
    required this.createdAt,
  });

  /// The maximum permitted length of a report [description] (R12.4).
  static const int maxDescriptionLength = 1000;

  /// The report's unique identifier.
  final String reportId;

  /// The id of the user who submitted the report.
  final String submitterId;

  /// The role of the submitting user (student or vendor).
  final SubmitterRole submitterRole;

  /// The category of issue being reported.
  final ReportCategory category;

  /// The free-text description of the issue (expected 1..1000 characters).
  final String description;

  /// When the report was created.
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[
        reportId,
        submitterId,
        submitterRole,
        category,
        description,
        createdAt,
      ];

  @override
  String toString() => 'Report('
      'reportId: $reportId, '
      'submitterId: $submitterId, '
      'submitterRole: $submitterRole, '
      'category: $category, '
      'description: $description, '
      'createdAt: $createdAt)';
}

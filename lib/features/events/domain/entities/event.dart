import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/approval_status.dart';
import '../../../../core/value_objects/event_status.dart';
import '../../../../core/value_objects/money.dart';
import '../event_finance.dart';
import 'event_location.dart';

/// A gig posted by a vendor that students can discover and apply to.
///
/// An event is owned by the vendor identified by [vendorId] and starts life in
/// [EventStatus.active] on creation (R7.6); it may later transition to
/// [EventStatus.closed] or [EventStatus.completed]. It carries scheduling
/// details ([date], [startTime], [endTime]), a capacity ([slots]), a
/// pay-per-head amount as [Money], and an [EventLocation] used for attendance
/// distance checks. The optional [startCode] / [endCode] are the attendance
/// codes set when a vendor generates them (R5.6, R10.2, R10.7).
///
/// This is a pure domain entity: it holds only plain Dart values and the
/// project's value objects, so no backend type ever crosses the domain
/// boundary and the entity is unaffected by a future change of backend.
class Event extends Equatable {
  const Event({
    required this.eventId,
    required this.vendorId,
    required this.title,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.location,
    required this.slots,
    required this.payPerHead,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.startCode,
    this.endCode,
    this.approvedCount = 0,
    this.platformCommissionPercent = 10,
    this.approvalStatus = ApprovalStatus.approved,
  });

  /// The maximum number of characters allowed in a [title].
  static const int maxTitleLength = 100;

  /// The maximum number of characters allowed in a [description].
  static const int maxDescriptionLength = 2000;

  /// The smallest valid value for [slots].
  static const int minSlots = 1;

  /// The largest valid value for [slots].
  static const int maxSlots = 10000;

  /// The unique identifier of the event (the persistence document id).
  final String eventId;

  /// The id of the owning vendor (R5.9, R7.x).
  final String vendorId;

  /// The event title, 1..[maxTitleLength] characters.
  final String title;

  /// The event description, 1..[maxDescriptionLength] characters.
  final String description;

  /// The calendar date on which the event takes place.
  final DateTime date;

  /// The scheduled start time of the event.
  final DateTime startTime;

  /// The scheduled end time of the event; must be later than [startTime].
  final DateTime endTime;

  /// Where the event takes place: a label plus a geographic coordinate.
  final EventLocation location;

  /// The number of student slots available, an integer in
  /// [minSlots]..[maxSlots].
  final int slots;

  /// The amount paid per attending student.
  final Money payPerHead;

  /// The current lifecycle status; [EventStatus.active] on creation (R7.6).
  final EventStatus status;

  /// The admin moderation gate, **separate from the lifecycle [status]**. A new
  /// event is created [ApprovalStatus.pending] and stays invisible to students
  /// until an admin sets it to [ApprovalStatus.approved]; the admin may instead
  /// [ApprovalStatus.rejected] it. Only approved events appear in student
  /// discovery. Defaults to [ApprovalStatus.approved] so events created before
  /// this gate existed remain published.
  final ApprovalStatus approvalStatus;

  /// Whether this event is published — admin-approved and therefore visible to
  /// students. The single predicate used to gate student discovery.
  bool get isPublished => approvalStatus == ApprovalStatus.approved;

  /// The number of applications a vendor has approved for this event. Starts at
  /// 0 and is incremented as the owning vendor approves applicants; it can never
  /// exceed [slots] (capacity is enforced when approving).
  final int approvedCount;

  /// The platform commission percentage (the admin's cut) **snapshotted at
  /// creation** from the current platform config. Because it lives on the event,
  /// a later change to the platform-wide rate never affects this (or any past)
  /// event. Defaults to 10 for events created before this field existed.
  final int platformCommissionPercent;

  /// What a student actually takes home per head: the pay-per-head net of the
  /// event's snapshotted [platformCommissionPercent] (e.g. ₹100 at 10% ⇒ ₹90).
  ///
  /// This is the amount shown to students everywhere they view the pay — they
  /// see the net, while vendors and the admin see the gross pay they fund. Uses
  /// the canonical [splitCommission] rule so it always matches wallet credits.
  Money get studentNetPayPerHead => Money.fromMinorUnits(
        splitCommission(payPerHead.minorUnits, platformCommissionPercent)
            .studentNetMinor,
        requirePayPerHeadRange: false,
      );

  /// The number of unfilled slots remaining (never negative).
  int get seatsRemaining =>
      (slots - approvedCount) < 0 ? 0 : slots - approvedCount;

  /// Whether every slot has been filled by an approved applicant.
  bool get isFull => approvedCount >= slots;

  /// The attendance check-in code, set when the owning vendor generates it
  /// (R5.6, R10.2). `null` until generated.
  final String? startCode;

  /// The attendance check-out code, set when the owning vendor generates it
  /// (R5.6, R10.7). `null` until generated.
  final String? endCode;

  /// When the event was created.
  final DateTime createdAt;

  /// When the event was last updated.
  final DateTime updatedAt;

  /// Returns a copy of this event with the given fields replaced.
  ///
  /// Note that nullable code fields cannot be cleared via [copyWith]; passing
  /// `null` leaves the existing value unchanged. Use the dedicated repository
  /// `setCode` operation to set attendance codes.
  Event copyWith({
    String? title,
    String? description,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    EventLocation? location,
    int? slots,
    Money? payPerHead,
    EventStatus? status,
    String? startCode,
    String? endCode,
    DateTime? updatedAt,
    int? approvedCount,
    int? platformCommissionPercent,
    ApprovalStatus? approvalStatus,
  }) {
    return Event(
      eventId: eventId,
      vendorId: vendorId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      slots: slots ?? this.slots,
      payPerHead: payPerHead ?? this.payPerHead,
      status: status ?? this.status,
      startCode: startCode ?? this.startCode,
      endCode: endCode ?? this.endCode,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedCount: approvedCount ?? this.approvedCount,
      platformCommissionPercent:
          platformCommissionPercent ?? this.platformCommissionPercent,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        eventId,
        vendorId,
        title,
        description,
        date,
        startTime,
        endTime,
        location,
        slots,
        payPerHead,
        status,
        startCode,
        endCode,
        createdAt,
        updatedAt,
        approvedCount,
        platformCommissionPercent,
        approvalStatus,
      ];

  @override
  String toString() => 'Event('
      'eventId: $eventId, '
      'vendorId: $vendorId, '
      'title: $title, '
      'status: $status, '
      'slots: $slots, '
      'payPerHead: $payPerHead, '
      'startCode: $startCode, '
      'endCode: $endCode)';
}

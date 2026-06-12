import 'package:equatable/equatable.dart';

import '../../../../core/value_objects/event_status.dart';
import '../../../../core/value_objects/money.dart';
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

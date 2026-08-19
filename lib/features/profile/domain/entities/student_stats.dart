import 'package:equatable/equatable.dart';

/// A student's aggregated track record, shown to a vendor reviewing them as an
/// applicant (R5.3, R5.4).
///
/// A pure domain entity carrying two counters:
/// * [eventsParticipated] — how many events are on the student's record.
/// * [attendanceCompleted] — how many of those they actually worked, i.e. have
///   an attendance record with both a check-in and a check-out.
///
/// Exactly which events land in [eventsParticipated] is the wired
/// [StudentStatsService] implementation's decision: the client-side
/// `AttendanceDerivedStudentStatsService` counts events the student turned up
/// to, while the trusted `FirestoreStudentStatsService` counts events they were
/// approved for (so a ghosted event lowers the rate).
///
/// Both counts are integers of zero or greater; validity is enforced at
/// construction so a [StudentStats] value can never represent a negative count.
///
/// The entity itself is source-agnostic: it says nothing about where the numbers
/// came from, so the app can move between an in-app derivation and a trusted
/// server-side aggregate without any change here or in the screens that show it.
class StudentStats extends Equatable {
  /// Creates a [StudentStats] value, asserting both counts are non-negative.
  ///
  /// Throws an [ArgumentError] if [eventsParticipated] or
  /// [attendanceCompleted] is negative.
  StudentStats({
    required this.studentId,
    required this.eventsParticipated,
    required this.attendanceCompleted,
  }) {
    _checkNonNegative('eventsParticipated', eventsParticipated);
    _checkNonNegative('attendanceCompleted', attendanceCompleted);
  }

  /// The student the counters belong to.
  final String studentId;

  /// The number of events on the student's record (>= 0). See the class doc for
  /// which events count under each implementation.
  final int eventsParticipated;

  /// The number of events the student completed attendance for — both a
  /// check-in and a check-out recorded (>= 0).
  final int attendanceCompleted;

  /// A [StudentStats] with both counts at zero, used before the trusted
  /// aggregator has written anything for this student (a new student, or a
  /// student with no approved applications yet).
  static StudentStats zeroFor(String studentId) => StudentStats(
        studentId: studentId,
        eventsParticipated: 0,
        attendanceCompleted: 0,
      );

  /// Whether the student has any recorded history at all.
  ///
  /// Lets the UI distinguish "no track record yet" from a genuine zero score.
  bool get isEmpty => eventsParticipated == 0 && attendanceCompleted == 0;

  static void _checkNonNegative(String name, int value) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'must be zero or greater');
    }
  }

  @override
  List<Object?> get props => <Object?>[
        studentId,
        eventsParticipated,
        attendanceCompleted,
      ];

  @override
  String toString() => 'StudentStats(studentId: $studentId, '
      'eventsParticipated: $eventsParticipated, '
      'attendanceCompleted: $attendanceCompleted)';
}

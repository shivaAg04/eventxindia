import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../attendance/domain/usecases/generate_attendance_code.dart';
import '../../domain/entities/application.dart';
import '../../domain/usecases/apply_to_event.dart';
import '../../domain/usecases/decide_application.dart';
import '../../domain/usecases/watch_event_applications.dart';
import 'application_event.dart';
import 'application_state.dart';

/// Drives the application lifecycle for both students and vendors.
///
/// The bloc depends only on injected use cases — [ApplyToEvent],
/// [DecideApplication], [WatchEventApplications], and [GenerateAttendanceCode]
/// — so it carries no backend type and stays backend-agnostic.
///
/// Event → state mapping (see design BLoC table):
/// - [ApplyRequested] → `[Applying, Applied]` on success, `[Applying,
///   DuplicateApplication]` when the student already applied (R9.2), or
///   `[Applying, ApplicationFailure]` otherwise (e.g. event not Active, R8.7).
/// - [DecideRequested] → `[ApplicationFailure]` when the vendor does not own
///   the event (R5.9) or the application is not Pending (R5.8, R9.5); the
///   applicant-list stream re-emits the updated [ApplicationsLoaded] on
///   success.
/// - [ApplicationsWatchStarted] → a fresh [ApplicationsLoaded] for every change
///   to the event's applications (R5.3).
/// - [AttendanceCodeRequested] → [AttendanceCodeGenerated] on success or
///   [ApplicationFailure] on a non-owner request (R5.6, R5.9).
@injectable
class ApplicationBloc extends Bloc<ApplicationEvent, ApplicationState> {
  ApplicationBloc({
    required ApplyToEvent applyToEvent,
    required DecideApplication decideApplication,
    required WatchEventApplications watchEventApplications,
    required GenerateAttendanceCode generateAttendanceCode,
  })  : _applyToEvent = applyToEvent,
        _decideApplication = decideApplication,
        _watchEventApplications = watchEventApplications,
        _generateAttendanceCode = generateAttendanceCode,
        super(const ApplicationInitial()) {
    on<ApplyRequested>(_onApplyRequested);
    on<DecideRequested>(_onDecideRequested);
    on<ApplicationsWatchStarted>(_onApplicationsWatchStarted);
    on<AttendanceCodeRequested>(_onAttendanceCodeRequested);
  }

  final ApplyToEvent _applyToEvent;
  final DecideApplication _decideApplication;
  final WatchEventApplications _watchEventApplications;
  final GenerateAttendanceCode _generateAttendanceCode;

  Future<void> _onApplyRequested(
    ApplyRequested event,
    Emitter<ApplicationState> emit,
  ) async {
    emit(const Applying());

    final Result<Application, Failure> result = await _applyToEvent(
      studentId: event.studentId,
      eventId: event.eventId,
    );

    emit(
      result.fold<ApplicationState>(
        Applied.new,
        (Failure failure) => _isDuplicate(failure)
            ? DuplicateApplication(failure)
            : ApplicationFailure(failure),
      ),
    );
  }

  Future<void> _onDecideRequested(
    DecideRequested event,
    Emitter<ApplicationState> emit,
  ) async {
    final Result<Application, Failure> result = await _decideApplication(
      vendorId: event.vendorId,
      applicationId: event.applicationId,
      decision: event.decision,
    );

    // On success the watched applicant-list stream re-emits the updated list;
    // only a failure needs to be surfaced here so it can be shown to the
    // vendor without tearing down the applicant list (R5.8, R5.9, R9.5).
    if (result.isErr) {
      emit(ApplicationFailure(result.failureOrNull!));
    }
  }

  Future<void> _onApplicationsWatchStarted(
    ApplicationsWatchStarted event,
    Emitter<ApplicationState> emit,
  ) {
    return emit.forEach<List<Application>>(
      _watchEventApplications(eventId: event.eventId),
      onData: ApplicationsLoaded.new,
      onError: (Object error, StackTrace _) => ApplicationFailure(
        PersistenceFailure(message: 'Failed to load applications: $error'),
      ),
    );
  }

  Future<void> _onAttendanceCodeRequested(
    AttendanceCodeRequested event,
    Emitter<ApplicationState> emit,
  ) async {
    final Result<String, Failure> result = await _generateAttendanceCode(
      vendorId: event.vendorId,
      eventId: event.eventId,
      kind: event.kind,
    );

    emit(
      result.fold<ApplicationState>(
        (String code) => AttendanceCodeGenerated(code, event.kind),
        ApplicationFailure.new,
      ),
    );
  }

  /// Whether [failure] represents a duplicate-application rejection (R9.2).
  ///
  /// The repository signals a duplicate with a [StateTransitionFailure] whose
  /// message identifies the already-applied condition; this distinguishes it
  /// from the event-not-Active rejection (R8.7), which is surfaced as a generic
  /// [ApplicationFailure].
  bool _isDuplicate(Failure failure) =>
      failure is StateTransitionFailure &&
      failure.message.toLowerCase().contains('already applied');
}

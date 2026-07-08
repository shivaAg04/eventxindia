import 'package:equatable/equatable.dart';

import '../../../../core/error/failure.dart';
import '../../../events/domain/repositories/event_repository.dart';
import '../../domain/entities/application.dart';

/// Base type for every state emitted by the `ApplicationBloc`.
sealed class ApplicationState extends Equatable {
  const ApplicationState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The initial state before any event has been handled.
class ApplicationInitial extends ApplicationState {
  const ApplicationInitial();
}

/// An apply request is in flight (R8.6).
class Applying extends ApplicationState {
  const Applying();
}

/// A student's application was created successfully in Pending status (R8.6,
/// R9.1).
class Applied extends ApplicationState {
  const Applied(this.application);

  /// The newly created application.
  final Application application;

  @override
  List<Object?> get props => <Object?>[application];
}

/// An application by the same student for the same event already exists; the
/// existing record is left unchanged (R9.2).
class DuplicateApplication extends ApplicationState {
  const DuplicateApplication(this.failure);

  /// The failure describing the duplicate.
  final Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

/// The current list of applications for the watched event (R5.3).
///
/// Carries an empty list when no applications exist, backing the applicant
/// list's empty-state indication.
class ApplicationsLoaded extends ApplicationState {
  const ApplicationsLoaded(this.applications);

  /// The applications for the watched event, possibly empty.
  final List<Application> applications;

  @override
  List<Object?> get props => <Object?>[applications];
}

/// An attendance code was generated and stored for an event (R5.6).
class AttendanceCodeGenerated extends ApplicationState {
  const AttendanceCodeGenerated(this.code, this.kind);

  /// The generated attendance code.
  final String code;

  /// Whether the code is the start (check-in) or end (check-out) code, so the
  /// UI can label and retain each code separately.
  final EventCodeKind kind;

  @override
  List<Object?> get props => <Object?>[code, kind];
}

/// A generic failure state for apply/decide/code-generation actions.
///
/// Surfaces authorization denials on non-owned events (R5.9), Pending-only
/// transition violations (R5.8, R9.5), and persistence errors. The wrapped
/// [failure] carries the machine-readable code and human-readable message.
class ApplicationFailure extends ApplicationState {
  const ApplicationFailure(this.failure);

  /// The underlying failure.
  final Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}

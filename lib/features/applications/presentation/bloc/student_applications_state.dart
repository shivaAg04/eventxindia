part of 'student_applications_cubit.dart';

/// Base type for all [StudentApplicationsCubit] states rendered by the
/// student dashboard's applied/approved lists.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine change and tests can assert exact emission sequences.
sealed class StudentApplicationsState extends Equatable {
  const StudentApplicationsState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The application stream is being established.
final class StudentApplicationsLoading extends StudentApplicationsState {
  const StudentApplicationsLoading();
}

/// Applications (already filtered by the requested status, when any) are
/// available for display (R4.2, R4.3).
final class StudentApplicationsLoaded extends StudentApplicationsState {
  const StudentApplicationsLoaded(this.applications);

  /// The applications to render, in repository/stream order.
  final List<Application> applications;

  @override
  List<Object?> get props => <Object?>[applications];
}

/// No matching applications exist; the screen shows an empty-state indication
/// (R4.2, R4.3).
final class StudentApplicationsEmpty extends StudentApplicationsState {
  const StudentApplicationsEmpty();
}

/// The application stream errored; the screen indicates the data could not be
/// loaded and leaves stored data unchanged (R4.7).
final class StudentApplicationsFailure extends StudentApplicationsState {
  const StudentApplicationsFailure(this.message);

  /// A human-readable description of why the list could not be loaded.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

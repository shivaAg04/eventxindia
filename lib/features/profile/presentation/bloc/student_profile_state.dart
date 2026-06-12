part of 'student_profile_cubit.dart';

/// Base type for all [StudentProfileCubit] states rendered by the profile view.
///
/// States are compared by [Equatable] so the widget layer rebuilds only on a
/// genuine change and tests can assert exact emission sequences.
sealed class StudentProfileState extends Equatable {
  const StudentProfileState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The profile is being read.
final class StudentProfileLoading extends StudentProfileState {
  const StudentProfileLoading();
}

/// The student's profile loaded successfully (R4.6).
final class StudentProfileLoaded extends StudentProfileState {
  const StudentProfileLoaded(this.student);

  /// The loaded student profile.
  final Student student;

  @override
  List<Object?> get props => <Object?>[student];
}

/// The profile read failed; the screen indicates the data could not be loaded
/// and leaves stored data unchanged (R4.7).
final class StudentProfileFailure extends StudentProfileState {
  const StudentProfileFailure(this.message);

  /// A human-readable description of why the profile could not be loaded.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

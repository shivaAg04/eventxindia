import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/value_objects/application_status.dart';
import '../../domain/entities/application.dart';
import '../../domain/usecases/watch_student_applications.dart';

part 'student_applications_state.dart';

/// Lightweight cubit backing the student dashboard's "applied" and "approved"
/// event lists (R4.2, R4.3, R4.7).
///
/// It subscribes to [WatchStudentApplications] for a student and emits the
/// current list of [Application]s, optionally filtered by an
/// [ApplicationStatus]. The "applied" list passes no filter (every submitted
/// application, R4.2); the "approved" list passes [ApplicationStatus.approved]
/// (R4.3). An empty result becomes [StudentApplicationsEmpty] so the screen can
/// show an empty-state indication, and a stream error becomes
/// [StudentApplicationsFailure] so the screen can indicate the data could not
/// be loaded without mutating any stored data (R4.7).
///
/// This is distinct from the existing `ApplicationBloc` (vendor-facing
/// applicant decisions); it depends only on the [WatchStudentApplications] use
/// case, never on a repository or backend type.
@injectable
class StudentApplicationsCubit extends Cubit<StudentApplicationsState> {
  /// Creates the cubit over the injected [WatchStudentApplications] use case.
  StudentApplicationsCubit(this._watchStudentApplications)
      : super(const StudentApplicationsLoading());

  final WatchStudentApplications _watchStudentApplications;

  StreamSubscription<List<Application>>? _subscription;

  /// Starts watching the applications submitted by [studentId].
  ///
  /// When [statusFilter] is non-null only applications with that status are
  /// retained (R4.3); otherwise every submitted application is shown (R4.2).
  void watch({required String studentId, ApplicationStatus? statusFilter}) {
    emit(const StudentApplicationsLoading());
    _subscription?.cancel();
    _subscription = _watchStudentApplications(studentId: studentId).listen(
      (List<Application> applications) {
        final List<Application> filtered = statusFilter == null
            ? applications
            : applications
                .where((Application a) => a.status == statusFilter)
                .toList(growable: false);
        if (filtered.isEmpty) {
          emit(const StudentApplicationsEmpty());
        } else {
          emit(StudentApplicationsLoaded(filtered));
        }
      },
      onError: (Object error, StackTrace _) =>
          emit(StudentApplicationsFailure(error.toString())),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

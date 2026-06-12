import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/profile_repository.dart';

part 'student_profile_state.dart';

/// Lightweight cubit backing the student dashboard's profile view (R4.6, R4.7).
///
/// It loads the [Student] profile for a uid through
/// [ProfileRepository.getStudent] and emits [StudentProfileLoaded] on success
/// or [StudentProfileFailure] when the read fails, in which case the screen
/// indicates the data could not be loaded and no stored data is mutated
/// (R4.7).
///
/// The profile view is a pure read, so this cubit depends on the
/// [ProfileRepository] read interface directly rather than introducing a new
/// use case; it carries no backend type.
@injectable
class StudentProfileCubit extends Cubit<StudentProfileState> {
  /// Creates the cubit over the injected [ProfileRepository].
  StudentProfileCubit(this._profileRepository)
      : super(const StudentProfileLoading());

  final ProfileRepository _profileRepository;

  /// Loads the profile for the student identified by [uid].
  Future<void> load(String uid) async {
    emit(const StudentProfileLoading());
    final Result<Student, Failure> result =
        await _profileRepository.getStudent(uid);
    emit(
      result.fold<StudentProfileState>(
        StudentProfileLoaded.new,
        (Failure failure) => StudentProfileFailure(failure.message),
      ),
    );
  }
}

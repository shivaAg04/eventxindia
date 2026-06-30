import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/student.dart';
import '../../domain/repositories/profile_repository.dart';

part 'student_profile_state.dart';

/// Backs the student dashboard's profile view (R4.6, R4.7): loads the [Student]
/// via [ProfileRepository.getStudent] and emits [StudentProfileLoaded] or, on a
/// failed read, [StudentProfileFailure] (no stored data is mutated, R4.7).
///
/// A pure read, so it uses the repository directly rather than a use case.
@injectable
class StudentProfileCubit extends Cubit<StudentProfileState> {
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

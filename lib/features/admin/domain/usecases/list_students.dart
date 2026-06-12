import '../../../profile/domain/entities/student.dart';
import '../repositories/admin_repository.dart';

/// Streams all registered students for the Admin student list (R6.4, R6.9).
///
/// Delegates to [AdminRepository.listStudents], emitting an empty list when no
/// students are registered so the presentation layer can show an empty-state
/// indication (R6.9). Depends only on the abstract [AdminRepository], so it
/// carries no backend types.
class ListStudents {
  const ListStudents(this._repository);

  final AdminRepository _repository;

  /// Returns the stream of registered students.
  Stream<List<Student>> call() => _repository.listStudents();
}

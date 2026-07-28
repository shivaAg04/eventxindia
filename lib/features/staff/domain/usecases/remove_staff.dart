import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/staff_repository.dart';

/// Removes a staff member from a vendor's roster.
class RemoveStaff {
  const RemoveStaff({required StaffRepository repository})
      : _repository = repository;

  final StaffRepository _repository;

  Future<Result<Unit, Failure>> call(String staffId) =>
      _repository.remove(staffId);
}

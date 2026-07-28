import '../entities/staff_member.dart';
import '../repositories/staff_repository.dart';

/// Streams the staff members belonging to a single vendor.
class WatchVendorStaff {
  const WatchVendorStaff({required StaffRepository repository})
      : _repository = repository;

  final StaffRepository _repository;

  Stream<List<StaffMember>> call(String vendorId) =>
      _repository.watchByVendor(vendorId);
}

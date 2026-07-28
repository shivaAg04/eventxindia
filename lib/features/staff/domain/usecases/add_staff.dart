import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../entities/staff_member.dart';
import '../entities/staff_role.dart';
import '../repositories/staff_repository.dart';

/// The raw form input a vendor supplies when adding a staff member.
class StaffInput {
  const StaffInput({
    required this.name,
    required this.rawPhone,
    required this.role,
  });

  /// The staff member's display name.
  final String name;

  /// The user-entered phone string (expected to be a 10-digit Indian number;
  /// normalised to `+91` E.164 on success).
  final String rawPhone;

  /// The chosen predefined role.
  final StaffRole role;
}

/// Adds a staff member to a vendor's roster.
///
/// Validates the [StaffInput] (non-empty name; a 10-digit phone), normalises
/// the phone to `+91` E.164, builds the [StaffMember], and persists it via
/// [StaffRepository.add]. A duplicate phone for the same vendor surfaces as the
/// repository's [StateTransitionFailure]. Field problems surface as a
/// [ValidationFailure] carrying [FieldError]s so the form can highlight them.
class AddStaff {
  const AddStaff({
    required StaffRepository repository,
    required DateTime Function() now,
  })  : _repository = repository,
        _now = now;

  final StaffRepository _repository;
  final DateTime Function() _now;

  static final RegExp _tenDigits = RegExp(r'^\d{10}$');

  Future<Result<StaffMember, Failure>> call({
    required String vendorId,
    required StaffInput input,
  }) {
    final List<FieldError> errors = <FieldError>[];
    final String name = input.name.trim();
    if (name.isEmpty) {
      errors.add(const FieldError(field: 'name', message: 'Enter a name.'));
    }
    final String digits = input.rawPhone.trim().replaceAll(RegExp(r'\s'), '');
    if (!_tenDigits.hasMatch(digits)) {
      errors.add(const FieldError(
        field: 'phone',
        message: 'Enter a valid 10-digit mobile number.',
      ));
    }

    if (errors.isNotEmpty) {
      return Future<Result<StaffMember, Failure>>.value(
        Result<StaffMember, Failure>.err(ValidationFailure(fieldErrors: errors)),
      );
    }

    final StaffMember staff = StaffMember.create(
      vendorId: vendorId,
      name: name,
      phone: '+91$digits',
      role: input.role,
      now: _now(),
    );
    return _repository.add(staff);
  }
}

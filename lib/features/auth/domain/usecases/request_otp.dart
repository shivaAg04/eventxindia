import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/value_objects/phone_number.dart';
import '../entities/otp_session.dart';
import '../entities/user_role.dart';
import '../repositories/auth_repository.dart';
import '../validators/phone_validator.dart';

/// Requests delivery of a one-time password for a login attempt
/// (R1.1, R1.5, R2.1, R2.2).
///
/// The use case is the orchestration boundary for the "request OTP" action:
///
/// 1. It validates the raw phone string against the format required for the
///    chosen [UserRole] using the pure [PhoneValidator] (R1.5, R2.2). Invalid
///    phones short-circuit with a [ValidationFailure] and the repository is
///    never asked to deliver an OTP.
/// 2. On a valid phone it delegates to [AuthRepository.requestOtp], which
///    delivers the OTP and rejects locked phones or exhausted-attempt phones
///    (R1.4, R2.5).
///
/// It depends only on the abstract [AuthRepository] (injected) and the pure
/// validator, so it carries no backend types and is unit/mock testable.
class RequestOtp {
  const RequestOtp(
    this._repository, {
    PhoneValidator validator = const PhoneValidator(),
  }) : _validator = validator;

  final AuthRepository _repository;
  final PhoneValidator _validator;

  /// Validates [rawPhone] for [role] and, if valid, asks the repository to
  /// deliver an OTP.
  ///
  /// Returns the in-flight [OtpSession] on success, a [ValidationFailure] when
  /// the phone format is invalid, or the repository's failure (e.g.
  /// [AuthFailure] for a locked phone) otherwise.
  Future<Result<OtpSession, Failure>> call({
    required String rawPhone,
    required UserRole role,
  }) async {
    final Result<PhoneNumber, Failure> validation =
        _validator(rawPhone, role);

    return switch (validation) {
      Err<PhoneNumber, Failure>(:final Failure failure) =>
        Result<OtpSession, Failure>.err(failure),
      Ok<PhoneNumber, Failure>(:final PhoneNumber value) =>
        await _repository.requestOtp(value),
    };
  }
}

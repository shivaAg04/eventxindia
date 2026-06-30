import '../../../../core/error/failure.dart';
import '../../../../core/result/result.dart';
import '../repositories/auth_repository.dart';

/// Signs the current user out, ending the session (R3.4).
///
/// A thin orchestration over [AuthRepository.signOut]: once the backend session
/// is cleared, [WatchSession] emits [Unauthenticated] and the role-based router
/// returns to the authentication screen. Keeping it behind a use case preserves
/// the dependency rule — the presentation layer depends only on the domain,
/// never on the [AuthRepository] implementation directly.
class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  /// Clears the session, returning [unit] on success or a [Failure].
  Future<Result<Unit, Failure>> call() => _repository.signOut();
}

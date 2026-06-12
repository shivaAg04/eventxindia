import '../error/failure.dart';
import '../result/result.dart';

/// The default maximum number of attempts for a guarded write (R14.6).
///
/// One initial attempt plus retries, capped so that a write is tried at most
/// this many times before the policy gives up.
const int kDefaultMaxWriteAttempts = 3;

/// Runs [operation] under the data-layer write-retry policy (R14.6, Property 29).
///
/// The wrapper is a **pure, backend-agnostic** higher-order function: it knows
/// nothing about Firebase. Both the attempt budget ([maxAttempts]) and the
/// [operation] are injected, which keeps the policy fully testable in isolation.
///
/// Semantics:
/// - The [operation] is invoked at most [maxAttempts] times.
/// - As soon as an attempt completes without throwing, its value is returned as
///   an [Ok] and **no further attempts are made** — so a successful write is
///   committed exactly once.
/// - If every attempt throws, the policy gives up and returns an [Err] carrying
///   a [PersistenceFailure]. The wrapper itself commits nothing, so on total
///   failure no partial data is committed for the operation (the underlying
///   [operation] is responsible for being individually atomic, e.g. a single
///   document write or a Firestore transaction).
///
/// [maxAttempts] must be greater than zero; it defaults to
/// [kDefaultMaxWriteAttempts] (3). The exceptions thrown by individual attempts
/// are swallowed and mapped to a [Failure]: by default a [PersistenceFailure],
/// or a custom mapping via [onFailure] when the caller wants to translate a
/// specific error (e.g. permission-denied) into a different failure.
Future<Result<T, Failure>> withRetry<T>(
  int maxAttempts,
  Future<T> Function() operation, {
  Failure Function(Object error, StackTrace stackTrace)? onFailure,
}) async {
  assert(maxAttempts > 0, 'maxAttempts must be greater than zero');

  Object? lastError;
  StackTrace lastStackTrace = StackTrace.empty;

  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final T value = await operation();
      return Result<T, Failure>.ok(value);
    } catch (error, stackTrace) {
      // Record the most recent error and keep retrying until the budget is
      // exhausted. No value is returned mid-loop on failure, so nothing is
      // committed by the wrapper itself.
      lastError = error;
      lastStackTrace = stackTrace;
    }
  }

  final Failure failure = onFailure != null
      ? onFailure(lastError!, lastStackTrace)
      : const PersistenceFailure();
  return Result<T, Failure>.err(failure);
}

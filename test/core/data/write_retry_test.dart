import 'package:eventxindia/core/data/write_retry.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake write operation that fails its first [failuresBeforeSuccess] calls
/// and then succeeds, recording how many times it was invoked and how many
/// times it "committed" a value.
class _FakeWrite {
  _FakeWrite({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;

  int calls = 0;
  int commits = 0;

  Future<String> call() async {
    calls++;
    if (calls <= failuresBeforeSuccess) {
      throw StateError('write failed on attempt $calls');
    }
    commits++;
    return 'ok';
  }
}

void main() {
  group('withRetry', () {
    test('returns Ok and commits exactly once when the first attempt succeeds',
        () async {
      final _FakeWrite write = _FakeWrite(failuresBeforeSuccess: 0);

      final Result<String, Failure> result = await withRetry(3, write.call);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 'ok');
      expect(write.calls, 1);
      expect(write.commits, 1);
    });

    test('retries until an attempt succeeds, committing exactly once',
        () async {
      final _FakeWrite write = _FakeWrite(failuresBeforeSuccess: 2);

      final Result<String, Failure> result = await withRetry(3, write.call);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, 'ok');
      expect(write.calls, 3);
      expect(write.commits, 1);
    });

    test(
        'returns a PersistenceFailure and commits nothing when all attempts fail',
        () async {
      final _FakeWrite write = _FakeWrite(failuresBeforeSuccess: 99);

      final Result<String, Failure> result = await withRetry(3, write.call);

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<PersistenceFailure>());
      // Tried at most maxAttempts times and committed no partial data (R14.6).
      expect(write.calls, 3);
      expect(write.commits, 0);
    });

    test('never invokes the operation more than maxAttempts times', () async {
      final _FakeWrite write = _FakeWrite(failuresBeforeSuccess: 99);

      await withRetry(1, write.call);

      expect(write.calls, 1);
    });

    test('maps errors with onFailure when provided', () async {
      final _FakeWrite write = _FakeWrite(failuresBeforeSuccess: 99);

      final Result<String, Failure> result = await withRetry(
        2,
        write.call,
        onFailure: (Object error, StackTrace _) =>
            const NotFoundFailure(message: 'mapped'),
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(result.failureOrNull?.message, 'mapped');
    });
  });
}

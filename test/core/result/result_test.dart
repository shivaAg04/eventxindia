import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result construction and inspection', () {
    test('Ok reports isOk and exposes its value', () {
      const Result<int, Failure> result = Result<int, Failure>.ok(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err reports isErr and exposes its failure', () {
      const Failure failure = NotFoundFailure();
      const Result<int, Failure> result = Result<int, Failure>.err(failure);

      expect(result.isErr, isTrue);
      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });
  });

  group('map', () {
    test('transforms the success value', () {
      const Result<int, Failure> result = Ok<int, Failure>(2);

      final Result<int, Failure> mapped = result.map((int v) => v * 10);

      expect(mapped, const Ok<int, Failure>(20));
    });

    test('leaves a failure untouched', () {
      const Result<int, Failure> result =
          Err<int, Failure>(PersistenceFailure());

      final Result<int, Failure> mapped = result.map((int v) => v * 10);

      expect(mapped, const Err<int, Failure>(PersistenceFailure()));
    });
  });

  group('flatMap', () {
    Result<int, Failure> half(int n) => n.isEven
        ? Ok<int, Failure>(n ~/ 2)
        : const Err<int, Failure>(ValidationFailure(message: 'odd'));

    test('chains success steps', () {
      const Result<int, Failure> result = Ok<int, Failure>(8);

      expect(result.flatMap(half), const Ok<int, Failure>(4));
    });

    test('short-circuits on the first failure', () {
      const Result<int, Failure> result = Ok<int, Failure>(7);

      final Result<int, Failure> chained = result.flatMap(half);

      expect(chained.isErr, isTrue);
      expect(chained.failureOrNull, isA<ValidationFailure>());
    });

    test('does not call transform when already a failure', () {
      var called = false;
      const Result<int, Failure> result = Err<int, Failure>(AuthFailure());

      result.flatMap((int v) {
        called = true;
        return Ok<int, Failure>(v);
      });

      expect(called, isFalse);
    });
  });

  group('fold', () {
    test('invokes onSuccess for Ok', () {
      const Result<int, Failure> result = Ok<int, Failure>(5);

      final String out = result.fold(
        (int v) => 'value:$v',
        (Failure f) => 'error:${f.code}',
      );

      expect(out, 'value:5');
    });

    test('invokes onFailure for Err', () {
      const Result<int, Failure> result =
          Err<int, Failure>(AuthorizationFailure());

      final String out = result.fold(
        (int v) => 'value:$v',
        (Failure f) => 'error:${f.code}',
      );

      expect(out, 'error:authorization');
    });
  });

  group('mapError and getOrElse', () {
    test('mapError transforms only the failure channel', () {
      const Result<int, Failure> ok = Ok<int, Failure>(1);
      const Result<int, Failure> err = Err<int, Failure>(NotFoundFailure());

      expect(ok.mapError((Failure f) => const AuthFailure()).valueOrNull, 1);
      expect(
        err
            .mapError((Failure f) => const AuthFailure())
            .failureOrNull,
        isA<AuthFailure>(),
      );
    });

    test('getOrElse returns value for Ok and fallback for Err', () {
      expect(const Ok<int, Failure>(3).getOrElse(99), 3);
      expect(const Err<int, Failure>(NotFoundFailure()).getOrElse(99), 99);
    });
  });

  group('Unit', () {
    test('all Unit instances are equal', () {
      expect(unit, Unit.value);
      expect(const Result<Unit, Failure>.ok(unit),
          const Ok<Unit, Failure>(Unit.value));
    });
  });
}

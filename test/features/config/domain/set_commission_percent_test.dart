import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/config/domain/repositories/platform_config_repository.dart';
import 'package:eventxindia/features/config/domain/usecases/set_commission_percent.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConfigRepository implements PlatformConfigRepository {
  int? saved;

  @override
  Future<Result<Unit, Failure>> setCommissionPercent(int percent) async {
    saved = percent;
    return const Result<Unit, Failure>.ok(unit);
  }

  @override
  Future<Result<int, Failure>> getCommissionPercent() async =>
      Result<int, Failure>.ok(saved ?? kDefaultCommissionPercent);

  @override
  Stream<int> watchCommissionPercent() =>
      Stream<int>.value(saved ?? kDefaultCommissionPercent);
}

void main() {
  late _FakeConfigRepository repo;
  late SetCommissionPercent setPercent;

  setUp(() {
    repo = _FakeConfigRepository();
    setPercent = SetCommissionPercent(repository: repo);
  });

  test('accepts a value within 0..100 and persists it', () async {
    final Result<Unit, Failure> result = await setPercent(15);
    expect(result.isOk, isTrue);
    expect(repo.saved, 15);
  });

  test('accepts the boundary values 0 and 100', () async {
    expect((await setPercent(0)).isOk, isTrue);
    expect((await setPercent(100)).isOk, isTrue);
  });

  test('rejects a value below 0 and writes nothing', () async {
    final Result<Unit, Failure> result = await setPercent(-1);
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(repo.saved, isNull);
  });

  test('rejects a value above 100 and writes nothing', () async {
    final Result<Unit, Failure> result = await setPercent(101);
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(repo.saved, isNull);
  });
}

import 'package:eventxindia/features/config/data/datasources/firestore_platform_config_data_source.dart';
import 'package:eventxindia/features/config/data/repositories/firestore_platform_config_repository_impl.dart';
import 'package:eventxindia/features/config/domain/repositories/platform_config_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestorePlatformConfigRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = FirestorePlatformConfigRepositoryImpl(
      FirestorePlatformConfigDataSource(firestore),
    );
  });

  test('defaults to 10 when no config document exists', () async {
    final result = await repo.getCommissionPercent();
    expect(result.valueOrNull, kDefaultCommissionPercent);
    expect(kDefaultCommissionPercent, 10);
  });

  test('set then get round-trips the value', () async {
    await repo.setCommissionPercent(20);
    final result = await repo.getCommissionPercent();
    expect(result.valueOrNull, 20);
  });

  test('watch emits the default then the updated value', () async {
    final Stream<int> stream = repo.watchCommissionPercent();
    final Future<List<int>> firstTwo = stream.take(2).toList();
    await repo.setCommissionPercent(30);
    final List<int> emitted = await firstTwo;
    expect(emitted.first, kDefaultCommissionPercent);
    expect(emitted.last, 30);
  });
}

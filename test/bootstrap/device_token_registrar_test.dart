import 'package:eventxindia/bootstrap/device_token_registrar.dart';
import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/features/admin/domain/repositories/admin_repository.dart';
import 'package:eventxindia/features/events/domain/entities/event.dart';
import 'package:eventxindia/features/profile/domain/entities/student.dart';
import 'package:eventxindia/features/profile/domain/entities/vendor.dart';
import 'package:eventxindia/features/reports/domain/entities/report.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every device-token registration so the test can assert what was
/// written, and lets the test simulate a persistence failure (R13.7, R14.6).
class _RecordingAdminRepository implements AdminRepository {
  _RecordingAdminRepository({this.shouldFail = false});

  final bool shouldFail;
  final List<(String, String)> registered = <(String, String)>[];

  @override
  Future<Result<Unit, Failure>> registerDeviceToken(
    String uid,
    String token,
  ) async {
    registered.add((uid, token));
    if (shouldFail) {
      return const Err<Unit, Failure>(
        PersistenceFailure(message: 'write failed'),
      );
    }
    return const Ok<Unit, Failure>(unit);
  }

  @override
  Future<Result<Vendor, Failure>> approveVendor(String vendorId) =>
      throw UnimplementedError();

  @override
  Future<Result<Vendor, Failure>> rejectVendor(String vendorId) =>
      throw UnimplementedError();

  @override
  Stream<List<Student>> listStudents() => throw UnimplementedError();

  @override
  Stream<List<Vendor>> listVendors() => throw UnimplementedError();

  @override
  Stream<List<Event>> listEvents() => throw UnimplementedError();

  @override
  Stream<List<Report>> listReports() => throw UnimplementedError();
}

void main() {
  group('DeviceTokenRegistrar', () {
    test('registers the token for the signed-in user (R13.7)', () async {
      final repo = _RecordingAdminRepository();
      final registrar = DeviceTokenRegistrar(
        adminRepository: repo,
        uidProvider: () => 'user-1',
        tokenProvider: () async => 'token-abc',
      );

      final bool registered = await registrar.register();

      expect(registered, isTrue);
      expect(repo.registered, <(String, String)>[('user-1', 'token-abc')]);
    });

    test('skips when there is no signed-in user', () async {
      final repo = _RecordingAdminRepository();
      final registrar = DeviceTokenRegistrar(
        adminRepository: repo,
        uidProvider: () => null,
        tokenProvider: () async => 'token-abc',
      );

      final bool registered = await registrar.register();

      expect(registered, isFalse);
      expect(repo.registered, isEmpty);
    });

    test('skips when the FCM token is null', () async {
      final repo = _RecordingAdminRepository();
      final registrar = DeviceTokenRegistrar(
        adminRepository: repo,
        uidProvider: () => 'user-1',
        tokenProvider: () async => null,
      );

      final bool registered = await registrar.register();

      expect(registered, isFalse);
      expect(repo.registered, isEmpty);
    });

    test('skips when the FCM token is empty', () async {
      final repo = _RecordingAdminRepository();
      final registrar = DeviceTokenRegistrar(
        adminRepository: repo,
        uidProvider: () => 'user-1',
        tokenProvider: () async => '',
      );

      final bool registered = await registrar.register();

      expect(registered, isFalse);
      expect(repo.registered, isEmpty);
    });

    test('swallows a persistence failure (best-effort, never throws)',
        () async {
      final repo = _RecordingAdminRepository(shouldFail: true);
      final registrar = DeviceTokenRegistrar(
        adminRepository: repo,
        uidProvider: () => 'user-1',
        tokenProvider: () async => 'token-abc',
      );

      final bool registered = await registrar.register();

      expect(registered, isTrue);
      expect(repo.registered, <(String, String)>[('user-1', 'token-abc')]);
    });
  });
}

import 'package:eventxindia/core/error/failure.dart';
import 'package:eventxindia/core/result/result.dart';
import 'package:eventxindia/core/value_objects/money.dart';
import 'package:eventxindia/core/value_objects/withdrawal_status.dart';
import 'package:eventxindia/features/wallet/domain/entities/wallet.dart';
import 'package:eventxindia/features/wallet/domain/entities/withdrawal_request.dart';
import 'package:eventxindia/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:eventxindia/features/wallet/domain/usecases/request_withdrawal.dart';
import 'package:flutter_test/flutter_test.dart';

Money rupees(int major) =>
    Money.fromMajorUnits(major, requirePayPerHeadRange: false);

WithdrawalRequest withdrawal(Money amount, WithdrawalStatus status) =>
    WithdrawalRequest(
      id: 'wd_$status$amount',
      studentId: 's1',
      amount: amount,
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

/// Records the created request and returns a canned result.
class _FakeWalletRepository implements WalletRepository {
  WithdrawalRequest? created;

  @override
  Future<Result<WithdrawalRequest, Failure>> create(
    WithdrawalRequest request,
  ) async {
    created = request;
    return Result<WithdrawalRequest, Failure>.ok(request);
  }

  @override
  Future<Result<Unit, Failure>> decide({
    required String id,
    required WithdrawalStatus decision,
    required DateTime decidedAt,
  }) async =>
      const Result<Unit, Failure>.ok(unit);

  @override
  Stream<List<WithdrawalRequest>> watchAll() => const Stream.empty();

  @override
  Stream<List<WithdrawalRequest>> watchByStudent(String studentId) =>
      const Stream.empty();
}

void main() {
  group('Wallet balances', () {
    test('available = credited − approved − pending, and sub-totals', () {
      final Wallet wallet = Wallet(
        studentId: 's1',
        credited: rupees(1000),
        creditsPerEvent: const <String, Money>{},
        withdrawals: <WithdrawalRequest>[
          withdrawal(rupees(200), WithdrawalStatus.approved),
          withdrawal(rupees(150), WithdrawalStatus.pending),
          withdrawal(rupees(50), WithdrawalStatus.rejected), // ignored
        ],
      );

      expect(wallet.approvedTotal, rupees(200));
      expect(wallet.pendingTotal, rupees(150));
      expect(wallet.available, rupees(650)); // 1000 - 200 - 150
    });

    test('available never goes negative', () {
      final Wallet wallet = Wallet(
        studentId: 's1',
        credited: rupees(100),
        creditsPerEvent: const <String, Money>{},
        withdrawals: <WithdrawalRequest>[
          withdrawal(rupees(200), WithdrawalStatus.approved),
        ],
      );
      expect(wallet.available, Money.zero);
    });

    test('empty wallet has zero balances', () {
      final Wallet wallet = Wallet.empty('s1');
      expect(wallet.available, Money.zero);
      expect(wallet.approvedTotal, Money.zero);
      expect(wallet.pendingTotal, Money.zero);
    });
  });

  group('RequestWithdrawal', () {
    late _FakeWalletRepository repo;
    late RequestWithdrawal useCase;

    setUp(() {
      repo = _FakeWalletRepository();
      useCase = RequestWithdrawal(
        repository: repo,
        now: () => DateTime(2026, 5, 1),
      );
    });

    test('creates a pending request within the available balance', () async {
      final Result<WithdrawalRequest, Failure> result = await useCase(
        studentId: 's1',
        amount: rupees(300),
        available: rupees(500),
      );

      expect(result.isOk, isTrue);
      expect(repo.created, isNotNull);
      expect(repo.created!.status, WithdrawalStatus.pending);
      expect(repo.created!.amount, rupees(300));
    });

    test('rejects a zero amount and writes nothing', () async {
      final Result<WithdrawalRequest, Failure> result = await useCase(
        studentId: 's1',
        amount: Money.zero,
        available: rupees(500),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.created, isNull);
    });

    test('rejects an amount over the available balance', () async {
      final Result<WithdrawalRequest, Failure> result = await useCase(
        studentId: 's1',
        amount: rupees(600),
        available: rupees(500),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repo.created, isNull);
    });
  });
}

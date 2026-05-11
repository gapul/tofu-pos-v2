import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/repositories/ticket_number_pool_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

/// TicketNumberPoolRepository の契約テスト。
void runTicketPoolRepositoryContract(
  String label, {
  required Future<TicketNumberPoolRepository> Function() create,
  Future<void> Function()? cleanup,
}) {
  group('TicketNumberPoolRepository contract: $label', () {
    late TicketNumberPoolRepository repo;

    setUp(() async {
      repo = await create();
    });

    if (cleanup != null) {
      tearDown(cleanup);
    }

    test('initial load returns an empty pool', () async {
      final TicketNumberPool pool = await repo.load();
      expect(pool.inUseNumbers, isEmpty);
    });

    test('save -> load round-trips state', () async {
      TicketNumberPool pool = TicketNumberPool.empty();
      pool = pool.issue().pool;
      pool = pool.issue().pool;
      await repo.save(pool);
      final TicketNumberPool loaded = await repo.load();
      expect(loaded.inUseNumbers, <int>{1, 2});
    });

    test('allocate returns a positive TicketNumber', () async {
      final TicketNumber n = await repo.allocate();
      expect(n.value, isPositive);
    });

    test('50 concurrent allocate calls return unique numbers', () async {
      // default maxNumber=99 / bufferSize=10 を前提に枯渇しない範囲（50）で
      // 並行性の一意性を検証する。
      final List<TicketNumber> numbers = await Future.wait(<Future<TicketNumber>>[
        for (int i = 0; i < 50; i++) repo.allocate(),
      ]);
      expect(numbers.map((n) => n.value).toSet().length, 50);
    });

    test('release after allocate frees the number (eventually reusable)',
        () async {
      final TicketNumber n = await repo.allocate();
      await repo.release(n);
      // release 直後はバッファに残るため、すぐ同じ番号が出るとは限らない（仕様）。
      // ただしプールがリセット可能な状態であること = save できる、を確認する。
      final TicketNumberPool pool = await repo.load();
      expect(pool.inUseNumbers.contains(n.value), isFalse);
    });

    test('release of unknown number is no-op', () async {
      // 未払い出しの番号を release してもエラーにならない。
      await repo.release(const TicketNumber(42));
    });
  });
}

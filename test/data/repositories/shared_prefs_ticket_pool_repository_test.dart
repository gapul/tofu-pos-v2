import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsTicketPoolRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsTicketPoolRepository(prefs);
  });

  test('load returns empty pool when no state stored', () async {
    final TicketNumberPool pool = await repo.load();
    expect(pool.maxNumber, 99);
    expect(pool.bufferSize, 10);
    expect(pool.inUseNumbers, isEmpty);
  });

  test('save and load round-trip', () async {
    TicketNumberPool pool = TicketNumberPool.empty();
    pool = pool.issue().pool; // 1 in use
    pool = pool.issue().pool; // 1, 2 in use
    pool = pool.release(const TicketNumber(1)); // 2 in use, 1 in buffer

    await repo.save(pool);

    final TicketNumberPool loaded = await repo.load();
    expect(loaded.inUseNumbers, <int>{2});
    expect(loaded.recentlyReleasedNumbers, <int>[1]);
    expect(loaded.maxNumber, pool.maxNumber);
    expect(loaded.bufferSize, pool.bufferSize);
  });

  test('default constructor parameters override empty pool defaults', () async {
    repo = SharedPrefsTicketPoolRepository(
      prefs,
      defaultMaxNumber: 50,
      defaultBufferSize: 5,
    );
    final TicketNumberPool pool = await repo.load();
    expect(pool.maxNumber, 50);
    expect(pool.bufferSize, 5);
  });

  group('pending release queue (補償失敗のロスト防止)', () {
    test(
      'enqueuePendingRelease stores number; pendingReleases reads it back',
      () async {
        await repo.enqueuePendingRelease(const TicketNumber(7));
        await repo.enqueuePendingRelease(const TicketNumber(12));
        // 重複は de-dup される
        await repo.enqueuePendingRelease(const TicketNumber(7));

        final List<TicketNumber> pending = await repo.pendingReleases();
        expect(
          pending.map((t) => t.value).toList(),
          <int>[7, 12],
        );
      },
    );

    test(
      'flushPendingReleases releases queued numbers and clears the queue',
      () async {
        // 事前に 5 を発番（in_use にしておく）
        TicketNumberPool pool = TicketNumberPool.empty();
        final issued = pool.issue();
        pool = issued.pool; // 1 in use
        // 2 を強制 in_use にするため、もう1回発行
        final issued2 = pool.issue();
        pool = issued2.pool; // 1, 2 in use
        await repo.save(pool);

        // 2 を pending に積む（補償失敗を想定）
        await repo.enqueuePendingRelease(const TicketNumber(2));

        final int processed = await repo.flushPendingReleases();
        expect(processed, 1);

        // キューは空になる
        expect(await repo.pendingReleases(), isEmpty);
        // 2 は in_use から外れている
        final TicketNumberPool after = await repo.load();
        expect(after.inUseNumbers, <int>{1});
      },
    );

    test('flushPendingReleases on empty queue is a no-op', () async {
      expect(await repo.flushPendingReleases(), 0);
    });
  });
}

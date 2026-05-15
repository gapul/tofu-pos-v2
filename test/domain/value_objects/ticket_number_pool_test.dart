import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

void main() {
  group('TicketNumberPool', () {
    test('empty pool issues 1 first', () {
      final TicketNumberPool pool = TicketNumberPool.empty();
      final ({TicketNumberPool pool, TicketNumber number}) r = pool.issue();
      expect(r.number, const TicketNumber(1));
      expect(r.pool.inUseNumbers, <int>{1});
    });

    test('issues sequentially while no release', () {
      TicketNumberPool pool = TicketNumberPool.empty();
      final List<int> issued = <int>[];
      for (int i = 0; i < 5; i++) {
        final ({TicketNumberPool pool, TicketNumber number}) r = pool.issue();
        issued.add(r.number.value);
        pool = r.pool;
      }
      expect(issued, <int>[1, 2, 3, 4, 5]);
    });

    test('released number is buffered, then reusable', () {
      // バッファ2、最大10で運用。クールタイムはこのテストでは無効化。
      TicketNumberPool pool = TicketNumberPool.empty(
        maxNumber: 10,
        bufferSize: 2,
        cooldown: Duration.zero,
      );

      // 番号1を払い出して解放
      final ({TicketNumberPool pool, TicketNumber number}) r1 = pool.issue();
      pool = r1.pool;
      pool = pool.release(r1.number); // 1がバッファに

      // 直後の発番は2が出るはず（1はバッファ中）
      final ({TicketNumberPool pool, TicketNumber number}) r2 = pool.issue();
      expect(r2.number.value, 2);
      pool = r2.pool;

      // 3を発番→解放
      final ({TicketNumberPool pool, TicketNumber number}) r3 = pool.issue();
      expect(r3.number.value, 3);
      pool = r3.pool;
      pool = pool.release(r3.number); // 3がバッファに、1も保持

      // 4を発番→解放（バッファ満杯）
      final ({TicketNumberPool pool, TicketNumber number}) r4 = pool.issue();
      expect(r4.number.value, 4);
      pool = r4.pool;
      pool = pool.release(r4.number); // 1が押し出され再利用可、3,4が保持

      // 次の発番は1（最若の再利用可能番号）
      final ({TicketNumberPool pool, TicketNumber number}) r5 = pool.issue();
      expect(r5.number.value, 1);
    });

    test('hasAvailable becomes false when exhausted', () {
      TicketNumberPool pool = TicketNumberPool.empty(
        maxNumber: 3,
        bufferSize: 0,
      );
      pool = pool.issue().pool;
      pool = pool.issue().pool;
      pool = pool.issue().pool;
      expect(pool.peekNext(), isNull);
      expect(() => pool.issue(), throwsStateError);
    });

    test('release of unknown number is idempotent', () {
      final TicketNumberPool pool = TicketNumberPool.empty();
      final TicketNumberPool same = pool.release(const TicketNumber(99));
      expect(same.inUseNumbers, isEmpty);
      expect(same.recentlyReleasedNumbers, isEmpty);
    });

    test('reset clears everything', () {
      TicketNumberPool pool = TicketNumberPool.empty(bufferSize: 5);
      for (int i = 0; i < 3; i++) {
        pool = pool.issue().pool;
      }
      pool = pool.release(const TicketNumber(2));
      final TicketNumberPool reset = pool.reset();
      expect(reset.inUseNumbers, isEmpty);
      expect(reset.recentlyReleasedNumbers, isEmpty);
      expect(reset.bufferSize, 5);
    });
  });
}

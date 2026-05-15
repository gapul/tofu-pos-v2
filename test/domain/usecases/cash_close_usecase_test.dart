import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/usecases/cash_close_usecase.dart';
import 'package:tofu_pos/domain/value_objects/cash_close_difference.dart';
import 'package:tofu_pos/domain/value_objects/daily_summary.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

import '../../fakes/fake_repositories.dart';

Order _order({
  required int id,
  required DateTime createdAt,
  Money price = const Money(500),
  OrderStatus status = OrderStatus.served,
  SyncStatus sync = SyncStatus.synced,
}) {
  return Order(
    id: id,
    ticketNumber: TicketNumber(id),
    items: <OrderItem>[
      OrderItem(
        productId: 'p',
        productName: 'P',
        priceAtTime: price,
        quantity: 1,
      ),
    ],
    discount: Discount.none,
    receivedCash: price,
    createdAt: createdAt,
    orderStatus: status,
    syncStatus: sync,
  );
}

void main() {
  late InMemoryOrderRepository orderRepo;
  late InMemoryCashDrawerRepository cashRepo;
  late CashCloseUseCase usecase;

  final DateTime today = DateTime(2026, 5, 7, 12);

  setUp(() {
    orderRepo = InMemoryOrderRepository();
    cashRepo = InMemoryCashDrawerRepository();
    usecase = CashCloseUseCase(
      orderRepository: orderRepo,
      cashDrawerRepository: cashRepo,
      now: () => today,
    );
  });

  group('getDailySummary', () {
    test('empty day returns zero counts', () async {
      final DailySummary s = await usecase.getDailySummary(
        flags: FeatureFlags.allOff,
      );
      expect(s.totalSales, Money.zero);
      expect(s.orderCount, 0);
      expect(s.cancelledCount, 0);
      expect(s.unsyncedCount, 0);
      expect(s.theoreticalDrawer, isNull);
    });

    test('sums final prices of non-cancelled orders', () async {
      await orderRepo.create(
        _order(
          id: 1,
          createdAt: DateTime(2026, 5, 7, 10),
          price: const Money(400),
        ),
      );
      await orderRepo.create(
        _order(
          id: 2,
          createdAt: DateTime(2026, 5, 7, 14),
          price: const Money(300),
        ),
      );
      final DailySummary s = await usecase.getDailySummary(
        flags: FeatureFlags.allOff,
      );
      expect(s.totalSales, const Money(700));
      expect(s.orderCount, 2);
    });

    test('excludes cancelled orders from sales but counts them', () async {
      await orderRepo.create(
        _order(id: 1, createdAt: DateTime(2026, 5, 7, 10)),
      );
      await orderRepo.create(
        _order(
          id: 2,
          createdAt: DateTime(2026, 5, 7, 11),
          price: const Money(800),
          status: OrderStatus.cancelled,
        ),
      );
      final DailySummary s = await usecase.getDailySummary(
        flags: FeatureFlags.allOff,
      );
      expect(s.totalSales, const Money(500));
      expect(s.orderCount, 1);
      expect(s.cancelledCount, 1);
    });

    test('counts unsynced orders', () async {
      await orderRepo.create(
        _order(
          id: 1,
          createdAt: DateTime(2026, 5, 7, 10),
          sync: SyncStatus.notSynced,
        ),
      );
      await orderRepo.create(
        _order(id: 2, createdAt: DateTime(2026, 5, 7, 11)),
      );
      final DailySummary s = await usecase.getDailySummary(
        flags: FeatureFlags.allOff,
      );
      expect(s.unsyncedCount, 1);
      expect(s.hasUnsynced, isTrue);
    });

    test('includes theoreticalDrawer when cashManagement is on', () async {
      await cashRepo.replace(
        CashDrawer(<Denomination, int>{const Denomination(1000): 3}),
      );
      final DailySummary s = await usecase.getDailySummary(
        flags: const FeatureFlags(),
      );
      expect(s.theoreticalDrawer, isNotNull);
      expect(s.theoreticalDrawer!.totalAmount, const Money(3000));
    });

    test('omits theoreticalDrawer when cashManagement is off', () async {
      await cashRepo.replace(
        CashDrawer(<Denomination, int>{const Denomination(1000): 3}),
      );
      final DailySummary s = await usecase.getDailySummary(
        flags: FeatureFlags.allOff,
      );
      expect(s.theoreticalDrawer, isNull);
    });
  });

  group('computeDifference', () {
    test('zero diff when actual matches theoretical', () {
      final CashDrawer th = CashDrawer(<Denomination, int>{
        const Denomination(1000): 5,
        const Denomination(100): 10,
      });
      final CashCloseDifference d = usecase.computeDifference(
        theoretical: th,
        actual: th,
      );
      expect(d.isZero, isTrue);
      expect(d.amountDiff, Money.zero);
    });

    test('shortage when actual is less', () {
      final CashDrawer th = CashDrawer(<Denomination, int>{
        const Denomination(1000): 5,
      });
      final CashDrawer ac = CashDrawer(<Denomination, int>{
        const Denomination(1000): 3,
      });
      final CashCloseDifference d = usecase.computeDifference(
        theoretical: th,
        actual: ac,
      );
      expect(d.isShort, isTrue);
      expect(d.amountDiff, const Money(-2000));
      expect(d.countDiff[const Denomination(1000)], -2);
    });

    test('overage when actual is more', () {
      final CashDrawer th = CashDrawer(<Denomination, int>{
        const Denomination(100): 10,
      });
      final CashDrawer ac = CashDrawer(<Denomination, int>{
        const Denomination(100): 12,
      });
      final CashCloseDifference d = usecase.computeDifference(
        theoretical: th,
        actual: ac,
      );
      expect(d.isOver, isTrue);
      expect(d.amountDiff, const Money(200));
    });
  });

  group('recordCashClose — operation log (§6.6)', () {
    test('appends a cash_close entry with summary + diff', () async {
      final InMemoryOperationLogRepository logRepo =
          InMemoryOperationLogRepository();
      final CashCloseUseCase u = CashCloseUseCase(
        orderRepository: orderRepo,
        cashDrawerRepository: cashRepo,
        operationLogRepository: logRepo,
        now: () => today,
      );

      final DailySummary summary = DailySummary(
        date: DateTime(2026, 5, 7),
        totalSales: const Money(12345),
        orderCount: 7,
        cancelledCount: 1,
        unsyncedCount: 2,
      );
      final CashCloseDifference diff = u.computeDifference(
        theoretical: CashDrawer(<Denomination, int>{
          const Denomination(1000): 5,
        }),
        actual: CashDrawer(<Denomination, int>{
          const Denomination(1000): 4,
        }),
      );
      await u.recordCashClose(summary: summary, difference: diff);

      expect(logRepo.records, hasLength(1));
      expect(logRepo.records.single.kind, 'cash_close');
      expect(
        logRepo.records.single.detailJson,
        contains('"total_sales_yen":12345'),
      );
      expect(
        logRepo.records.single.detailJson,
        contains('"difference_yen":-1000'),
      );
    });

    test('no-op when operation log repo is not injected', () async {
      final InMemoryOperationLogRepository logRepo =
          InMemoryOperationLogRepository();
      await usecase.recordCashClose(
        summary: DailySummary(
          date: DateTime(2026, 5, 7),
          totalSales: Money.zero,
          orderCount: 0,
          cancelledCount: 0,
          unsyncedCount: 0,
        ),
      );
      expect(logRepo.records, isEmpty);
    });
  });
}

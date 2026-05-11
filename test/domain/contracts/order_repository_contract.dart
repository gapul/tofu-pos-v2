import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/repositories/order_repository.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

/// OrderRepository の契約テスト。
///
/// すべての実装は `runOrderRepositoryContract` をパスする必要がある。
/// 個別実装の特殊機能ではなく **インタフェースの観察可能な挙動** だけを検証する。
void runOrderRepositoryContract(
  String label, {
  required Future<OrderRepository> Function() create,
  Future<void> Function()? cleanup,
}) {
  group('OrderRepository contract: $label', () {
    late OrderRepository repo;

    setUp(() async {
      repo = await create();
    });

    if (cleanup != null) {
      tearDown(cleanup);
    }

    Order makeOrder({
      int ticketValue = 1,
      Discount discount = Discount.none,
      OrderStatus status = OrderStatus.unsent,
      SyncStatus sync = SyncStatus.notSynced,
    }) {
      return Order(
        id: 0,
        ticketNumber: TicketNumber(ticketValue),
        items: const <OrderItem>[
          OrderItem(
            productId: 'p1',
            productName: 'Yakisoba',
            priceAtTime: Money(400),
            quantity: 2,
          ),
        ],
        discount: discount,
        receivedCash: const Money(1000),
        createdAt: DateTime(2026, 5, 7, 12),
        orderStatus: status,
        syncStatus: sync,
      );
    }

    test('create assigns a positive id', () async {
      final Order saved = await repo.create(makeOrder());
      expect(saved.id, isPositive);
    });

    test('create assigns unique ids across calls', () async {
      final Order a = await repo.create(makeOrder());
      final Order b = await repo.create(makeOrder(ticketValue: 2));
      expect(a.id, isNot(b.id));
    });

    test('findById returns persisted order', () async {
      final Order saved = await repo.create(makeOrder());
      final Order? loaded = await repo.findById(saved.id);
      expect(loaded, isNotNull);
      expect(loaded!.ticketNumber, saved.ticketNumber);
    });

    test('findById returns null for unknown id', () async {
      final Order? o = await repo.findById(999999);
      expect(o, isNull);
    });

    test('findUnsynced returns only NOT_SYNCED orders', () async {
      final Order a = await repo.create(makeOrder());
      final Order b = await repo.create(makeOrder(ticketValue: 2));
      await repo.updateSyncStatus(a.id, SyncStatus.synced);

      final List<Order> unsynced = await repo.findUnsynced();
      final Set<int> ids = unsynced.map((o) => o.id).toSet();
      expect(ids.contains(a.id), isFalse);
      expect(ids.contains(b.id), isTrue);
    });

    test('updateStatus persists the new status', () async {
      final Order saved = await repo.create(makeOrder());
      await repo.updateStatus(saved.id, OrderStatus.served);
      final Order? loaded = await repo.findById(saved.id);
      expect(loaded!.orderStatus, OrderStatus.served);
    });

    test('updateSyncStatus persists the new sync status', () async {
      final Order saved = await repo.create(makeOrder());
      await repo.updateSyncStatus(saved.id, SyncStatus.synced);
      final Order? loaded = await repo.findById(saved.id);
      expect(loaded!.syncStatus, SyncStatus.synced);
    });

    test('updateStatus on unknown id does not throw', () async {
      await repo.updateStatus(999999, OrderStatus.served);
    });

    test('updateSyncStatus on unknown id does not throw', () async {
      await repo.updateSyncStatus(999999, SyncStatus.synced);
    });

    test('findAll returns all created orders (no filter)', () async {
      await repo.create(makeOrder());
      await repo.create(makeOrder(ticketValue: 2));
      await repo.create(makeOrder(ticketValue: 3));
      final List<Order> all = await repo.findAll();
      expect(all.length, greaterThanOrEqualTo(3));
    });

    test('findAll respects limit', () async {
      await repo.create(makeOrder());
      await repo.create(makeOrder(ticketValue: 2));
      await repo.create(makeOrder(ticketValue: 3));
      final List<Order> limited = await repo.findAll(limit: 2);
      expect(limited.length, 2);
    });

    test('findAll honors date range filter', () async {
      await repo.create(makeOrder());
      final List<Order> none = await repo.findAll(
        from: DateTime(2099, 2),
      );
      expect(none, isEmpty);
    });
  });
}

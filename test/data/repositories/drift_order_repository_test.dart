import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/domain/entities/customer_attributes.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/customer_attributes_enums.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

void main() {
  late AppDatabase db;
  late DriftOrderRepository repo;

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
        OrderItem(
          productId: 'p2',
          productName: 'Juice',
          priceAtTime: Money(150),
          quantity: 1,
        ),
      ],
      discount: discount,
      receivedCash: const Money(1000),
      createdAt: DateTime(2026, 5, 7, 12),
      orderStatus: status,
      syncStatus: sync,
      customerAttributes: const CustomerAttributes(
        age: CustomerAge.twenties,
        gender: CustomerGender.female,
        group: CustomerGroup.couple,
      ),
    );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftOrderRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create assigns id and persists items', () async {
    final Order saved = await repo.create(makeOrder());
    expect(saved.id, isPositive);
    expect(saved.items, hasLength(2));

    final Order? loaded = await repo.findById(saved.id);
    expect(loaded, isNotNull);
    expect(loaded!.totalPrice, const Money(950));
    expect(loaded.customerAttributes.age, CustomerAge.twenties);
  });

  test('findUnsynced returns only NOT_SYNCED orders', () async {
    final Order a = await repo.create(makeOrder());
    final Order b = await repo.create(makeOrder(ticketValue: 2));
    await repo.updateSyncStatus(a.id, SyncStatus.synced);

    final List<Order> unsynced = await repo.findUnsynced();
    expect(unsynced.map((Order o) => o.id), <int>[b.id]);
  });

  test('updateStatus changes order status', () async {
    final Order placed = await repo.create(makeOrder());
    await repo.updateStatus(placed.id, OrderStatus.cancelled);

    final Order? loaded = await repo.findById(placed.id);
    expect(loaded!.orderStatus, OrderStatus.cancelled);
  });

  test('round-trips PercentDiscount', () async {
    final Order placed = await repo.create(
      makeOrder(discount: const PercentDiscount(-10)),
    );
    final Order? loaded = await repo.findById(placed.id);
    expect(loaded!.discount, isA<PercentDiscount>());
    expect((loaded.discount as PercentDiscount).percent, -10);
  });

  test('findAll respects limit/offset and orders desc', () async {
    for (int i = 0; i < 5; i++) {
      await repo.create(
        makeOrder(
          ticketValue: i + 1,
        ).copyWith(createdAt: DateTime(2026, 5, 7, 10 + i)),
      );
    }
    final List<Order> page1 = await repo.findAll(limit: 2);
    expect(page1, hasLength(2));
    // newest first
    expect(page1[0].createdAt.hour, 14);
    expect(page1[1].createdAt.hour, 13);

    final List<Order> page2 = await repo.findAll(limit: 2, offset: 2);
    expect(page2, hasLength(2));
    expect(page2[0].createdAt.hour, 12);
    expect(page2[1].createdAt.hour, 11);

    final List<Order> page3 = await repo.findAll(limit: 2, offset: 4);
    expect(page3, hasLength(1));
  });

  test('round-trips AmountDiscount', () async {
    final Order placed = await repo.create(
      makeOrder(discount: const AmountDiscount(Money(-150))),
    );
    final Order? loaded = await repo.findById(placed.id);
    expect(loaded!.discount, isA<AmountDiscount>());
    expect((loaded.discount as AmountDiscount).amount, const Money(-150));
  });
}

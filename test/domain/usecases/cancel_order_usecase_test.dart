import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/usecases/cancel_order_usecase.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

import '../../fakes/fake_repositories.dart';

void main() {
  late InMemoryProductRepository productRepo;
  late InMemoryOrderRepository orderRepo;
  late InMemoryCashDrawerRepository cashRepo;
  late InMemoryTicketPoolRepository poolRepo;
  late InMemoryOperationLogRepository logRepo;
  late CheckoutUseCase checkout;
  late CancelOrderUseCase cancel;

  const CheckoutDraft draft = CheckoutDraft(
    items: <OrderItem>[
      OrderItem(
        productId: 'p1',
        productName: 'Yakisoba',
        priceAtTime: Money(400),
        quantity: 2,
      ),
    ],
    receivedCash: Money(1000),
    cashDelta: <int, int>{1000: 1, 100: -2}, // +800円
  );

  setUp(() {
    productRepo = InMemoryProductRepository(<Product>[
      const Product(id: 'p1', name: 'Yakisoba', price: Money(400), stock: 10),
    ]);
    orderRepo = InMemoryOrderRepository();
    cashRepo = InMemoryCashDrawerRepository();
    poolRepo = InMemoryTicketPoolRepository();
    logRepo = InMemoryOperationLogRepository();
    checkout = CheckoutUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7, 12),
    );
    cancel = CancelOrderUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      operationLogRepository: logRepo,
      now: () => DateTime(2026, 5, 7, 13),
    );
  });

  test('marks order as cancelled and unsynced', () async {
    final Order placed = await checkout.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );

    final Order cancelled = await cancel.execute(
      orderId: placed.id,
      flags: FeatureFlags.allOff,
      originalCashDelta: const <int, int>{},
    );

    expect(cancelled.orderStatus, OrderStatus.cancelled);
    expect(cancelled.syncStatus, SyncStatus.notSynced);
    expect(cancelled.isCancelled, isTrue);
  });

  test('rolls back stock when stockManagement was on', () async {
    final FeatureFlags flags = FeatureFlags.allOff.copyWith(stockManagement: true);
    final Order placed = await checkout.execute(draft: draft, flags: flags);
    final Product? before = await productRepo.findById('p1');
    expect(before!.stock, 8);

    await cancel.execute(
      orderId: placed.id,
      flags: flags,
      originalCashDelta: const <int, int>{},
    );

    final Product? after = await productRepo.findById('p1');
    expect(after!.stock, 10);
  });

  test('rolls back cash drawer when cashManagement was on', () async {
    // ¥100 を5枚 seed しておく
    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(100): 5}),
    );

    final FeatureFlags flags = FeatureFlags.allOff.copyWith(cashManagement: true);
    final Order placed = await checkout.execute(draft: draft, flags: flags);
    expect((await cashRepo.get()).totalAmount, const Money(1300));

    await cancel.execute(
      orderId: placed.id,
      flags: flags,
      originalCashDelta: draft.cashDelta,
    );

    // 取消で +1000 / -100×2 が逆転 → 元の seed money 500円に戻る
    expect((await cashRepo.get()).totalAmount, const Money(500));
  });

  test('releases ticket number back to pool', () async {
    final Order placed = await checkout.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );
    final pool = await poolRepo.load();
    expect(pool.inUseNumbers, contains(placed.ticketNumber.value));

    await cancel.execute(
      orderId: placed.id,
      flags: FeatureFlags.allOff,
      originalCashDelta: const <int, int>{},
    );

    final pool2 = await poolRepo.load();
    expect(pool2.inUseNumbers, isNot(contains(placed.ticketNumber.value)));
    expect(pool2.recentlyReleasedNumbers, contains(placed.ticketNumber.value));
  });

  test('throws when order does not exist', () {
    expect(
      () => cancel.execute(
        orderId: 999,
        flags: FeatureFlags.allOff,
        originalCashDelta: const <int, int>{},
      ),
      throwsA(isA<OrderNotCancellableException>()),
    );
  });

  test('records cancel_order operation log entry', () async {
    final Order placed = await checkout.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );
    await cancel.execute(
      orderId: placed.id,
      flags: FeatureFlags.allOff,
      originalCashDelta: const <int, int>{},
    );

    expect(logRepo.records, hasLength(1));
    final logEntry = logRepo.records.single;
    expect(logEntry.kind, 'cancel_order');
    expect(logEntry.targetId, placed.id.toString());
    expect(logEntry.detailJson, isNotNull);
    expect(logEntry.detailJson, contains('ticket_number'));
    expect(logEntry.occurredAt, DateTime(2026, 5, 7, 13));
  });

  test('does not log when cancellation throws', () async {
    expect(
      () => cancel.execute(
        orderId: 999,
        flags: FeatureFlags.allOff,
        originalCashDelta: const <int, int>{},
      ),
      throwsA(isA<OrderNotCancellableException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(logRepo.records, isEmpty);
  });

  test('throws when order is already cancelled', () async {
    final Order placed = await checkout.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );
    await cancel.execute(
      orderId: placed.id,
      flags: FeatureFlags.allOff,
      originalCashDelta: const <int, int>{},
    );
    expect(
      () => cancel.execute(
        orderId: placed.id,
        flags: FeatureFlags.allOff,
        originalCashDelta: const <int, int>{},
      ),
      throwsA(isA<OrderNotCancellableException>()),
    );
  });
}

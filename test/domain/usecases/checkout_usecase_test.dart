import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';

import '../../fakes/fake_repositories.dart';

void main() {
  late InMemoryProductRepository productRepo;
  late InMemoryOrderRepository orderRepo;
  late InMemoryCashDrawerRepository cashRepo;
  late InMemoryTicketPoolRepository poolRepo;
  late CheckoutUseCase usecase;

  setUp(() {
    productRepo = InMemoryProductRepository(<Product>[
      const Product(id: 'p1', name: 'Yakisoba', price: Money(400), stock: 10),
      const Product(id: 'p2', name: 'Juice', price: Money(150), stock: 20),
    ]);
    orderRepo = InMemoryOrderRepository();
    cashRepo = InMemoryCashDrawerRepository();
    poolRepo = InMemoryTicketPoolRepository();
    usecase = CheckoutUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7, 12),
    );
  });

  CheckoutDraft makeDraft({
    Discount discount = Discount.none,
    Money receivedCash = const Money(1000),
    Map<int, int> cashDelta = const <int, int>{},
  }) {
    return CheckoutDraft(
      items: const <OrderItem>[
        OrderItem(
          productId: 'p1',
          productName: 'Yakisoba',
          priceAtTime: Money(400),
          quantity: 2,
        ),
      ],
      discount: discount,
      receivedCash: receivedCash,
      cashDelta: cashDelta,
    );
  }

  test('persists order with assigned ticket number 1', () async {
    final Order order = await usecase.execute(
      draft: makeDraft(),
      flags: FeatureFlags.allOff,
    );

    expect(order.id, 1);
    expect(order.ticketNumber.value, 1);
    expect(order.orderStatus, OrderStatus.unsent);
    expect(order.syncStatus, SyncStatus.notSynced);
    expect(order.totalPrice, const Money(800));
  });

  test('decrements stock when stockManagement is on', () async {
    await usecase.execute(
      draft: makeDraft(),
      flags: const FeatureFlags(stockManagement: true),
    );
    final Product? p = await productRepo.findById('p1');
    expect(p!.stock, 8); // 10 - 2
  });

  test('does NOT decrement stock when stockManagement is off', () async {
    await usecase.execute(
      draft: makeDraft(),
      flags: FeatureFlags.allOff,
    );
    final Product? p = await productRepo.findById('p1');
    expect(p!.stock, 10);
  });

  test('throws InsufficientStockException when stock is short', () async {
    const CheckoutDraft draft = CheckoutDraft(
      items: <OrderItem>[
        OrderItem(
          productId: 'p1',
          productName: 'Yakisoba',
          priceAtTime: Money(400),
          quantity: 100, // > 10
        ),
      ],
    );
    expect(
      () => usecase.execute(
        draft: draft,
        flags: const FeatureFlags(stockManagement: true),
      ),
      throwsA(isA<InsufficientStockException>()),
    );
  });

  test('updates cash drawer when cashManagement is on', () async {
    // ¥100コインを5枚積んでおく（お釣り用の seed money）
    await cashRepo.replace(CashDrawer(<Denomination, int>{
      const Denomination(100): 5,
    }));

    await usecase.execute(
      draft: makeDraft(
        cashDelta: const <int, int>{1000: 1, 100: -2},
      ),
      flags: const FeatureFlags(cashManagement: true),
    );
    final drawer = await cashRepo.get();
    // 開始時 500円 → +1000 - 200 = 1300円
    expect(drawer.totalAmount, const Money(1300));
  });

  test('throws when ticket pool is exhausted', () async {
    // 番号1を払い出した状態（max=1, buffer=0）からスタート
    final TicketNumberPool exhausted =
        TicketNumberPool.empty(maxNumber: 1, bufferSize: 0).issue().pool;
    poolRepo = InMemoryTicketPoolRepository(exhausted);
    usecase = CheckoutUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
    );
    expect(
      () => usecase.execute(draft: makeDraft(), flags: FeatureFlags.allOff),
      throwsA(isA<TicketPoolExhaustedException>()),
    );
  });

  test('rejects empty cart', () {
    expect(
      () => usecase.execute(
        draft: const CheckoutDraft(items: <OrderItem>[]),
        flags: FeatureFlags.allOff,
      ),
      throwsArgumentError,
    );
  });

  test('issues sequential ticket numbers across multiple checkouts', () async {
    final Order o1 =
        await usecase.execute(draft: makeDraft(), flags: FeatureFlags.allOff);
    final Order o2 =
        await usecase.execute(draft: makeDraft(), flags: FeatureFlags.allOff);
    expect(o1.ticketNumber.value, 1);
    expect(o2.ticketNumber.value, 2);
  });
}

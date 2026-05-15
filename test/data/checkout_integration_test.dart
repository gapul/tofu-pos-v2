import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_cash_drawer_repository.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/data/repositories/drift_unit_of_work.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/usecases/cancel_order_usecase.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

/// Drift + SharedPreferences の本物実装で UseCase が end-to-end で動くことを検証。
void main() {
  late AppDatabase db;
  late DriftProductRepository productRepo;
  late DriftOrderRepository orderRepo;
  late DriftCashDrawerRepository cashRepo;
  late SharedPrefsTicketPoolRepository poolRepo;
  late DriftUnitOfWork uow;
  late CheckoutUseCase checkout;
  late CancelOrderUseCase cancel;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    productRepo = DriftProductRepository(db);
    orderRepo = DriftOrderRepository(db);
    cashRepo = DriftCashDrawerRepository(db);
    poolRepo = SharedPrefsTicketPoolRepository(prefs);
    uow = DriftUnitOfWork(db);

    checkout = CheckoutUseCase(
      unitOfWork: uow,
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      now: () => DateTime(2026, 5, 7, 12),
    );
    cancel = CancelOrderUseCase(
      unitOfWork: uow,
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
    );

    // 商品マスタを2件登録
    await productRepo.upsert(
      const Product(id: 'p1', name: 'Yakisoba', price: Money(400), stock: 10),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('end-to-end: checkout persists everything atomically', () async {
    // ¥100 を 5 枚 seed
    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(100): 5}),
    );

    final Order order = await checkout.execute(
      draft: const CheckoutDraft(
        items: <OrderItem>[
          OrderItem(
            productId: 'p1',
            productName: 'Yakisoba',
            priceAtTime: Money(400),
            quantity: 2,
          ),
        ],
        receivedCash: Money(1000),
        cashDelta: <int, int>{1000: 1, 100: -2},
      ),
      flags: const FeatureFlags(),
    );

    // 注文・明細・整理券・在庫・金種・プールがすべて永続化されている
    expect(order.id, isPositive);
    expect(order.ticketNumber.value, 1);

    final Product? p = await productRepo.findById('p1');
    expect(p!.stock, 8);

    final CashDrawer drawer = await cashRepo.get();
    expect(drawer.totalAmount, const Money(1300));

    final pool = await poolRepo.load();
    expect(pool.inUseNumbers, contains(1));
  });

  test('end-to-end: cancel rolls everything back atomically', () async {
    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(100): 5}),
    );

    const FeatureFlags flags = FeatureFlags(
      
    );
    const Map<int, int> cashDelta = <int, int>{1000: 1, 100: -2};

    final Order placed = await checkout.execute(
      draft: const CheckoutDraft(
        items: <OrderItem>[
          OrderItem(
            productId: 'p1',
            productName: 'Yakisoba',
            priceAtTime: Money(400),
            quantity: 2,
          ),
        ],
        receivedCash: Money(1000),
        cashDelta: cashDelta,
      ),
      flags: flags,
    );

    await cancel.execute(
      orderId: placed.id,
      flags: flags,
      originalCashDelta: cashDelta,
    );

    final Product? p = await productRepo.findById('p1');
    expect(p!.stock, 10); // 元に戻る

    final CashDrawer drawer = await cashRepo.get();
    expect(drawer.totalAmount, const Money(500)); // seed money のみ

    final pool = await poolRepo.load();
    expect(pool.inUseNumbers, isNot(contains(placed.ticketNumber.value)));
    expect(pool.recentlyReleasedNumbers, contains(placed.ticketNumber.value));
  });
}

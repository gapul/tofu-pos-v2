import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_cash_drawer_repository.dart';
import 'package:tofu_pos/data/repositories/drift_operation_log_repository.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/data/repositories/drift_unit_of_work.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/entities/operation_log.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

/// 複数 Repository が同一の AppDatabase（in-memory）に対して
/// 整合的に動作することを検証する統合テスト。
///
/// 単体 Repository ごとのテストでは見つからない、相互依存の問題を捕捉する。
void main() {
  late AppDatabase db;
  late DriftUnitOfWork uow;
  late DriftProductRepository productRepo;
  late DriftOrderRepository orderRepo;
  late DriftCashDrawerRepository cashRepo;
  late DriftOperationLogRepository logRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    uow = DriftUnitOfWork(db);
    productRepo = DriftProductRepository(db);
    orderRepo = DriftOrderRepository(db);
    cashRepo = DriftCashDrawerRepository(db);
    logRepo = DriftOperationLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Database creates all tables (migration v1 onCreate)', () async {
    // 各テーブルに最小行を入れて INSERT が通ることを確認
    await productRepo.upsert(
      const Product(id: 'p1', name: 'P', price: Money(100), stock: 1),
    );
    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(100): 1}),
    );
    await logRepo.record(kind: 'test');

    expect(await productRepo.findAll(), hasLength(1));
    expect((await cashRepo.get()).totalAmount, const Money(100));
    expect(await logRepo.findRecent(), hasLength(1));
  });

  test('schemaVersion is 1', () {
    expect(db.schemaVersion, 1);
  });

  test('UnitOfWork rolls back on exception', () async {
    await productRepo.upsert(
      const Product(id: 'p1', name: 'P', price: Money(100), stock: 5),
    );

    bool didThrow = false;
    try {
      await uow.run<void>(() async {
        await productRepo.adjustStock('p1', -2); // stock = 3
        throw StateError('intentional');
      });
      // テストでは意図的に StateError を投げ、トランザクションロールバックを検証する。
      // ignore: avoid_catching_errors
    } on StateError {
      didThrow = true;
    }
    expect(didThrow, isTrue);

    final Product? p = await productRepo.findById('p1');
    expect(
      p!.stock,
      5,
      reason: 'transaction should roll back, stock unchanged',
    );
  });

  test(
    'multi-repository checkout flow keeps cross-references intact',
    () async {
      // 商品登録 → 在庫減算 → 注文+明細登録 → 金種記録 → 操作ログ
      await productRepo.upsert(
        const Product(id: 'pizza', name: 'Pizza', price: Money(800), stock: 10),
      );
      await cashRepo.replace(
        CashDrawer(<Denomination, int>{const Denomination(100): 5}),
      );

      await uow.run<void>(() async {
        await productRepo.adjustStock('pizza', -1);
        await orderRepo.create(
          Order(
            id: 0,
            ticketNumber: const TicketNumber(1),
            items: const <OrderItem>[
              OrderItem(
                productId: 'pizza',
                productName: 'Pizza',
                priceAtTime: Money(800),
                quantity: 1,
              ),
            ],
            discount: Discount.none,
            receivedCash: const Money(1000),
            createdAt: DateTime(2026, 5, 7, 12),
            orderStatus: OrderStatus.unsent,
            syncStatus: SyncStatus.notSynced,
          ),
        );
        await cashRepo.apply(<Denomination, int>{
          const Denomination(1000): 1,
          const Denomination(100): -2,
        });
      });

      // すべて整合的に書き込まれている
      expect((await productRepo.findById('pizza'))!.stock, 9);
      final List<Order> orders = await orderRepo.findAll();
      expect(orders, hasLength(1));
      expect(orders.single.items.single.productId, 'pizza');
      expect((await cashRepo.get()).totalAmount, const Money(1300));
    },
  );

  test('OrderItem cascade delete (FK)', () async {
    // FK が cascade で削除されることを確認するため、注文を作って
    // テーブル直接 DELETE で動作確認。
    await orderRepo.create(
      Order(
        id: 0,
        ticketNumber: const TicketNumber(1),
        items: const <OrderItem>[
          OrderItem(
            productId: 'p',
            productName: 'P',
            priceAtTime: Money(100),
            quantity: 1,
          ),
        ],
        discount: Discount.none,
        receivedCash: const Money(100),
        createdAt: DateTime(2026, 5, 7),
        orderStatus: OrderStatus.served,
        syncStatus: SyncStatus.synced,
      ),
    );

    final int beforeItemCount = (await db.select(db.orderItems).get()).length;
    expect(beforeItemCount, 1);

    // FK は cascade onDelete を持つので、orders の行を直接消すと
    // order_items も消える。
    await db.delete(db.orders).go();
    final int afterItemCount = (await db.select(db.orderItems).get()).length;
    expect(afterItemCount, 0);
  });

  test(
    'OperationLog ordering: oldest stays first by id when same timestamp',
    () async {
      final DateTime t = DateTime(2026, 5, 7, 12);
      await logRepo.record(kind: 'a', at: t);
      await logRepo.record(kind: 'b', at: t);
      await logRepo.record(kind: 'c', at: t);

      final List<OperationLog> recent = await logRepo.findRecent();
      expect(recent.map((OperationLog l) => l.kind), <String>['c', 'b', 'a']);
    },
  );

  test('CashDrawer is independent across replace calls', () async {
    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(100): 5}),
    );
    expect((await cashRepo.get()).countOf(const Denomination(100)), 5);

    await cashRepo.replace(
      CashDrawer(<Denomination, int>{const Denomination(1000): 2}),
    );
    final CashDrawer drawer = await cashRepo.get();
    expect(drawer.countOf(const Denomination(100)), 0);
    expect(drawer.countOf(const Denomination(1000)), 2);
  });
}

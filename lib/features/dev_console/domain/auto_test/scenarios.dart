import '../../../../core/error/app_exceptions.dart';
import '../../../../domain/entities/cash_drawer.dart';
import '../../../../domain/entities/order.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/enums/order_status.dart';
import '../../../../domain/enums/sync_status.dart';
import '../../../../domain/value_objects/checkout_draft.dart';
import '../../../../domain/value_objects/denomination.dart';
import '../../../../domain/value_objects/discount.dart';
import '../../../../domain/value_objects/feature_flags.dart';
import '../../../../domain/value_objects/money.dart';
import '../../../../domain/value_objects/ticket_number.dart';
import '../../../../domain/value_objects/ticket_number_pool.dart';
import 'scenario.dart';
import 'scenario_context.dart';
import 'transport_scenarios.dart';

/// すべての標準シナリオ。
List<TestScenario> defaultScenarios() => <TestScenario>[
  _smokeCheckoutScenario,
  _stockDecrementsScenario,
  _stockInsufficientScenario,
  _cancelRollbackScenario,
  _cashDrawerScenario,
  _ticketSequenceScenario,
  _ticketPoolExhaustionScenario,
  _operationLogScenario,
  _hourlyAggregationScenario,
  _csvExportScenario,
  // 通信経路（online / LAN / BT / peer roundtrip）系。
  // 前提が満たされなければ ScenarioResult.skip で中立に返る。
  ...transportScenarios(),
];

// === 共通ヘルパ ===

Future<Product> _seedProduct(
  ScenarioContext ctx, {
  String id = 'p1',
  String name = 'Yakisoba',
  int priceYen = 400,
  int stock = 10,
}) async {
  final Product p = Product(
    id: id,
    name: name,
    price: Money(priceYen),
    stock: stock,
  );
  await ctx.productRepo.upsert(p);
  return p;
}

CheckoutDraft _draft(
  Product p, {
  int qty = 1,
  Discount discount = Discount.none,
  Money? receivedCash,
  Map<int, int> cashDelta = const <int, int>{},
}) {
  return CheckoutDraft(
    items: <OrderItem>[
      OrderItem(
        productId: p.id,
        productName: p.name,
        priceAtTime: p.price,
        quantity: qty,
      ),
    ],
    discount: discount,
    receivedCash: receivedCash ?? p.price * qty,
    cashDelta: cashDelta,
  );
}

// === シナリオ実装 ===

const TestScenario _smokeCheckoutScenario = TestScenario(
  id: 'smoke_checkout',
  name: '会計の煙テスト',
  description: '商品1点を全フラグオフで会計確定し、注文が保存されているか',
  run: _runSmokeCheckout,
);

Future<ScenarioResult> _runSmokeCheckout(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx);
  final Order saved = await ctx.checkout.execute(
    draft: _draft(p),
    flags: FeatureFlags.allOff,
  );
  if (saved.id <= 0) {
    return ScenarioResult.fail('order id should be assigned');
  }
  if (saved.ticketNumber.value != 1) {
    return ScenarioResult.fail(
      'expected ticket=1, got ${saved.ticketNumber.value}',
    );
  }
  if (saved.totalPrice != const Money(400)) {
    return ScenarioResult.fail('totalPrice mismatch: ${saved.totalPrice}');
  }
  return ScenarioResult.pass(
    'order #${saved.id} ticket=${saved.ticketNumber} ${saved.finalPrice}',
  );
}

const TestScenario _stockDecrementsScenario = TestScenario(
  id: 'stock_decrement',
  name: '在庫減算',
  description: '在庫管理オン時、会計確定で在庫が正しく減るか',
  run: _runStockDecrement,
);

Future<ScenarioResult> _runStockDecrement(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, stock: 5);
  await ctx.checkout.execute(
    draft: _draft(p, qty: 2),
    flags: const FeatureFlags(),
  );
  final Product? after = await ctx.productRepo.findById(p.id);
  if (after?.stock != 3) {
    return ScenarioResult.fail('expected stock=3, got ${after?.stock}');
  }
  return ScenarioResult.pass('stock decreased 5 → 3');
}

const TestScenario _stockInsufficientScenario = TestScenario(
  id: 'stock_insufficient',
  name: '在庫不足エラー',
  description: '在庫を超える数量での会計が InsufficientStockException で拒否されるか',
  run: _runStockInsufficient,
);

Future<ScenarioResult> _runStockInsufficient(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, stock: 1);
  try {
    await ctx.checkout.execute(
      draft: _draft(p, qty: 5),
      flags: const FeatureFlags(),
    );
    return ScenarioResult.fail('expected exception was not thrown');
  } on InsufficientStockException {
    return ScenarioResult.pass(
      'correctly rejected with InsufficientStockException',
    );
  } catch (e) {
    return ScenarioResult.fail('unexpected exception: $e');
  }
}

const TestScenario _cancelRollbackScenario = TestScenario(
  id: 'cancel_rollback',
  name: '取消の完全ロールバック',
  description: '取消で在庫・金種・整理券プールが元に戻るか',
  run: _runCancelRollback,
);

Future<ScenarioResult> _runCancelRollback(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx);
  await ctx.cashRepo.replace(
    CashDrawer(<Denomination, int>{const Denomination(100): 5}),
  );
  const FeatureFlags flags = FeatureFlags(
    
  );
  const Map<int, int> delta = <int, int>{1000: 1, 100: -2};
  final Order saved = await ctx.checkout.execute(
    draft: _draft(p, qty: 2, cashDelta: delta, receivedCash: const Money(1000)),
    flags: flags,
  );
  await ctx.cancel.execute(
    orderId: saved.id,
    flags: flags,
    originalCashDelta: delta,
  );

  final Product? prodAfter = await ctx.productRepo.findById(p.id);
  if (prodAfter?.stock != 10) {
    return ScenarioResult.fail('stock not restored: ${prodAfter?.stock}');
  }
  final CashDrawer drawerAfter = await ctx.cashRepo.get();
  if (drawerAfter.totalAmount != const Money(500)) {
    return ScenarioResult.fail(
      'drawer not restored: ${drawerAfter.totalAmount}',
    );
  }
  final TicketNumberPool pool = await ctx.poolRepo.load();
  if (pool.inUseNumbers.contains(saved.ticketNumber.value)) {
    return ScenarioResult.fail('ticket still in use');
  }
  return ScenarioResult.pass('stock+cash+ticket all rolled back');
}

const TestScenario _cashDrawerScenario = TestScenario(
  id: 'cash_drawer',
  name: '金種の入出金',
  description: '預り金と釣り銭の金種別入出金が正しく drawer に反映されるか',
  run: _runCashDrawer,
);

Future<ScenarioResult> _runCashDrawer(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, priceYen: 800);
  await ctx.cashRepo.replace(
    CashDrawer(<Denomination, int>{const Denomination(100): 5}),
  );
  await ctx.checkout.execute(
    draft: _draft(
      p,
      receivedCash: const Money(1000),
      cashDelta: const <int, int>{1000: 1, 100: -2},
    ),
    flags: const FeatureFlags(),
  );
  final CashDrawer d = await ctx.cashRepo.get();
  if (d.totalAmount != const Money(1300)) {
    return ScenarioResult.fail('expected total=¥1300, got ${d.totalAmount}');
  }
  return ScenarioResult.pass('drawer total=${d.totalAmount}');
}

const TestScenario _ticketSequenceScenario = TestScenario(
  id: 'ticket_sequence',
  name: '整理券番号が1から順',
  description: '5回連続で会計確定して 1〜5 の整理券番号が振られるか',
  run: _runTicketSequence,
);

Future<ScenarioResult> _runTicketSequence(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, stock: 100);
  final List<int> issued = <int>[];
  for (int i = 0; i < 5; i++) {
    final Order o = await ctx.checkout.execute(
      draft: _draft(p),
      flags: FeatureFlags.allOff,
    );
    issued.add(o.ticketNumber.value);
  }
  if (issued.toString() != '[1, 2, 3, 4, 5]') {
    return ScenarioResult.fail('expected [1,2,3,4,5], got $issued');
  }
  return ScenarioResult.pass('ticket sequence $issued');
}

const TestScenario _ticketPoolExhaustionScenario = TestScenario(
  id: 'ticket_pool_exhaustion',
  name: '整理券プール満杯',
  description: '小さな整理券プールで満杯になったら会計拒否される',
  run: _runTicketPoolExhaustion,
);

Future<ScenarioResult> _runTicketPoolExhaustion(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx);
  await ctx.poolRepo.save(TicketNumberPool.empty(maxNumber: 2, bufferSize: 0));
  await ctx.checkout.execute(draft: _draft(p), flags: FeatureFlags.allOff);
  await ctx.checkout.execute(draft: _draft(p), flags: FeatureFlags.allOff);
  try {
    await ctx.checkout.execute(draft: _draft(p), flags: FeatureFlags.allOff);
    return ScenarioResult.fail('expected exhaustion exception');
  } on TicketPoolExhaustedException {
    return ScenarioResult.pass('correctly blocked at pool exhaustion');
  } catch (e) {
    return ScenarioResult.fail('unexpected exception: $e');
  }
}

const TestScenario _operationLogScenario = TestScenario(
  id: 'operation_log',
  name: '取消ログの記録',
  description: '取消すると operation_logs に kind=cancel_order が記録されるか',
  run: _runOperationLog,
);

Future<ScenarioResult> _runOperationLog(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx);
  final Order saved = await ctx.checkout.execute(
    draft: _draft(p),
    flags: FeatureFlags.allOff,
  );
  await ctx.cancel.execute(
    orderId: saved.id,
    flags: FeatureFlags.allOff,
    originalCashDelta: const <int, int>{},
  );
  final logs = await ctx.logRepo.findRecent();
  final cancelLog = logs.where((e) => e.kind == 'cancel_order').toList();
  if (cancelLog.isEmpty) {
    return ScenarioResult.fail('no cancel_order log');
  }
  if (cancelLog.first.targetId != saved.id.toString()) {
    return ScenarioResult.fail(
      'targetId mismatch: ${cancelLog.first.targetId} vs ${saved.id}',
    );
  }
  return ScenarioResult.pass(
    'cancel_order log #${cancelLog.first.id} recorded',
  );
}

const TestScenario _hourlyAggregationScenario = TestScenario(
  id: 'hourly_aggregation',
  name: '時間帯別集計',
  description: '異なる時刻の注文が時間別バケットに正しく振り分けられるか',
  run: _runHourlyAggregation,
);

Future<ScenarioResult> _runHourlyAggregation(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, priceYen: 500, stock: 100);
  final DateTime today = DateTime.now();
  Order orderAt(int ticket, DateTime at) => Order(
    id: 0,
    ticketNumber: TicketNumber(ticket),
    items: <OrderItem>[
      OrderItem(
        productId: p.id,
        productName: p.name,
        priceAtTime: p.price,
        quantity: 1,
      ),
    ],
    discount: Discount.none,
    receivedCash: p.price,
    createdAt: at,
    orderStatus: OrderStatus.served,
    syncStatus: SyncStatus.synced,
  );

  await ctx.orderRepo.create(
    orderAt(1, DateTime(today.year, today.month, today.day, 10, 30)),
  );
  await ctx.orderRepo.create(
    orderAt(2, DateTime(today.year, today.month, today.day, 14)),
  );

  final buckets = await ctx.hourly.getActiveHourly();
  if (buckets.length != 2) {
    return ScenarioResult.fail('expected 2 buckets, got ${buckets.length}');
  }
  final hours = buckets.map((b) => b.hour).toList();
  if (!hours.contains(10) || !hours.contains(14)) {
    return ScenarioResult.fail('hours mismatch: $hours');
  }
  return ScenarioResult.pass('aggregated into hours $hours');
}

const TestScenario _csvExportScenario = TestScenario(
  id: 'csv_export',
  name: 'CSV 出力',
  description: '会計確定済の注文を CSV にシリアライズしてヘッダ＋明細行が揃うか',
  run: _runCsvExport,
);

Future<ScenarioResult> _runCsvExport(ScenarioContext ctx) async {
  final Product p = await _seedProduct(ctx, priceYen: 300, stock: 100);
  await ctx.checkout.execute(
    draft: _draft(p, qty: 2),
    flags: FeatureFlags.allOff,
  );
  final orders = await ctx.orderRepo.findAll();
  final csv = ctx.csv.serialize(orders: orders, shopId: 'shop_a');
  final lines = csv.split('\r\n').where((s) => s.isNotEmpty).toList();
  if (lines.length < 2) {
    return ScenarioResult.fail('csv lines too few: ${lines.length}');
  }
  if (!lines.first.contains('order_id')) {
    return ScenarioResult.fail('header missing');
  }
  if (!lines[1].contains(p.name)) {
    return ScenarioResult.fail('product name not in row');
  }
  return ScenarioResult.pass('${lines.length - 1} csv rows generated');
}

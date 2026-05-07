import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/usecases/cancel_order_usecase.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/domain/cancel_order_flow_usecase.dart';

import '../../../fakes/fake_repositories.dart';

class _FailingTransport implements Transport {
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Stream<TransportEvent> events() => const Stream<TransportEvent>.empty();
  @override
  Future<void> send(TransportEvent event) {
    throw StateError('boom');
  }
}

void main() {
  late InMemoryProductRepository productRepo;
  late InMemoryOrderRepository orderRepo;
  late InMemoryCashDrawerRepository cashRepo;
  late InMemoryTicketPoolRepository poolRepo;
  late InMemoryOperationLogRepository logRepo;
  late CheckoutUseCase checkout;
  late CancelOrderUseCase cancelInner;

  const CheckoutDraft draft = CheckoutDraft(
    items: <OrderItem>[
      OrderItem(
        productId: 'p1',
        productName: 'Yakisoba',
        priceAtTime: Money(400),
        quantity: 1,
      ),
    ],
    receivedCash: Money(400),
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
    cancelInner = CancelOrderUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      operationLogRepository: logRepo,
    );
  });

  test('with both flags off: cancels locally, no transport send', () async {
    final NoopTransport transport = NoopTransport();
    final CancelOrderFlowUseCase u = CancelOrderFlowUseCase(
      cancelOrderUseCase: cancelInner,
      transport: transport,
      shopId: 'shop_a',
    );
    final Order placed = await checkout.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );
    final Order cancelled = await u.execute(
      orderId: placed.id,
      flags: FeatureFlags.allOff,
      originalCashDelta: const <int, int>{},
    );
    expect(cancelled.orderStatus, OrderStatus.cancelled);
    expect(transport.sent, isEmpty);
  });

  test('with kitchenLink on: sends OrderCancelledEvent', () async {
    final NoopTransport transport = NoopTransport();
    final CancelOrderFlowUseCase u = CancelOrderFlowUseCase(
      cancelOrderUseCase: cancelInner,
      transport: transport,
      shopId: 'shop_a',
    );
    final Order placed = await checkout.execute(
      draft: draft,
      flags: const FeatureFlags(kitchenLink: true),
    );
    await u.execute(
      orderId: placed.id,
      flags: const FeatureFlags(kitchenLink: true),
      originalCashDelta: const <int, int>{},
    );
    expect(transport.sent.single, isA<OrderCancelledEvent>());
    final OrderCancelledEvent ev = transport.sent.single as OrderCancelledEvent;
    expect(ev.orderId, placed.id);
    expect(ev.ticketNumber, placed.ticketNumber);
    expect(ev.shopId, 'shop_a');
  });

  test('with callingLink on: sends OrderCancelledEvent', () async {
    final NoopTransport transport = NoopTransport();
    final CancelOrderFlowUseCase u = CancelOrderFlowUseCase(
      cancelOrderUseCase: cancelInner,
      transport: transport,
      shopId: 'shop_a',
    );
    final Order placed = await checkout.execute(
      draft: draft,
      flags: const FeatureFlags(callingLink: true),
    );
    await u.execute(
      orderId: placed.id,
      flags: const FeatureFlags(callingLink: true),
      originalCashDelta: const <int, int>{},
    );
    expect(transport.sent.single, isA<OrderCancelledEvent>());
  });

  test('on transport failure: cancellation persists, error thrown', () async {
    final CancelOrderFlowUseCase u = CancelOrderFlowUseCase(
      cancelOrderUseCase: cancelInner,
      transport: _FailingTransport(),
      shopId: 'shop_a',
    );
    final Order placed = await checkout.execute(
      draft: draft,
      flags: const FeatureFlags(kitchenLink: true),
    );

    expect(
      () => u.execute(
        orderId: placed.id,
        flags: const FeatureFlags(kitchenLink: true),
        originalCashDelta: const <int, int>{},
      ),
      throwsA(isA<TransportDeliveryException>()),
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    final Order? after = await orderRepo.findById(placed.id);
    expect(after!.orderStatus, OrderStatus.cancelled,
        reason: '通信失敗してもローカル取消は完了している');
  });
}

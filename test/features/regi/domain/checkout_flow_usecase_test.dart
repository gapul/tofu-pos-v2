import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/domain/checkout_flow_usecase.dart';

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
    throw StateError('simulated send failure');
  }
}

void main() {
  late InMemoryProductRepository productRepo;
  late InMemoryOrderRepository orderRepo;
  late InMemoryCashDrawerRepository cashRepo;
  late InMemoryTicketPoolRepository poolRepo;
  late CheckoutUseCase checkout;

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
  );

  setUp(() {
    productRepo = InMemoryProductRepository(<Product>[
      const Product(id: 'p1', name: 'Yakisoba', price: Money(400), stock: 10),
    ]);
    orderRepo = InMemoryOrderRepository();
    cashRepo = InMemoryCashDrawerRepository();
    poolRepo = InMemoryTicketPoolRepository();
    checkout = CheckoutUseCase(
      unitOfWork: InMemoryUnitOfWork(),
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
    );
  });

  test('with kitchenLink off: saves and skips transport send', () async {
    final NoopTransport transport = NoopTransport();
    final CheckoutFlowUseCase flow = CheckoutFlowUseCase(
      checkoutUseCase: checkout,
      transport: transport,
      orderRepository: orderRepo,
      shopId: 'shop_a',
    );

    final Order order = await flow.execute(
      draft: draft,
      flags: FeatureFlags.allOff,
    );

    expect(order.orderStatus, OrderStatus.unsent);
    expect(transport.sent, isEmpty);
  });

  test(
    'with kitchenLink on: sends OrderSubmittedEvent and marks sent',
    () async {
      final NoopTransport transport = NoopTransport();
      final CheckoutFlowUseCase flow = CheckoutFlowUseCase(
        checkoutUseCase: checkout,
        transport: transport,
        orderRepository: orderRepo,
        shopId: 'shop_a',
      );

      final Order order = await flow.execute(
        draft: draft,
        flags: const FeatureFlags(kitchenLink: true),
      );

      expect(order.orderStatus, OrderStatus.sent);
      expect(transport.sent, hasLength(1));
      final TransportEvent ev = transport.sent.single;
      expect(ev, isA<OrderSubmittedEvent>());
      expect(ev.shopId, 'shop_a');
      expect(ev.isHighPriority, isTrue);
      final OrderSubmittedEvent submitted = ev as OrderSubmittedEvent;
      expect(submitted.orderId, order.id);
      expect(submitted.ticketNumber, order.ticketNumber);
      expect(submitted.itemsJson, contains('Yakisoba'));
    },
  );

  test(
    'on transport failure: order is still saved (unsent), error thrown',
    () async {
      final CheckoutFlowUseCase flow = CheckoutFlowUseCase(
        checkoutUseCase: checkout,
        transport: _FailingTransport(),
        orderRepository: orderRepo,
        shopId: 'shop_a',
      );

      expect(
        () => flow.execute(
          draft: draft,
          flags: const FeatureFlags(kitchenLink: true),
        ),
        throwsA(isA<TransportDeliveryException>()),
      );

      // 例外発生後でも、ローカル保存は完了している（データ厳格性 §1.2）
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final List<Order> saved = await orderRepo.findAll();
      expect(saved, hasLength(1));
      expect(saved.single.orderStatus, OrderStatus.unsent);
    },
  );
}

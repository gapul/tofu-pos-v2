import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_alert.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_ingest_router.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_ingest_usecase.dart';
import 'package:tofu_pos/features/kitchen/domain/product_master_ingest_usecase.dart';

import '../../../fakes/fake_repositories.dart';

class _FakeTransport implements Transport {
  final StreamController<TransportEvent> incoming =
      StreamController<TransportEvent>.broadcast();
  final List<TransportEvent> sent = <TransportEvent>[];

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {
    await incoming.close();
  }
  @override
  Stream<TransportEvent> events() => incoming.stream;
  @override
  Future<void> send(TransportEvent event) async {
    sent.add(event);
  }
}

void main() {
  late InMemoryKitchenOrderRepository kitchenRepo;
  late InMemoryProductRepository productRepo;
  late KitchenIngestUseCase ingest;
  late ProductMasterIngestUseCase productIngest;
  late _FakeTransport transport;
  late KitchenIngestRouter router;

  setUp(() {
    kitchenRepo = InMemoryKitchenOrderRepository();
    productRepo = InMemoryProductRepository(<Product>[]);
    ingest = KitchenIngestUseCase(repository: kitchenRepo);
    productIngest =
        ProductMasterIngestUseCase(productRepository: productRepo);
    transport = _FakeTransport();
    router = KitchenIngestRouter(
      transport: transport,
      ingest: ingest,
      productIngest: productIngest,
      shopId: 'shop',
    );
  });

  tearDown(() async {
    await router.stop();
    await ingest.dispose();
  });

  test('OrderSubmitted ingested into kitchen repo', () async {
    router.start();
    transport.incoming.add(OrderSubmittedEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[{"name":"a","qty":1}]',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final saved = await kitchenRepo.findByOrderId(1);
    expect(saved, isNotNull);
    expect(saved!.status, KitchenStatus.pending);
  });

  test('OrderCancelled flips status and emits alert if mid-process', () async {
    await kitchenRepo.upsert(KitchenOrder(
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[]',
      status: KitchenStatus.done,
      receivedAt: DateTime(2026, 5, 7, 12),
    ));
    final List<KitchenAlert> alerts = <KitchenAlert>[];
    final sub = ingest.alerts.listen(alerts.add);

    router.start();
    transport.incoming.add(OrderCancelledEvent(
      shopId: 'shop',
      eventId: 'c1',
      occurredAt: DateTime(2026, 5, 7, 12, 30),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      (await kitchenRepo.findByOrderId(1))!.status,
      KitchenStatus.cancelled,
    );
    expect(alerts, hasLength(1));
    expect(alerts.single.kind, KitchenAlertKind.cancelledMidProcess);
    await sub.cancel();
  });

  test('OrderCancelled does NOT alert if was pending', () async {
    await kitchenRepo.upsert(KitchenOrder(
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[]',
      status: KitchenStatus.pending,
      receivedAt: DateTime(2026, 5, 7, 12),
    ));
    final List<KitchenAlert> alerts = <KitchenAlert>[];
    final sub = ingest.alerts.listen(alerts.add);

    router.start();
    transport.incoming.add(OrderCancelledEvent(
      shopId: 'shop',
      eventId: 'c1',
      occurredAt: DateTime(2026, 5, 7, 12, 30),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(alerts, isEmpty);
    await sub.cancel();
  });

  test('ProductMasterUpdate ingested into product repo', () async {
    router.start();
    transport.incoming.add(ProductMasterUpdateEvent(
      shopId: 'shop',
      eventId: 'p1',
      occurredAt: DateTime(2026, 5, 7, 12),
      productsJson:
          '[{"id":"p1","name":"Yakisoba","price_yen":400,"stock":10}]',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final products = await productRepo.findAll();
    expect(products, hasLength(1));
    expect(products.first.name, 'Yakisoba');
    expect(products.first.price, const Money(400));
  });

  test('foreign shop_id events are ignored', () async {
    router.start();
    transport.incoming.add(OrderSubmittedEvent(
      shopId: 'OTHER',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[]',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await kitchenRepo.findByOrderId(1), isNull);
  });
}

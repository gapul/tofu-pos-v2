import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/kitchen/domain/kitchen_ingest_usecase.dart';

import '../../../fakes/fake_repositories.dart';

void main() {
  late InMemoryKitchenOrderRepository repo;
  late KitchenIngestUseCase usecase;

  setUp(() {
    repo = InMemoryKitchenOrderRepository();
    usecase = KitchenIngestUseCase(
      repository: repo,
      now: () => DateTime(2026, 5, 7, 12),
    );
  });

  test('ingestSubmitted persists as pending', () async {
    final OrderSubmittedEvent ev = OrderSubmittedEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[{"name":"yakisoba","qty":2}]',
    );
    await usecase.ingestSubmitted(ev);

    final KitchenOrder? saved = await repo.findByOrderId(1);
    expect(saved, isNotNull);
    expect(saved!.status, KitchenStatus.pending);
    expect(saved.ticketNumber.value, 7);
    expect(saved.itemsJson, contains('yakisoba'));
  });

  test('ingestSubmitted is idempotent (re-receive overwrites)', () async {
    final OrderSubmittedEvent first = OrderSubmittedEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[{"qty":1}]',
    );
    await usecase.ingestSubmitted(first);
    final OrderSubmittedEvent second = OrderSubmittedEvent(
      shopId: 'shop',
      eventId: 'e1-retry',
      occurredAt: DateTime(2026, 5, 7, 12, 1),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[{"qty":2}]',
    );
    await usecase.ingestSubmitted(second);
    final KitchenOrder? saved = await repo.findByOrderId(1);
    expect(saved!.itemsJson, contains('"qty":2'));
  });

  test('ingestCancelled flips existing order to cancelled', () async {
    await repo.upsert(
      KitchenOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[]',
        status: KitchenStatus.pending,
        receivedAt: DateTime(2026, 5, 7, 12),
      ),
    );
    await usecase.ingestCancelled(
      OrderCancelledEvent(
        shopId: 'shop',
        eventId: 'c1',
        occurredAt: DateTime(2026, 5, 7, 12, 30),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    final KitchenOrder? after = await repo.findByOrderId(1);
    expect(after!.status, KitchenStatus.cancelled);
  });

  test('ingestCancelled is no-op when order is unknown', () async {
    await usecase.ingestCancelled(
      OrderCancelledEvent(
        shopId: 'shop',
        eventId: 'c1',
        occurredAt: DateTime(2026, 5, 7, 12, 30),
        orderId: 999,
        ticketNumber: const TicketNumber(99),
      ),
    );
    expect(await repo.findAll(), isEmpty);
  });
}

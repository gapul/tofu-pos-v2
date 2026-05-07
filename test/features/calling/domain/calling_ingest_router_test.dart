import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/calling_order.dart';
import 'package:tofu_pos/domain/enums/calling_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/calling/domain/calling_ingest_router.dart';
import 'package:tofu_pos/features/calling/domain/calling_ingest_usecase.dart';

import '../../../fakes/fake_repositories.dart';

class _FakeTransport implements Transport {
  final StreamController<TransportEvent> incoming =
      StreamController<TransportEvent>.broadcast();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {
    await incoming.close();
  }

  @override
  Stream<TransportEvent> events() => incoming.stream;
  @override
  Future<void> send(TransportEvent event) async {}
}

void main() {
  late InMemoryCallingOrderRepository repo;
  late CallingIngestUseCase ingest;
  late _FakeTransport transport;
  late CallingIngestRouter router;

  setUp(() {
    repo = InMemoryCallingOrderRepository();
    ingest = CallingIngestUseCase(repository: repo);
    transport = _FakeTransport();
    router = CallingIngestRouter(
      transport: transport,
      ingest: ingest,
      shopId: 'shop',
    );
  });

  tearDown(() => router.stop());

  test('CallNumberEvent is ingested as pending', () async {
    router.start();
    transport.incoming.add(
      CallNumberEvent(
        shopId: 'shop',
        eventId: 'c1',
        occurredAt: DateTime(2026, 5, 7, 12),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final saved = await repo.findByOrderId(1);
    expect(saved, isNotNull);
    expect(saved!.status, CallingStatus.pending);
  });

  test('OrderCancelled flips existing to cancelled', () async {
    await repo.upsert(
      CallingOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        status: CallingStatus.pending,
        receivedAt: DateTime(2026, 5, 7, 12),
      ),
    );
    router.start();
    transport.incoming.add(
      OrderCancelledEvent(
        shopId: 'shop',
        eventId: 'x1',
        occurredAt: DateTime(2026, 5, 7, 12, 10),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await repo.findByOrderId(1))!.status, CallingStatus.cancelled);
  });

  test('foreign shop_id is ignored', () async {
    router.start();
    transport.incoming.add(
      CallNumberEvent(
        shopId: 'OTHER',
        eventId: 'c1',
        occurredAt: DateTime(2026, 5, 7, 12),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await repo.findByOrderId(1), isNull);
  });

  test('non-relevant events (OrderSubmitted) are ignored', () async {
    router.start();
    transport.incoming.add(
      OrderSubmittedEvent(
        shopId: 'shop',
        eventId: 's1',
        occurredAt: DateTime(2026, 5, 7, 12),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[]',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(await repo.findAll(), isEmpty);
  });
}

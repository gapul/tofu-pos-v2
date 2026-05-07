import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/calling_order.dart';
import 'package:tofu_pos/domain/enums/calling_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/calling/domain/calling_ingest_usecase.dart';

import '../../../fakes/fake_repositories.dart';

void main() {
  late InMemoryCallingOrderRepository repo;
  late CallingIngestUseCase usecase;

  setUp(() {
    repo = InMemoryCallingOrderRepository();
    usecase = CallingIngestUseCase(
      repository: repo,
      now: () => DateTime(2026, 5, 7, 12),
    );
  });

  test('ingestCallNumber persists as pending', () async {
    await usecase.ingestCallNumber(CallNumberEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    ));
    final CallingOrder? saved = await repo.findByOrderId(1);
    expect(saved!.status, CallingStatus.pending);
    expect(saved.ticketNumber.value, 7);
  });

  test('ingestCancelled flips existing to cancelled', () async {
    await repo.upsert(CallingOrder(
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      status: CallingStatus.pending,
      receivedAt: DateTime(2026, 5, 7, 12),
    ));
    await usecase.ingestCancelled(OrderCancelledEvent(
      shopId: 'shop',
      eventId: 'c1',
      occurredAt: DateTime(2026, 5, 7, 12, 30),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    ));
    expect((await repo.findByOrderId(1))!.status, CallingStatus.cancelled);
  });

  test('ingestCancelled is no-op for unknown order', () async {
    await usecase.ingestCancelled(OrderCancelledEvent(
      shopId: 'shop',
      eventId: 'c1',
      occurredAt: DateTime(2026, 5, 7, 12, 30),
      orderId: 999,
      ticketNumber: const TicketNumber(99),
    ));
    expect(await repo.findAll(), isEmpty);
  });

  test('markCalled and undoCall flip the status', () async {
    await repo.upsert(CallingOrder(
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      status: CallingStatus.pending,
      receivedAt: DateTime(2026, 5, 7, 12),
    ));
    await usecase.markCalled(1);
    expect((await repo.findByOrderId(1))!.status, CallingStatus.called);
    await usecase.undoCall(1);
    expect((await repo.findByOrderId(1))!.status, CallingStatus.pending);
  });
}

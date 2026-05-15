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
    await usecase.ingestCallNumber(
      CallNumberEvent(
        shopId: 'shop',
        eventId: 'e1',
        occurredAt: DateTime(2026, 5, 7, 12),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    final CallingOrder? saved = await repo.findByOrderId(1);
    expect(saved!.status, CallingStatus.pending);
    expect(saved.ticketNumber.value, 7);
  });

  test(
    'ingestCallNumber preserves existing status on backfill replay '
    '(bug: called orders must not revert to pending)',
    () async {
      // 既に「呼び出し済 (called)」状態。
      await repo.upsert(
        CallingOrder(
          orderId: 1,
          ticketNumber: const TicketNumber(7),
          status: CallingStatus.called,
          receivedAt: DateTime(2026, 5, 7, 11),
        ),
      );
      await usecase.ingestCallNumber(
        CallNumberEvent(
          shopId: 'shop',
          eventId: 'e1',
          occurredAt: DateTime(2026, 5, 7, 11),
          orderId: 1,
          ticketNumber: const TicketNumber(7),
        ),
      );
      expect(
        (await repo.findByOrderId(1))!.status,
        CallingStatus.called,
        reason: 'replay は called を pending に巻き戻してはならない',
      );
    },
  );

  test('ingestCallNumber preserves pickedUp status on backfill replay', () async {
    await repo.upsert(
      CallingOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        status: CallingStatus.pickedUp,
        receivedAt: DateTime(2026, 5, 7, 11),
      ),
    );
    await usecase.ingestCallNumber(
      CallNumberEvent(
        shopId: 'shop',
        eventId: 'e1',
        occurredAt: DateTime(2026, 5, 7, 11),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
      ),
    );
    expect((await repo.findByOrderId(1))!.status, CallingStatus.pickedUp);
  });

  test('ingestCancelled flips existing to cancelled', () async {
    await repo.upsert(
      CallingOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        status: CallingStatus.pending,
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
    expect((await repo.findByOrderId(1))!.status, CallingStatus.cancelled);
  });

  test('ingestCancelled is no-op for unknown order', () async {
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

  test('ingestSubmitted persists as awaitingKitchen', () async {
    await usecase.ingestSubmitted(
      OrderSubmittedEvent(
        shopId: 'shop',
        eventId: 's1',
        occurredAt: DateTime(2026, 5, 7, 12),
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[]',
      ),
    );
    final CallingOrder? saved = await repo.findByOrderId(1);
    expect(saved, isNotNull);
    expect(saved!.status, CallingStatus.awaitingKitchen);
    expect(saved.ticketNumber.value, 7);
  });

  test(
    'ingestSubmitted preserves existing pending/called/pickedUp status '
    '(replay safe)',
    () async {
      for (final CallingStatus initial in <CallingStatus>[
        CallingStatus.pending,
        CallingStatus.called,
        CallingStatus.pickedUp,
        CallingStatus.cancelled,
      ]) {
        await repo.upsert(
          CallingOrder(
            orderId: 10,
            ticketNumber: const TicketNumber(7),
            status: initial,
            receivedAt: DateTime(2026, 5, 7, 11),
          ),
        );
        await usecase.ingestSubmitted(
          OrderSubmittedEvent(
            shopId: 'shop',
            eventId: 's1',
            occurredAt: DateTime(2026, 5, 7, 12),
            orderId: 10,
            ticketNumber: const TicketNumber(7),
            itemsJson: '[]',
          ),
        );
        expect(
          (await repo.findByOrderId(10))!.status,
          initial,
          reason: 'ingestSubmitted は $initial を上書きしてはならない',
        );
      }
    },
  );

  test(
    'ingestCallNumber promotes awaitingKitchen → pending (popup-eligible)',
    () async {
      await repo.upsert(
        CallingOrder(
          orderId: 1,
          ticketNumber: const TicketNumber(7),
          status: CallingStatus.awaitingKitchen,
          receivedAt: DateTime(2026, 5, 7, 11),
        ),
      );
      await usecase.ingestCallNumber(
        CallNumberEvent(
          shopId: 'shop',
          eventId: 'c1',
          occurredAt: DateTime(2026, 5, 7, 12),
          orderId: 1,
          ticketNumber: const TicketNumber(7),
        ),
      );
      expect((await repo.findByOrderId(1))!.status, CallingStatus.pending);
    },
  );

  test('markCalled and undoCall flip the status', () async {
    await repo.upsert(
      CallingOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        status: CallingStatus.pending,
        receivedAt: DateTime(2026, 5, 7, 12),
      ),
    );
    await usecase.markCalled(1);
    expect((await repo.findByOrderId(1))!.status, CallingStatus.called);
    await usecase.undoCall(1);
    expect((await repo.findByOrderId(1))!.status, CallingStatus.pending);
  });
}

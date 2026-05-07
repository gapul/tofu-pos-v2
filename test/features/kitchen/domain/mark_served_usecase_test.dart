import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/entities/kitchen_order.dart';
import 'package:tofu_pos/domain/enums/kitchen_status.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/kitchen/domain/mark_served_usecase.dart';

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
  late InMemoryKitchenOrderRepository repo;

  setUp(() async {
    repo = InMemoryKitchenOrderRepository();
    await repo.upsert(
      KitchenOrder(
        orderId: 1,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[]',
        status: KitchenStatus.pending,
        receivedAt: DateTime(2026, 5, 7, 12),
      ),
    );
  });

  test('marks done and sends OrderServedEvent', () async {
    final NoopTransport transport = NoopTransport();
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: transport,
      shopId: 'shop_a',
    );
    await u.execute(1);

    expect((await repo.findByOrderId(1))!.status, KitchenStatus.done);
    expect(transport.sent.single, isA<OrderServedEvent>());
    final OrderServedEvent ev = transport.sent.single as OrderServedEvent;
    expect(ev.orderId, 1);
    expect(ev.shopId, 'shop_a');
  });

  test('reverts to pending on transport failure', () async {
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: _FailingTransport(),
      shopId: 'shop_a',
    );
    expect(() => u.execute(1), throwsA(isA<TransportDeliveryException>()));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await repo.findByOrderId(1))!.status, KitchenStatus.pending);
  });

  test('rejects unknown order', () {
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: NoopTransport(),
      shopId: 'shop_a',
    );
    expect(() => u.execute(999), throwsA(isA<OrderNotCancellableException>()));
  });

  test('rejects cancelled order', () async {
    await repo.updateStatus(1, KitchenStatus.cancelled);
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: NoopTransport(),
      shopId: 'shop_a',
    );
    expect(() => u.execute(1), throwsA(isA<OrderNotCancellableException>()));
  });

  test('undo flips done back to pending', () async {
    await repo.updateStatus(1, KitchenStatus.done);
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: NoopTransport(),
      shopId: 'shop_a',
    );
    await u.undo(1);
    expect((await repo.findByOrderId(1))!.status, KitchenStatus.pending);
  });

  test('undo rejects when not in done state', () async {
    final MarkServedUseCase u = MarkServedUseCase(
      repository: repo,
      transport: NoopTransport(),
      shopId: 'shop_a',
    );
    expect(() => u.undo(1), throwsA(isA<OrderNotCancellableException>()));
  });
}

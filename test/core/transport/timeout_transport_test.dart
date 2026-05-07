import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/transport/noop_transport.dart';
import 'package:tofu_pos/core/transport/timeout_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

class _SlowTransport implements Transport {
  _SlowTransport(this.delay);
  final Duration delay;
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Stream<TransportEvent> events() => const Stream<TransportEvent>.empty();
  @override
  Future<void> send(TransportEvent event) async {
    await Future<void>.delayed(delay);
  }
}

OrderSubmittedEvent _ev() => OrderSubmittedEvent(
  shopId: 'shop',
  eventId: 'e1',
  occurredAt: DateTime(2026, 5, 7),
  orderId: 1,
  ticketNumber: const TicketNumber(1),
  itemsJson: '[]',
);

void main() {
  test('passes through send when within timeout', () async {
    final NoopTransport inner = NoopTransport();
    final TimeoutTransport t = TimeoutTransport(
      inner: inner,
      timeout: const Duration(milliseconds: 100),
    );
    await t.send(_ev());
    expect(inner.sent, hasLength(1));
  });

  test('throws TransportDeliveryException on timeout', () async {
    final TimeoutTransport t = TimeoutTransport(
      inner: _SlowTransport(const Duration(seconds: 5)),
      timeout: const Duration(milliseconds: 50),
    );
    expect(() => t.send(_ev()), throwsA(isA<TransportDeliveryException>()));
  });

  test('wraps inner exception as TransportDeliveryException', () async {
    final TimeoutTransport t = TimeoutTransport(
      inner: _ThrowingTransport(),
      timeout: const Duration(seconds: 1),
    );
    expect(() => t.send(_ev()), throwsA(isA<TransportDeliveryException>()));
  });
}

class _ThrowingTransport implements Transport {
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

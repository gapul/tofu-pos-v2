import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/data/datasources/lan/lan_protocol.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

void main() {
  final DateTime ts = DateTime.utc(2026, 5, 7, 12, 30);

  group('LanProtocol round-trip', () {
    test('ProductMasterUpdateEvent', () {
      final ProductMasterUpdateEvent original = ProductMasterUpdateEvent(
        shopId: 'shop_a',
        eventId: 'e1',
        occurredAt: ts,
        productsJson: '[{"id":"p1"}]',
      );
      final TransportEvent decoded =
          LanProtocol.decode(LanProtocol.encode(original));
      expect(decoded, isA<ProductMasterUpdateEvent>());
      final ProductMasterUpdateEvent r = decoded as ProductMasterUpdateEvent;
      expect(r.shopId, 'shop_a');
      expect(r.eventId, 'e1');
      expect(r.occurredAt, ts);
      expect(r.productsJson, '[{"id":"p1"}]');
      expect(r.isHighPriority, isFalse);
    });

    test('OrderSubmittedEvent', () {
      final OrderSubmittedEvent original = OrderSubmittedEvent(
        shopId: 'shop_a',
        eventId: 'e2',
        occurredAt: ts,
        orderId: 42,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[{"name":"yakisoba","qty":2}]',
      );
      final TransportEvent decoded =
          LanProtocol.decode(LanProtocol.encode(original));
      expect(decoded, isA<OrderSubmittedEvent>());
      final OrderSubmittedEvent r = decoded as OrderSubmittedEvent;
      expect(r.orderId, 42);
      expect(r.ticketNumber.value, 7);
      expect(r.itemsJson, '[{"name":"yakisoba","qty":2}]');
      expect(r.isHighPriority, isTrue);
    });

    test('OrderServedEvent', () {
      final OrderServedEvent original = OrderServedEvent(
        shopId: 'shop_a',
        eventId: 'e3',
        occurredAt: ts,
        orderId: 1,
        ticketNumber: const TicketNumber(2),
      );
      final TransportEvent decoded =
          LanProtocol.decode(LanProtocol.encode(original));
      expect(decoded, isA<OrderServedEvent>());
    });

    test('CallNumberEvent', () {
      final CallNumberEvent original = CallNumberEvent(
        shopId: 'shop_a',
        eventId: 'e4',
        occurredAt: ts,
        orderId: 1,
        ticketNumber: const TicketNumber(2),
      );
      final TransportEvent decoded =
          LanProtocol.decode(LanProtocol.encode(original));
      expect(decoded, isA<CallNumberEvent>());
    });

    test('OrderCancelledEvent', () {
      final OrderCancelledEvent original = OrderCancelledEvent(
        shopId: 'shop_a',
        eventId: 'e5',
        occurredAt: ts,
        orderId: 99,
        ticketNumber: const TicketNumber(11),
      );
      final TransportEvent decoded =
          LanProtocol.decode(LanProtocol.encode(original));
      expect(decoded, isA<OrderCancelledEvent>());
      expect((decoded as OrderCancelledEvent).orderId, 99);
    });
  });

  group('LanProtocol error handling', () {
    test('rejects non-object payload', () {
      expect(
        () => LanProtocol.decode('"hello"'),
        throwsFormatException,
      );
    });

    test('rejects unknown kind', () {
      expect(
        () => LanProtocol.decode('{"kind":"WhoKnows"}'),
        throwsFormatException,
      );
    });

    test('falls back to safe defaults for missing fields', () {
      final TransportEvent ev = LanProtocol.decode('{"kind":"OrderSubmitted"}');
      expect(ev, isA<OrderSubmittedEvent>());
      final OrderSubmittedEvent r = ev as OrderSubmittedEvent;
      expect(r.orderId, 0);
      expect(r.ticketNumber.value, 1);
      expect(r.itemsJson, '[]');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tofu_pos/core/retry/retry_policy.dart';
import 'package:tofu_pos/core/transport/supabase_transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class _MockFilterBuilder extends Mock
    implements PostgrestFilterBuilder<dynamic> {}

/// `device_events` の 1 行に相当する Map を組み立てるテスト用ヘルパ。
Map<String, dynamic> _row({
  required String shopId,
  required String eventId,
  required String type,
  required DateTime occurredAt,
  required Map<String, Object?> payload,
}) {
  return <String, dynamic>{
    'shop_id': shopId,
    'event_id': eventId,
    'event_type': type,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'payload': payload,
  };
}

void main() {
  group('SupabaseTransport.eventTypeNameOf', () {
    test('all event subtypes have stable type names', () {
      final DateTime t = DateTime.utc(2026, 5, 11, 10);
      expect(
        SupabaseTransport.eventTypeNameOf(
          OrderSubmittedEvent(
            shopId: 's',
            eventId: 'e',
            occurredAt: t,
            orderId: 1,
            ticketNumber: const TicketNumber(1),
            itemsJson: '[]',
          ),
        ),
        'order_submitted',
      );
      expect(
        SupabaseTransport.eventTypeNameOf(
          OrderServedEvent(
            shopId: 's',
            eventId: 'e',
            occurredAt: t,
            orderId: 1,
            ticketNumber: const TicketNumber(1),
          ),
        ),
        'order_served',
      );
      expect(
        SupabaseTransport.eventTypeNameOf(
          CallNumberEvent(
            shopId: 's',
            eventId: 'e',
            occurredAt: t,
            orderId: 1,
            ticketNumber: const TicketNumber(1),
          ),
        ),
        'call_number',
      );
      expect(
        SupabaseTransport.eventTypeNameOf(
          OrderCancelledEvent(
            shopId: 's',
            eventId: 'e',
            occurredAt: t,
            orderId: 1,
            ticketNumber: const TicketNumber(1),
          ),
        ),
        'order_cancelled',
      );
      expect(
        SupabaseTransport.eventTypeNameOf(
          ProductMasterUpdateEvent(
            shopId: 's',
            eventId: 'e',
            occurredAt: t,
            productsJson: '[]',
          ),
        ),
        'product_master_update',
      );
    });
  });

  group('SupabaseTransport encode/decode round-trip', () {
    final DateTime occurredAt = DateTime.utc(2026, 5, 11, 10, 30, 15);

    test('OrderSubmittedEvent round-trips through encode/decode', () {
      final OrderSubmittedEvent ev = OrderSubmittedEvent(
        shopId: 'shop-A',
        eventId: 'evt-001',
        occurredAt: occurredAt,
        orderId: 42,
        ticketNumber: const TicketNumber(7),
        itemsJson: '[{"id":"p1","qty":2}]',
      );
      final Map<String, Object?> payload = SupabaseTransport.encodePayload(ev);
      expect(payload, <String, Object?>{
        'order_id': 42,
        'ticket_number': 7,
        'items_json': '[{"id":"p1","qty":2}]',
      });

      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: ev.shopId,
          eventId: ev.eventId,
          type: 'order_submitted',
          occurredAt: ev.occurredAt,
          payload: payload,
        ),
      );
      expect(decoded, isA<OrderSubmittedEvent>());
      final OrderSubmittedEvent d = decoded! as OrderSubmittedEvent;
      expect(d.shopId, ev.shopId);
      expect(d.eventId, ev.eventId);
      expect(d.occurredAt, ev.occurredAt);
      expect(d.orderId, ev.orderId);
      expect(d.ticketNumber, ev.ticketNumber);
      expect(d.itemsJson, ev.itemsJson);
    });

    test('OrderServedEvent round-trips', () {
      final OrderServedEvent ev = OrderServedEvent(
        shopId: 'shop-A',
        eventId: 'evt-002',
        occurredAt: occurredAt,
        orderId: 99,
        ticketNumber: const TicketNumber(3),
      );
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: ev.shopId,
          eventId: ev.eventId,
          type: 'order_served',
          occurredAt: ev.occurredAt,
          payload: SupabaseTransport.encodePayload(ev),
        ),
      );
      expect(decoded, isA<OrderServedEvent>());
      final OrderServedEvent d = decoded! as OrderServedEvent;
      expect(d.orderId, 99);
      expect(d.ticketNumber.value, 3);
    });

    test('CallNumberEvent round-trips', () {
      final CallNumberEvent ev = CallNumberEvent(
        shopId: 'shop-A',
        eventId: 'evt-003',
        occurredAt: occurredAt,
        orderId: 12,
        ticketNumber: const TicketNumber(8),
      );
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: ev.shopId,
          eventId: ev.eventId,
          type: 'call_number',
          occurredAt: ev.occurredAt,
          payload: SupabaseTransport.encodePayload(ev),
        ),
      );
      expect(decoded, isA<CallNumberEvent>());
      final CallNumberEvent d = decoded! as CallNumberEvent;
      expect(d.orderId, 12);
      expect(d.ticketNumber.value, 8);
    });

    test('OrderCancelledEvent round-trips', () {
      final OrderCancelledEvent ev = OrderCancelledEvent(
        shopId: 'shop-A',
        eventId: 'evt-004',
        occurredAt: occurredAt,
        orderId: 5,
        ticketNumber: const TicketNumber(2),
      );
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: ev.shopId,
          eventId: ev.eventId,
          type: 'order_cancelled',
          occurredAt: ev.occurredAt,
          payload: SupabaseTransport.encodePayload(ev),
        ),
      );
      expect(decoded, isA<OrderCancelledEvent>());
      final OrderCancelledEvent d = decoded! as OrderCancelledEvent;
      expect(d.orderId, 5);
      expect(d.ticketNumber.value, 2);
    });

    test('ProductMasterUpdateEvent round-trips', () {
      final ProductMasterUpdateEvent ev = ProductMasterUpdateEvent(
        shopId: 'shop-A',
        eventId: 'evt-005',
        occurredAt: occurredAt,
        productsJson: '[{"id":"p1","name":"焼きそば"}]',
      );
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: ev.shopId,
          eventId: ev.eventId,
          type: 'product_master_update',
          occurredAt: ev.occurredAt,
          payload: SupabaseTransport.encodePayload(ev),
        ),
      );
      expect(decoded, isA<ProductMasterUpdateEvent>());
      final ProductMasterUpdateEvent d = decoded! as ProductMasterUpdateEvent;
      expect(d.productsJson, '[{"id":"p1","name":"焼きそば"}]');
    });
  });

  group('SupabaseTransport.decodeRow defensive parsing', () {
    final DateTime t = DateTime.utc(2026, 5, 11, 10);

    test('unknown event_type returns null (does not throw)', () {
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: 's',
          eventId: 'e',
          type: 'something_unknown_v99',
          occurredAt: t,
          payload: <String, Object?>{},
        ),
      );
      expect(decoded, isNull);
    });

    test('empty row returns null', () {
      expect(SupabaseTransport.decodeRow(<String, dynamic>{}), isNull);
    });

    test('missing shop_id returns null', () {
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        <String, dynamic>{
          'event_id': 'e',
          'event_type': 'order_served',
          'occurred_at': t.toIso8601String(),
          'payload': <String, Object?>{
            'order_id': 1,
            'ticket_number': 1,
          },
        },
      );
      expect(decoded, isNull);
    });

    test('missing required payload field returns null', () {
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: 's',
          eventId: 'e',
          type: 'order_submitted',
          occurredAt: t,
          // items_json が欠落
          payload: <String, Object?>{'order_id': 1, 'ticket_number': 1},
        ),
      );
      expect(decoded, isNull);
    });

    test('malformed occurred_at returns null', () {
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        <String, dynamic>{
          'shop_id': 's',
          'event_id': 'e',
          'event_type': 'order_served',
          'occurred_at': 'not-a-date',
          'payload': <String, Object?>{
            'order_id': 1,
            'ticket_number': 1,
          },
        },
      );
      expect(decoded, isNull);
    });

    test('wrong type in payload (string where int expected) returns null', () {
      final TransportEvent? decoded = SupabaseTransport.decodeRow(
        _row(
          shopId: 's',
          eventId: 'e',
          type: 'order_served',
          occurredAt: t,
          payload: <String, Object?>{
            'order_id': 'not-a-number',
            'ticket_number': 1,
          },
        ),
      );
      expect(decoded, isNull);
    });

    test(
      'non-Map payload is tolerated and decodes to null (missing fields)',
      () {
        final TransportEvent? decoded = SupabaseTransport.decodeRow(
          <String, dynamic>{
            'shop_id': 's',
            'event_id': 'e',
            'event_type': 'order_served',
            'occurred_at': t.toIso8601String(),
            'payload': 'unexpected-string',
          },
        );
        expect(decoded, isNull);
      },
    );
  });

  group('SupabaseTransport.send with mocked SupabaseClient', () {
    late _MockSupabaseClient client;
    late _MockQueryBuilder queryBuilder;
    late _MockFilterBuilder filterBuilder;
    late SupabaseTransport transport;

    setUpAll(() {
      registerFallbackValue(<String, Object?>{});
    });

    setUp(() {
      client = _MockSupabaseClient();
      queryBuilder = _MockQueryBuilder();
      filterBuilder = _MockFilterBuilder();
      // 注意: SupabaseQueryBuilder / PostgrestFilterBuilder のチェーンは
      // どちらも内部的に `Future` を implements している。そのため mocktail は
      // 戻り値を Future 扱いし、`thenReturn` を拒否する → `thenAnswer` で返す。
      when(() => client.from(any())).thenAnswer((_) => queryBuilder);
      when(() => queryBuilder.insert(any())).thenAnswer((_) => filterBuilder);
      // PostgrestFilterBuilder は Future<dynamic> を implements している。
      // `await filterBuilder` で `.then(onValue, onError: onError)` が呼ばれるので、
      // それを完了済みの Future にすり替える。
      when(
        () => filterBuilder.then<dynamic>(
          any(),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((invocation) {
        final onValue =
            invocation.positionalArguments[0] as dynamic Function(dynamic);
        return Future<dynamic>.value().then(onValue);
      });
      transport = SupabaseTransport(
        client: client,
        shopId: 'shop_a',
        retryPolicy: const RetryPolicy(
          initialDelay: Duration.zero,
          maxDelay: Duration.zero,
          maxAttempts: 1,
        ),
      );
    });

    test(
      'send calls client.from(table).insert(row) with expected shape',
      () async {
        final OrderServedEvent ev = OrderServedEvent(
          shopId: 'shop_a',
          eventId: 'evt-send-1',
          occurredAt: DateTime.utc(2026, 5, 11, 10),
          orderId: 7,
          ticketNumber: const TicketNumber(3),
        );
        await transport.send(ev);

        final capturedTable = verify(() => client.from(captureAny())).captured;
        expect(capturedTable.single, 'device_events');

        final capturedRow = verify(
          () => queryBuilder.insert(captureAny()),
        ).captured;
        expect(capturedRow, hasLength(1));
        final Map<String, Object?> row = (capturedRow.single as Map)
            .cast<String, Object?>();
        expect(row['shop_id'], 'shop_a');
        expect(row['event_id'], 'evt-send-1');
        expect(row['event_type'], 'order_served');
        expect(row['occurred_at'], isA<String>());
        expect((row['occurred_at']! as String).endsWith('Z'), isTrue);
        expect(row['payload'], isA<Map<String, Object?>>());
        final Map<String, Object?> payload = (row['payload']! as Map)
            .cast<String, Object?>();
        expect(payload['order_id'], 7);
        expect(payload['ticket_number'], 3);
      },
    );

    test(
      'send registers event_id into selfIds for echo-back filtering',
      () async {
        final CallNumberEvent ev = CallNumberEvent(
          shopId: 'shop_a',
          eventId: 'evt-self-1',
          occurredAt: DateTime.utc(2026, 5, 11, 10),
          orderId: 12,
          ticketNumber: const TicketNumber(8),
        );
        await transport.send(ev);
        expect(transport.debugSelfIds(), contains('evt-self-1'));
      },
    );

    test(
      'send after disconnect still works (HTTP path is not closed)',
      () async {
        // disconnect は Realtime チャネルだけを閉じる。送信は HTTP 経由なので
        // disconnect 後も呼び出せる（業務継続）。
        await transport.disconnect();
        final OrderCancelledEvent ev = OrderCancelledEvent(
          shopId: 'shop_a',
          eventId: 'evt-after-disconnect',
          occurredAt: DateTime.utc(2026, 5, 11, 10),
          orderId: 1,
          ticketNumber: const TicketNumber(1),
        );
        await transport.send(ev);
        expect(transport.debugSelfIds(), contains('evt-after-disconnect'));
      },
    );

    test(
      'onSubscribed is a broadcast stream that supports listen before any '
      'subscribe success (bug B: ingest router must be able to attach early)',
      () async {
        // 連続購読しても StateError が出ない（=broadcast）こと。
        // subscribe 成功通知用にこの仕様が必要。
        final s1 = transport.onSubscribed.listen((_) {});
        final s2 = transport.onSubscribed.listen((_) {});
        await s1.cancel();
        await s2.cancel();
        // 初期は未 subscribed。
        expect(transport.isSubscribed, isFalse);
      },
    );
  });
}

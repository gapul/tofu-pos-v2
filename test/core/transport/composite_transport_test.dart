import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/error/app_exceptions.dart';
import 'package:tofu_pos/core/transport/composite_transport.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

class _RecordingTransport implements Transport {
  _RecordingTransport({this.throwOnSend = false});
  final bool throwOnSend;
  final List<TransportEvent> sent = <TransportEvent>[];
  final StreamController<TransportEvent> ctrl =
      StreamController<TransportEvent>.broadcast();

  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {
    await ctrl.close();
  }
  @override
  Stream<TransportEvent> events() => ctrl.stream;
  @override
  Future<void> send(TransportEvent event) async {
    if (throwOnSend) {
      throw StateError('primary down');
    }
    sent.add(event);
  }
}

OrderSubmittedEvent _ev(String id, {int orderId = 1}) => OrderSubmittedEvent(
      shopId: 'shop',
      eventId: id,
      occurredAt: DateTime(2026, 5, 16),
      orderId: orderId,
      ticketNumber: const TicketNumber(1),
      itemsJson: '[]',
    );

ProductMasterUpdateEvent _master(String id) => ProductMasterUpdateEvent(
      shopId: 'shop',
      eventId: id,
      occurredAt: DateTime(2026, 5, 16),
      productsJson: '[]',
    );

void main() {
  test('send: primary success path also fires BLE in parallel', () async {
    // 受信側の primary が死んでいるケース（DNS 不安定など）で push が
    // 落ちる事故を防ぐため、BLE eligible なイベントは常に副経路にも
    // fire-and-forget で並行送信する。
    final _RecordingTransport primary = _RecordingTransport();
    final _RecordingTransport secondary = _RecordingTransport();
    final CompositeOnlineBleTransport t = CompositeOnlineBleTransport(
      primary: primary,
      secondary: secondary,
    );
    await t.connect();
    await t.send(_ev('a'));
    // primary は同期 await、BLE は fire-and-forget なので microtask 1 巡で送られる。
    await Future<void>.delayed(Duration.zero);
    expect(primary.sent, hasLength(1));
    expect(secondary.sent, hasLength(1));
    expect(t.didFallback, isFalse);
    await t.disconnect();
  });

  test('send: BLE fallback when primary throws', () async {
    final _RecordingTransport primary =
        _RecordingTransport(throwOnSend: true);
    final _RecordingTransport secondary = _RecordingTransport();
    final CompositeOnlineBleTransport t = CompositeOnlineBleTransport(
      primary: primary,
      secondary: secondary,
    );
    await t.connect();
    await t.send(_ev('b'));
    expect(secondary.sent, hasLength(1));
    expect(t.didFallback, isTrue);
    expect(t.primaryHealthy, isFalse);
    await t.disconnect();
  });

  test('send: ProductMasterUpdate never falls back to BLE', () async {
    final _RecordingTransport primary =
        _RecordingTransport(throwOnSend: true);
    final _RecordingTransport secondary = _RecordingTransport();
    final CompositeOnlineBleTransport t = CompositeOnlineBleTransport(
      primary: primary,
      secondary: secondary,
    );
    await t.connect();
    await expectLater(
      t.send(_master('m1')),
      throwsA(isA<TransportDeliveryException>()),
    );
    expect(secondary.sent, isEmpty);
    await t.disconnect();
  });

  test('events: merges both sources and dedups by eventId', () async {
    final _RecordingTransport primary = _RecordingTransport();
    final _RecordingTransport secondary = _RecordingTransport();
    final CompositeOnlineBleTransport t = CompositeOnlineBleTransport(
      primary: primary,
      secondary: secondary,
    );
    await t.connect();
    final List<TransportEvent> received = <TransportEvent>[];
    final StreamSubscription<TransportEvent> sub =
        t.events().listen(received.add);

    primary.ctrl.add(_ev('dup'));
    secondary.ctrl.add(_ev('dup')); // dedup されて 1 件のみ
    secondary.ctrl.add(_ev('uniq', orderId: 2));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(received, hasLength(2));
    expect(received.map((e) => e.eventId).toSet(), <String>{'dup', 'uniq'});
    await sub.cancel();
    await t.disconnect();
  });
}

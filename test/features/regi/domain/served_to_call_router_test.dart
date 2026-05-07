import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/repositories/settings_repository.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/regi/domain/served_to_call_router.dart';

class _FakeSettings implements SettingsRepository {
  _FakeSettings(this._flags);
  FeatureFlags _flags;

  @override
  Future<FeatureFlags> getFeatureFlags() async => _flags;

  @override
  Future<void> setFeatureFlags(FeatureFlags flags) async {
    _flags = flags;
  }

  // 以下未使用
  @override
  Future<ShopId?> getShopId() async => null;
  @override
  Future<void> setShopId(ShopId shopId) async {}
  @override
  Future<DeviceRole?> getDeviceRole() async => null;
  @override
  Future<void> setDeviceRole(DeviceRole role) async {}
  @override
  Stream<FeatureFlags> watchFeatureFlags() =>
      const Stream<FeatureFlags>.empty();
  @override
  Future<TransportMode> getTransportMode() async => TransportMode.online;
  @override
  Future<void> setTransportMode(TransportMode mode) async {}
  @override
  Stream<TransportMode> watchTransportMode() =>
      const Stream<TransportMode>.empty();
}

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

OrderServedEvent _served() => OrderServedEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    );

void main() {
  test('forwards CallNumberEvent when both flags on', () async {
    final _FakeTransport transport = _FakeTransport();
    final ServedToCallRouter router = ServedToCallRouter(
      transport: transport,
      settingsRepository: _FakeSettings(
        const FeatureFlags(kitchenLink: true, callingLink: true),
      ),
      shopId: 'shop',
      now: () => DateTime(2026, 5, 7, 12, 30),
    );
    router.start();
    transport.incoming.add(_served());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(transport.sent.single, isA<CallNumberEvent>());
    final CallNumberEvent ev = transport.sent.single as CallNumberEvent;
    expect(ev.orderId, 1);
    expect(ev.ticketNumber.value, 7);
    expect(ev.shopId, 'shop');
    await router.stop();
  });

  test('does not forward when callingLink is off', () async {
    final _FakeTransport transport = _FakeTransport();
    final ServedToCallRouter router = ServedToCallRouter(
      transport: transport,
      settingsRepository: _FakeSettings(const FeatureFlags(kitchenLink: true)),
      shopId: 'shop',
    );
    router.start();
    transport.incoming.add(_served());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.sent, isEmpty);
    await router.stop();
  });

  test('does not forward when kitchenLink is off', () async {
    // 仕様書 §6.3 後段: キッチン連携オフ時は手動ボタン経由なので、自動転送はしない
    final _FakeTransport transport = _FakeTransport();
    final ServedToCallRouter router = ServedToCallRouter(
      transport: transport,
      settingsRepository: _FakeSettings(const FeatureFlags(callingLink: true)),
      shopId: 'shop',
    );
    router.start();
    transport.incoming.add(_served());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.sent, isEmpty);
    await router.stop();
  });

  test('ignores foreign shop_id events', () async {
    final _FakeTransport transport = _FakeTransport();
    final ServedToCallRouter router = ServedToCallRouter(
      transport: transport,
      settingsRepository: _FakeSettings(
        const FeatureFlags(kitchenLink: true, callingLink: true),
      ),
      shopId: 'shop',
    );
    router.start();
    transport.incoming.add(OrderServedEvent(
      shopId: 'OTHER',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.sent, isEmpty);
    await router.stop();
  });

  test('ignores non-OrderServed events', () async {
    final _FakeTransport transport = _FakeTransport();
    final ServedToCallRouter router = ServedToCallRouter(
      transport: transport,
      settingsRepository: _FakeSettings(
        const FeatureFlags(kitchenLink: true, callingLink: true),
      ),
      shopId: 'shop',
    );
    router.start();
    transport.incoming.add(OrderSubmittedEvent(
      shopId: 'shop',
      eventId: 'e1',
      occurredAt: DateTime(2026, 5, 7, 12),
      orderId: 1,
      ticketNumber: const TicketNumber(7),
      itemsJson: '[]',
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(transport.sent, isEmpty);
    await router.stop();
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/connectivity/connectivity_monitor.dart';
import 'package:tofu_pos/core/connectivity/connectivity_status.dart';
import 'package:tofu_pos/core/sync/cloud_sync_client.dart';
import 'package:tofu_pos/core/sync/sync_service.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/repositories/settings_repository.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

import '../../fakes/fake_repositories.dart';

class _FakeMonitor implements ConnectivityMonitor {
  _FakeMonitor(this._status);
  ConnectivityStatus _status;
  final StreamController<ConnectivityStatus> _ctrl =
      StreamController<ConnectivityStatus>.broadcast();

  void emit(ConnectivityStatus s) {
    _status = s;
    _ctrl.add(s);
  }

  @override
  ConnectivityStatus get current => _status;

  @override
  Stream<ConnectivityStatus> watch() async* {
    yield _status;
    yield* _ctrl.stream;
  }
}

class _FakeSettings implements SettingsRepository {
  _FakeSettings(this._shopId);
  final ShopId? _shopId;

  @override
  Future<ShopId?> getShopId() async => _shopId;

  // 以下は本テストで未使用。
  @override
  Future<void> setShopId(ShopId shopId) async {}
  @override
  Future<DeviceRole?> getDeviceRole() async => null;
  @override
  Future<void> setDeviceRole(DeviceRole role) async {}
  @override
  Future<FeatureFlags> getFeatureFlags() async => FeatureFlags.allOff;
  @override
  Future<void> setFeatureFlags(FeatureFlags flags) async {}
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
  @override
  Future<Duration> getLanSendTimeout() async => const Duration(seconds: 5);
  @override
  Future<void> setLanSendTimeout(Duration value) async {}
  @override
  Future<Duration> getBleSendTimeout() async => const Duration(seconds: 10);
  @override
  Future<void> setBleSendTimeout(Duration value) async {}
  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';
}

class _RecordingClient implements CloudSyncClient {
  final List<Order> pushed = <Order>[];
  bool fail = false;

  @override
  Future<void> push(Order order, {required String shopId}) async {
    if (fail) {
      throw StateError('simulated failure');
    }
    pushed.add(order);
  }
}

Order _makeOrder({int id = 0, SyncStatus sync = SyncStatus.notSynced}) {
  return Order(
    id: id,
    ticketNumber: const TicketNumber(1),
    items: const <OrderItem>[
      OrderItem(
        productId: 'p1',
        productName: 'Yakisoba',
        priceAtTime: Money(400),
        quantity: 1,
      ),
    ],
    discount: Discount.none,
    receivedCash: const Money(500),
    createdAt: DateTime(2026, 5, 7),
    orderStatus: OrderStatus.served,
    syncStatus: sync,
  );
}

void main() {
  late InMemoryOrderRepository orderRepo;
  late _FakeMonitor monitor;
  late _RecordingClient client;
  late SyncService service;

  setUp(() {
    orderRepo = InMemoryOrderRepository();
    monitor = _FakeMonitor(ConnectivityStatus.online);
    client = _RecordingClient();
    service = SyncService(
      orderRepository: orderRepo,
      settingsRepository: _FakeSettings(ShopId('shop_a')),
      connectivityMonitor: monitor,
      client: client,
    );
  });

  test('does nothing when offline', () async {
    monitor.emit(ConnectivityStatus.offline);
    await orderRepo.create(_makeOrder());
    final SyncResult r = await service.runOnce();
    expect(r.successCount, 0);
    expect(client.pushed, isEmpty);
  });

  test('does nothing when shopId is not set', () async {
    service = SyncService(
      orderRepository: orderRepo,
      settingsRepository: _FakeSettings(null),
      connectivityMonitor: monitor,
      client: client,
    );
    await orderRepo.create(_makeOrder());
    final SyncResult r = await service.runOnce();
    expect(r.successCount, 0);
  });

  test('pushes only NOT_SYNCED orders and marks them synced', () async {
    final Order a = await orderRepo.create(_makeOrder());
    final Order b = await orderRepo.create(_makeOrder());
    await orderRepo.updateSyncStatus(b.id, SyncStatus.synced);

    final SyncResult r = await service.runOnce();
    expect(r.successCount, 1);
    expect(client.pushed.map((Order o) => o.id), <int>[a.id]);

    final List<Order> unsynced = await orderRepo.findUnsynced();
    expect(unsynced, isEmpty);
  });

  test('records lastFailureSince on failure and clears on success', () async {
    await orderRepo.create(_makeOrder());
    client.fail = true;
    final SyncResult r1 = await service.runOnce();
    expect(r1.failureCount, 1);
    expect(service.lastFailureSince, isNotNull);

    client.fail = false;
    final SyncResult r2 = await service.runOnce();
    expect(r2.failureCount, 0);
    expect(service.lastFailureSince, isNull);
  });
}

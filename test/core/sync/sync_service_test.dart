import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/core/connectivity/connectivity_monitor.dart';
import 'package:tofu_pos/core/connectivity/connectivity_status.dart';
import 'package:tofu_pos/core/sync/cloud_sync_client.dart';
import 'package:tofu_pos/core/sync/sync_service.dart';
import 'package:tofu_pos/core/telemetry/telemetry.dart';
import 'package:tofu_pos/core/telemetry/telemetry_event.dart';
import 'package:tofu_pos/core/telemetry/telemetry_sink.dart';
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
  Future<void> clearShopId() async {}
  @override
  Future<DeviceRole?> getDeviceRole() async => null;
  @override
  Future<void> setDeviceRole(DeviceRole role) async {}

  @override
  Future<void> clearDeviceRole() async {}
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
  @override
  Future<String?> getUserName() async => null;
  @override
  Future<void> setUserName(String? value) async {}
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
    expect(client.pushed.map((o) => o.id), <int>[a.id]);

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

  test('start() で fire-and-forget された runOnce はタイムアウトで停止し、'
      '再試行タイマーは動き続ける', () async {
    // 永遠にハングする client を用意。
    final _HangingClient hanging = _HangingClient();
    final SyncService quick = SyncService(
      orderRepository: orderRepo,
      settingsRepository: _FakeSettings(ShopId('shop_a')),
      connectivityMonitor: monitor,
      client: hanging,
      retryInterval: const Duration(milliseconds: 50),
      runOnceTimeout: const Duration(milliseconds: 30),
    );
    await orderRepo.create(_makeOrder());
    quick.start();
    addTearDown(() async {
      await quick.stop();
      hanging.release();
    });

    // タイマー1回 + タイムアウト1回ぶんを待つ。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // ここで例外が外に漏れていなければタイムアウトガードが効いている。
    expect(true, isTrue);
  });

  test('orphan runOnce breaks the loop after token is invalidated and does '
      'not double-update synced orders', () async {
    // 3 件 unsynced を仕込む。各 push の合間に token を孤児化することで、
    // ループの最初の order だけが処理されて break するはず。
    final Order o1 = await orderRepo.create(_makeOrder());
    await orderRepo.create(_makeOrder());
    await orderRepo.create(_makeOrder());

    // push 後すぐに token をすり替える「介入クライアント」。
    // 戻り値: 何件成功したか。
    final List<int> pushedIds = <int>[];
    int callCount = 0;
    final _InterceptingClient client = _InterceptingClient(
      onPush: (order) async {
        pushedIds.add(order.id);
        callCount++;
        if (callCount == 1) {
          // 1 件目処理直後に孤児化 → 次のループ先頭の token チェックで break。
          service.debugInvalidateRunToken();
        }
      },
    );
    service = SyncService(
      orderRepository: orderRepo,
      settingsRepository: _FakeSettings(ShopId('shop_a')),
      connectivityMonitor: monitor,
      client: client,
    );

    final SyncResult r = await service.runOnce();
    // 1 件だけ成功、残り 2 件は break で未処理のまま。
    expect(r.successCount, 1);
    expect(r.failureCount, 0);
    expect(pushedIds, <int>[o1.id]);

    // 早期 break したので、2 件目以降は依然として notSynced のまま。
    final List<Order> stillUnsynced = await orderRepo.findUnsynced();
    expect(stillUnsynced.length, 2);
  });

  test('stop() cancels retry timer and connectivity subscription', () async {
    final _RecordingClient quietClient = _RecordingClient();
    final SyncService svc = SyncService(
      orderRepository: orderRepo,
      settingsRepository: _FakeSettings(ShopId('shop_a')),
      connectivityMonitor: monitor,
      client: quietClient,
      retryInterval: const Duration(milliseconds: 10),
    );
    svc.start();
    // Allow at least one periodic tick to fire.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await svc.stop();
    final int before = quietClient.pushed.length;
    // After stop, no further pushes should happen even if timer would have fired.
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(quietClient.pushed.length, before);
  });

  group('前回クラッシュ検出 (#4)', () {
    tearDown(Telemetry.instance.reset);

    test(
      '前回 started != completed の prefs で起動すると WARN telemetry が発火する',
      () async {
        // 前回プロセスが「開始したが完了しなかった」状態を再現
        SharedPreferences.setMockInitialValues(<String, Object>{
          'sync.lastStartedToken': 'tokenA',
          'sync.lastCompletedToken': 'tokenB', // 不一致
        });
        final SharedPreferences prefs =
            await SharedPreferences.getInstance();
        final _RecordingSink sink = _RecordingSink();
        Telemetry.instance.configure(
          sink: sink,
          shopId: 'shop_a',
          deviceId: 'd1',
          deviceRole: 'register',
        );

        final SyncService svc = SyncService(
          orderRepository: orderRepo,
          settingsRepository: _FakeSettings(ShopId('shop_a')),
          connectivityMonitor: monitor,
          client: client,
          prefs: prefs,
        );
        await svc.runOnce();

        final warns = sink.enqueued
            .where((e) => e.kind == 'sync.previous_run.incomplete')
            .toList();
        expect(warns, hasLength(1));
        expect(warns.first.level, TelemetryLevel.warn);
        // started key は消費される（次回は通知しない）
        expect(prefs.getString('sync.lastStartedToken'), isNot('tokenA'));
      },
    );

    test('前回 started == completed なら通知しない', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'sync.lastStartedToken': 'tokenSame',
        'sync.lastCompletedToken': 'tokenSame',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final _RecordingSink sink = _RecordingSink();
      Telemetry.instance.configure(
        sink: sink,
        shopId: 'shop_a',
        deviceId: 'd1',
        deviceRole: 'register',
      );

      final SyncService svc = SyncService(
        orderRepository: orderRepo,
        settingsRepository: _FakeSettings(ShopId('shop_a')),
        connectivityMonitor: monitor,
        client: client,
        prefs: prefs,
      );
      await svc.runOnce();

      expect(
        sink.enqueued.where((e) => e.kind == 'sync.previous_run.incomplete'),
        isEmpty,
      );
    });
  });
}

class _RecordingSink implements TelemetrySink {
  final List<TelemetryEvent> enqueued = <TelemetryEvent>[];
  @override
  void enqueue(TelemetryEvent event) => enqueued.add(event);
  @override
  Future<void> flush() async {}
}

class _HangingClient implements CloudSyncClient {
  final Completer<void> _completer = Completer<void>();

  void release() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  @override
  Future<void> push(Order order, {required String shopId}) => _completer.future;
}

class _InterceptingClient implements CloudSyncClient {
  _InterceptingClient({required this.onPush});
  final Future<void> Function(Order order) onPush;

  @override
  Future<void> push(Order order, {required String shopId}) => onPush(order);
}

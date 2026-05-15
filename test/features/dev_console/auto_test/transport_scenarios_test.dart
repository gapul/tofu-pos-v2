import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/core/connectivity/connectivity_monitor.dart';
import 'package:tofu_pos/core/connectivity/connectivity_status.dart';
import 'package:tofu_pos/core/export/csv_export_service.dart';
import 'package:tofu_pos/core/sync/cloud_sync_client.dart';
import 'package:tofu_pos/core/sync/sync_service.dart';
import 'package:tofu_pos/core/transport/transport.dart';
import 'package:tofu_pos/core/transport/transport_event.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_calling_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_cash_drawer_repository.dart';
import 'package:tofu_pos/data/repositories/drift_kitchen_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_operation_log_repository.dart';
import 'package:tofu_pos/data/repositories/drift_order_repository.dart';
import 'package:tofu_pos/data/repositories/drift_product_repository.dart';
import 'package:tofu_pos/data/repositories/drift_unit_of_work.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_daily_reset_repository.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_settings_repository.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/usecases/cancel_order_usecase.dart';
import 'package:tofu_pos/domain/usecases/cash_close_usecase.dart';
import 'package:tofu_pos/domain/usecases/checkout_usecase.dart';
import 'package:tofu_pos/domain/usecases/daily_reset_usecase.dart';
import 'package:tofu_pos/domain/usecases/hourly_sales_usecase.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenario.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/scenario_context.dart';
import 'package:tofu_pos/features/dev_console/domain/auto_test/transport_scenarios.dart';

/// テスト用 Transport。
/// - `send` は `sent` リストに積むだけ。
/// - `events()` は外部から `emit` で注入できる broadcast Stream。
/// - `failOnSend` を true にすると例外を投げる。
class FakeTransport implements Transport {
  FakeTransport({this.failOnSend = false});

  bool failOnSend;
  final List<TransportEvent> sent = <TransportEvent>[];
  final StreamController<TransportEvent> _ctrl =
      StreamController<TransportEvent>.broadcast();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _ctrl.close();
  }

  @override
  Stream<TransportEvent> events() => _ctrl.stream;

  @override
  Future<void> send(TransportEvent event) async {
    if (failOnSend) {
      throw StateError('fake send failure');
    }
    sent.add(event);
  }
}

Future<ScenarioContext> _buildCtx({
  Transport? transport,
  TransportMode? mode,
  String? shopId,
  bool hasCreds = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());

  final productRepo = DriftProductRepository(db);
  final orderRepo = DriftOrderRepository(db);
  final cashRepo = DriftCashDrawerRepository(db);
  final kitchenRepo = DriftKitchenOrderRepository(db);
  final callingRepo = DriftCallingOrderRepository(db);
  final logRepo = DriftOperationLogRepository(db);
  final settings = SharedPrefsSettingsRepository(prefs);
  final poolRepo = SharedPrefsTicketPoolRepository(prefs);
  final dailyRepo = SharedPrefsDailyResetRepository(prefs);
  final uow = DriftUnitOfWork(db);

  return ScenarioContext(
    db: db,
    prefs: prefs,
    productRepo: productRepo,
    orderRepo: orderRepo,
    cashRepo: cashRepo,
    kitchenRepo: kitchenRepo,
    callingRepo: callingRepo,
    poolRepo: poolRepo,
    logRepo: logRepo,
    settings: settings,
    checkout: CheckoutUseCase(
      unitOfWork: uow,
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
    ),
    cancel: CancelOrderUseCase(
      unitOfWork: uow,
      orderRepository: orderRepo,
      productRepository: productRepo,
      cashDrawerRepository: cashRepo,
      ticketPoolRepository: poolRepo,
      operationLogRepository: logRepo,
    ),
    cashClose: CashCloseUseCase(
      orderRepository: orderRepo,
      cashDrawerRepository: cashRepo,
    ),
    hourly: HourlySalesUseCase(orderRepository: orderRepo),
    dailyReset: DailyResetUseCase(
      dailyResetRepository: dailyRepo,
      ticketPoolRepository: poolRepo,
    ),
    csv: const CsvExportService(),
    sync: SyncService(
      orderRepository: orderRepo,
      settingsRepository: settings,
      connectivityMonitor: _AlwaysOfflineMonitor(),
      client: NoopCloudSyncClient(),
    ),
    transport: transport,
    transportMode: mode,
    shopId: shopId,
    hasSupabaseCredentials: hasCreds,
  );
}

class _AlwaysOfflineMonitor implements ConnectivityMonitor {
  @override
  ConnectivityStatus get current => ConnectivityStatus.offline;

  @override
  Stream<ConnectivityStatus> watch() async* {
    yield ConnectivityStatus.offline;
  }
}

TestScenario _byId(String id) =>
    transportScenarios().firstWhere((s) => s.id == id);

void main() {
  group('transport scenarios — skip conditions', () {
    test('online.send_persists skips when transport missing', () async {
      final ctx = await _buildCtx();
      final r = await _byId('transport.online.send_persists').run(ctx);
      expect(r.skipped, isTrue);
      await ctx.db.close();
    });

    test('online.send_persists skips when mode != online', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.localLan,
        shopId: 'shop_a',
        hasCreds: true,
      );
      final r = await _byId('transport.online.send_persists').run(ctx);
      expect(r.skipped, isTrue);
      expect(r.message, contains('not online'));
      await ctx.db.close();
    });

    test('online.send_persists skips when creds missing', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.online,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.online.send_persists').run(ctx);
      expect(r.skipped, isTrue);
      await ctx.db.close();
    });

    test('local_lan skips when mode != localLan', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.online,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.local_lan.broadcast_no_error').run(ctx);
      expect(r.skipped, isTrue);
      await ctx.db.close();
    });

    test('bluetooth skips when mode != bluetooth', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.localLan,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.bluetooth.broadcast_no_error').run(ctx);
      expect(r.skipped, isTrue);
      await ctx.db.close();
    });
  });

  group('transport scenarios — happy paths via fake', () {
    test('local_lan passes when send succeeds', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.localLan,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.local_lan.broadcast_no_error').run(ctx);
      expect(r.passed, isTrue);
      expect(t.sent, hasLength(1));
      await ctx.db.close();
    });

    test('local_lan fails when send throws', () async {
      final t = FakeTransport(failOnSend: true);
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.localLan,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.local_lan.broadcast_no_error').run(ctx);
      expect(r.passed, isFalse);
      expect(r.skipped, isFalse);
      expect(r.message, contains('threw'));
      await ctx.db.close();
    });

    test('bluetooth passes when send succeeds', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(
        transport: t,
        mode: TransportMode.bluetooth,
        shopId: 'shop_a',
      );
      final r = await _byId('transport.bluetooth.broadcast_no_error').run(ctx);
      expect(r.passed, isTrue);
      await ctx.db.close();
    });

    test('events.stream_alive passes with healthy fake', () async {
      final t = FakeTransport();
      final ctx = await _buildCtx(transport: t, shopId: 'shop_a');
      // FakeTransport は自送信を echo しないので loopback dedup チェックは
      // 自然にパスする（"echoed back" 文字列で fail しないこと）。
      final r = await _byId('transport.events.stream_alive').run(ctx);
      expect(r.passed, isTrue, reason: r.message);
      await ctx.db.close();
    });

    test('events.stream_alive fails if self event is echoed back', () async {
      // ループバック抑止が壊れた Transport のシミュレーション:
      // send したらそのまま events stream にも流す。
      final EchoBackTransport t = EchoBackTransport();
      final ctx = await _buildCtx(transport: t, shopId: 'shop_a');
      final r = await _byId('transport.events.stream_alive').run(ctx);
      expect(r.passed, isFalse);
      expect(r.message, contains('loopback dedup'));
      await ctx.db.close();
    });

    test('peer_register.roundtrip_3 passes when peer echoes', () async {
      // ループバックで OrderSubmittedEvent を受けたら OrderServedEvent を
      // 即座に events ストリームに流す疑似ピア。
      final PeerEchoTransport t = PeerEchoTransport();
      final ctx = await _buildCtx(transport: t, shopId: 'shop_a');
      final r = await _byId('transport.peer_register.roundtrip_3').run(ctx);
      expect(r.passed, isTrue, reason: r.message);
      await ctx.db.close();
    });

    test(
      'peer_register.roundtrip_3 fails when no peer responds',
      () async {
        final FakeTransport t = FakeTransport();
        final ctx = await _buildCtx(transport: t, shopId: 'shop_a');
        final r = await _byId('transport.peer_register.roundtrip_3').run(ctx);
        expect(r.passed, isFalse);
        expect(r.skipped, isFalse);
        expect(r.message, contains('missing'));
        await ctx.db.close();
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

/// 送ったイベントをそのまま events ストリームに流す壊れた Transport。
class EchoBackTransport implements Transport {
  final StreamController<TransportEvent> _ctrl =
      StreamController<TransportEvent>.broadcast();

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _ctrl.close();
  }

  @override
  Stream<TransportEvent> events() => _ctrl.stream;

  @override
  Future<void> send(TransportEvent event) async {
    _ctrl.add(event);
  }
}

/// OrderSubmittedEvent を受信したら OrderServedEvent を返す疑似キッチンピア。
class PeerEchoTransport implements Transport {
  final StreamController<TransportEvent> _ctrl =
      StreamController<TransportEvent>.broadcast();
  int _seq = 0;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    await _ctrl.close();
  }

  @override
  Stream<TransportEvent> events() => _ctrl.stream;

  @override
  Future<void> send(TransportEvent event) async {
    if (event is OrderSubmittedEvent) {
      _ctrl.add(
        OrderServedEvent(
          shopId: event.shopId,
          eventId: 'peer-${_seq++}',
          occurredAt: DateTime.now().toUtc(),
          orderId: event.orderId,
          ticketNumber: TicketNumber(event.ticketNumber.value),
        ),
      );
    }
  }
}

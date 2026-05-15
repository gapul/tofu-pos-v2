import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/logging/app_logger.dart';
import '../core/telemetry/telemetry.dart';
import '../core/transport/ble_transport.dart';
import '../core/transport/lan_transport.dart';
import '../core/transport/noop_transport.dart';
import '../core/transport/supabase_transport.dart';
import '../core/transport/timeout_transport.dart';
import '../core/transport/transport.dart';
import '../data/datasources/ble/ble_central_service.dart';
import '../data/datasources/ble/ble_peripheral_service.dart';
import '../data/datasources/lan/lan_client.dart';
import '../data/datasources/lan/lan_server.dart';
import '../domain/enums/device_role.dart';
import '../domain/enums/transport_mode.dart';
import '../domain/usecases/cancel_order_usecase.dart';
import '../domain/usecases/cash_close_usecase.dart';
import '../domain/usecases/checkout_usecase.dart';
import '../domain/usecases/daily_reset_usecase.dart';
import '../domain/usecases/hourly_sales_usecase.dart';
import '../domain/value_objects/shop_id.dart';
import '../features/regi/domain/cancel_order_flow_usecase.dart';
import '../features/regi/domain/checkout_flow_usecase.dart';
import 'repository_providers.dart';
import 'settings_providers.dart';

final Provider<CheckoutUseCase> checkoutUseCaseProvider =
    Provider<CheckoutUseCase>(
      (ref) => CheckoutUseCase(
        unitOfWork: ref.watch(unitOfWorkProvider),
        orderRepository: ref.watch(orderRepositoryProvider),
        productRepository: ref.watch(productRepositoryProvider),
        cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
        ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
        operationLogRepository: ref.watch(operationLogRepositoryProvider),
      ),
    );

final Provider<CancelOrderUseCase> cancelOrderUseCaseProvider =
    Provider<CancelOrderUseCase>(
      (ref) => CancelOrderUseCase(
        unitOfWork: ref.watch(unitOfWorkProvider),
        orderRepository: ref.watch(orderRepositoryProvider),
        productRepository: ref.watch(productRepositoryProvider),
        cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
        ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
        operationLogRepository: ref.watch(operationLogRepositoryProvider),
      ),
    );

final Provider<CashCloseUseCase> cashCloseUseCaseProvider =
    Provider<CashCloseUseCase>(
      (ref) => CashCloseUseCase(
        orderRepository: ref.watch(orderRepositoryProvider),
        cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
        operationLogRepository: ref.watch(operationLogRepositoryProvider),
      ),
    );

final Provider<HourlySalesUseCase> hourlySalesUseCaseProvider =
    Provider<HourlySalesUseCase>(
      (ref) => HourlySalesUseCase(
        orderRepository: ref.watch(orderRepositoryProvider),
      ),
    );

final Provider<DailyResetUseCase> dailyResetUseCaseProvider =
    Provider<DailyResetUseCase>(
      (ref) => DailyResetUseCase(
        dailyResetRepository: ref.watch(dailyResetRepositoryProvider),
        ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
        operationLogRepository: ref.watch(operationLogRepositoryProvider),
      ),
    );

/// 端末間連携の Transport を、現在の TransportMode と DeviceRole から自動選択する。
///
/// - online: Supabase Realtime + `device_events` テーブル（認証情報なしは Noop に degrade）
/// - localLan: 役割に応じて LanClient（レジ）／LanServer（キッチン・呼び出し）
/// - bluetooth: 役割に応じて BleCentral（レジ）／BlePeripheral（キッチン・呼び出し）
///
/// 店舗ID または役割が未設定なら Noop を返して安全側に倒す。
/// `connect()` は [_buildTransport] 内で呼び、ref.onDispose で disconnect する。
///
/// TransportMode が変わったら provider 自体が再ビルドされ、旧 Transport は
/// `ref.onDispose(disconnect)` で確実に切断される。`transportModeProvider`
/// が Stream で公開されているため、`ref.watch` するだけで変更検知できる。
final FutureProvider<Transport> transportProvider = FutureProvider<Transport>((
  ref,
) async {
  final settings = ref.watch(settingsRepositoryProvider);
  // TransportMode の変更を購読する。初期値が到着するまで待つ。
  // 取得失敗時は SharedPrefs のデフォルト（online）にフォールバックする。
  final TransportMode mode = await ref.watch(
    transportModeProvider.future,
  );
  final ShopId? shopId = await settings.getShopId();
  final DeviceRole? role = await settings.getDeviceRole();

  if (shopId == null || role == null) {
    final NoopTransport t = NoopTransport();
    // 旧 Transport の確実な後始末。disconnect 完了は待たない（unawaited）。
    ref.onDispose(() {
      unawaited(t.disconnect());
    });
    return t;
  }

  final Duration lanTimeout = await settings.getLanSendTimeout();
  final Duration bleTimeout = await settings.getBleSendTimeout();

  final Transport t = await _buildTransport(
    mode: mode,
    shopId: shopId.value,
    role: role,
    lanTimeout: lanTimeout,
    bleTimeout: bleTimeout,
  );
  ref.onDispose(() {
    unawaited(t.disconnect());
  });
  return t;
});

Future<Transport> _buildTransport({
  required TransportMode mode,
  required String shopId,
  required DeviceRole role,
  required Duration lanTimeout,
  required Duration bleTimeout,
}) async {
  switch (mode) {
    case TransportMode.online:
      if (!Env.hasSupabaseCredentials) {
        // 認証情報なしで online を選んだ場合は Noop に degrade
        // （業務停止より黙って動く方を選ぶ）。
        final NoopTransport t = NoopTransport();
        await t.connect();
        return t;
      }
      try {
        final SupabaseTransport t = SupabaseTransport(
          client: Supabase.instance.client,
          shopId: shopId,
        );
        await t.connect();
        return t;
        // Supabase 未初期化や Realtime チャンネル張り損ねなど、
        // 業務継続を優先して Noop に degrade（テレメトリで可視化）。
      } catch (e, st) {
        AppLogger.w(
          'usecase_providers: SupabaseTransport init failed, falling back to Noop',
          error: e,
          stackTrace: st,
        );
        Telemetry.instance.warn(
          'transport.supabase.init.failure',
          attrs: <String, Object?>{'shop_id': shopId, 'error': e.toString()},
        );
        final NoopTransport t = NoopTransport();
        await t.connect();
        return t;
      }
    case TransportMode.localLan:
      if (role == DeviceRole.register) {
        final LanClient client = LanClient(shopId: shopId);
        final LanTransport inner = LanTransport.client(client);
        await inner.connect();
        return TimeoutTransport(inner: inner, timeout: lanTimeout);
      }
      final LanServer server = LanServer(shopId: shopId, role: role.name);
      final LanTransport inner = LanTransport.server(server);
      await inner.connect();
      return TimeoutTransport(inner: inner, timeout: lanTimeout);
    case TransportMode.bluetooth:
      if (role == DeviceRole.register) {
        final BleCentralService central = BleCentralService(shopId: shopId);
        final BleTransport inner = BleTransport.central(central);
        await inner.connect();
        return TimeoutTransport(inner: inner, timeout: bleTimeout);
      }
      final BlePeripheralService peripheral = BlePeripheralService(
        shopId: shopId,
        role: role.name,
      );
      final BleTransport inner = BleTransport.peripheral(peripheral);
      await inner.connect();
      return TimeoutTransport(inner: inner, timeout: bleTimeout);
  }
}

/// 取消フロー全体（ローカル取消 + Transport 経由の調理中止/取消通知）。
///
/// 店舗ID が未設定の状態では使えないため Future で公開する。
final FutureProvider<CancelOrderFlowUseCase?> cancelOrderFlowUseCaseProvider =
    FutureProvider<CancelOrderFlowUseCase?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      return CancelOrderFlowUseCase(
        cancelOrderUseCase: ref.watch(cancelOrderUseCaseProvider),
        transport: transport,
        shopId: shopId.value,
      );
    });

/// 会計フロー全体（保存 + Transport 送信）。
///
/// 店舗ID が未設定の状態では使えないため Future で公開する。
final FutureProvider<CheckoutFlowUseCase?> checkoutFlowUseCaseProvider =
    FutureProvider<CheckoutFlowUseCase?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      return CheckoutFlowUseCase(
        checkoutUseCase: ref.watch(checkoutUseCaseProvider),
        transport: transport,
        orderRepository: ref.watch(orderRepositoryProvider),
        shopId: shopId.value,
      );
    });

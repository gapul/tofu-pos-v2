import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/transport/ble_transport.dart';
import '../core/transport/lan_transport.dart';
import '../core/transport/noop_transport.dart';
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
import '../features/regi/domain/checkout_flow_usecase.dart';
import 'repository_providers.dart';

final Provider<CheckoutUseCase> checkoutUseCaseProvider =
    Provider<CheckoutUseCase>(
  (Ref<CheckoutUseCase> ref) => CheckoutUseCase(
    unitOfWork: ref.watch(unitOfWorkProvider),
    orderRepository: ref.watch(orderRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
    ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
  ),
);

final Provider<CancelOrderUseCase> cancelOrderUseCaseProvider =
    Provider<CancelOrderUseCase>(
  (Ref<CancelOrderUseCase> ref) => CancelOrderUseCase(
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
  (Ref<CashCloseUseCase> ref) => CashCloseUseCase(
    orderRepository: ref.watch(orderRepositoryProvider),
    cashDrawerRepository: ref.watch(cashDrawerRepositoryProvider),
  ),
);

final Provider<HourlySalesUseCase> hourlySalesUseCaseProvider =
    Provider<HourlySalesUseCase>(
  (Ref<HourlySalesUseCase> ref) => HourlySalesUseCase(
    orderRepository: ref.watch(orderRepositoryProvider),
  ),
);

final Provider<DailyResetUseCase> dailyResetUseCaseProvider =
    Provider<DailyResetUseCase>(
  (Ref<DailyResetUseCase> ref) => DailyResetUseCase(
    dailyResetRepository: ref.watch(dailyResetRepositoryProvider),
    ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
  ),
);

/// 端末間連携の Transport を、現在の TransportMode と DeviceRole から自動選択する。
///
/// - online: NoopTransport（実通信は SyncService + SupabaseRealtimeListener が担う）
/// - localLan: 役割に応じて LanClient（レジ）／LanServer（キッチン・呼び出し）
/// - bluetooth: 役割に応じて BleCentral（レジ）／BlePeripheral（キッチン・呼び出し）
///
/// 店舗ID または役割が未設定なら Noop を返して安全側に倒す。
/// `connect()` は [_buildTransport] 内で呼び、ref.onDispose で disconnect する。
final FutureProvider<Transport> transportProvider = FutureProvider<Transport>(
  (Ref<AsyncValue<Transport>> ref) async {
    final settings = ref.watch(settingsRepositoryProvider);
    final TransportMode mode = await settings.getTransportMode();
    final ShopId? shopId = await settings.getShopId();
    final DeviceRole? role = await settings.getDeviceRole();

    if (shopId == null || role == null) {
      final NoopTransport t = NoopTransport();
      ref.onDispose(t.disconnect);
      return t;
    }

    final Transport t = await _buildTransport(
      mode: mode,
      shopId: shopId.value,
      role: role,
    );
    ref.onDispose(t.disconnect);
    return t;
  },
);

Future<Transport> _buildTransport({
  required TransportMode mode,
  required String shopId,
  required DeviceRole role,
}) async {
  switch (mode) {
    case TransportMode.online:
      // オンライン経路は SyncService（送信）+ SupabaseRealtimeListener（受信）が
      // それぞれ担うため、Transport 抽象としては Noop を返す。
      // CheckoutFlowUseCase の transport.send は no-op になるが、
      // SyncService が未同期注文を Supabase に押し出すので問題ない。
      final NoopTransport t = NoopTransport();
      await t.connect();
      return t;
    case TransportMode.localLan:
      if (role == DeviceRole.register) {
        final LanClient client = LanClient(shopId: shopId);
        final LanTransport inner = LanTransport.client(client);
        await inner.connect();
        return TimeoutTransport(
          inner: inner,
          timeout: const Duration(seconds: 5),
        );
      }
      final LanServer server = LanServer(shopId: shopId, role: role.name);
      final LanTransport inner = LanTransport.server(server);
      await inner.connect();
      return TimeoutTransport(
        inner: inner,
        timeout: const Duration(seconds: 5),
      );
    case TransportMode.bluetooth:
      if (role == DeviceRole.register) {
        final BleCentralService central = BleCentralService(shopId: shopId);
        final BleTransport inner = BleTransport.central(central);
        await inner.connect();
        return TimeoutTransport(
          inner: inner,
          timeout: const Duration(seconds: 10),
        );
      }
      final BlePeripheralService peripheral = BlePeripheralService(
        shopId: shopId,
        role: role.name,
      );
      final BleTransport inner = BleTransport.peripheral(peripheral);
      await inner.connect();
      return TimeoutTransport(
        inner: inner,
        timeout: const Duration(seconds: 10),
      );
  }
}

/// 会計フロー全体（保存 + Transport 送信）。
///
/// 店舗ID が未設定の状態では使えないため Future で公開する。
final FutureProvider<CheckoutFlowUseCase?> checkoutFlowUseCaseProvider =
    FutureProvider<CheckoutFlowUseCase?>(
  (Ref<AsyncValue<CheckoutFlowUseCase?>> ref) async {
    final ShopId? shopId =
        await ref.watch(settingsRepositoryProvider).getShopId();
    if (shopId == null) {
      return null;
    }
    final Transport transport =
        await ref.watch(transportProvider.future);
    return CheckoutFlowUseCase(
      checkoutUseCase: ref.watch(checkoutUseCaseProvider),
      transport: transport,
      orderRepository: ref.watch(orderRepositoryProvider),
      shopId: shopId.value,
    );
  },
);

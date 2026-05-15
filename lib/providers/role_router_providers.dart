import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/sync/device_events_backfill.dart';
import '../core/transport/transport.dart';
import '../domain/enums/device_role.dart';
import '../domain/value_objects/shop_id.dart';
import '../features/calling/domain/calling_ingest_router.dart';
import '../features/calling/domain/calling_ingest_usecase.dart';
import '../features/kitchen/domain/kitchen_ingest_router.dart';
import '../features/kitchen/domain/kitchen_ingest_usecase.dart';
import '../features/kitchen/domain/product_master_ingest_usecase.dart';
import '../features/regi/domain/product_master_auto_broadcaster.dart';
import '../features/regi/domain/product_master_broadcast_usecase.dart';
import '../features/regi/domain/served_to_call_router.dart';
import 'repository_providers.dart';
import 'usecase_providers.dart';

// ============== レジ役のサービス ==============

final FutureProvider<ServedToCallRouter?> servedToCallRouterProvider =
    FutureProvider<ServedToCallRouter?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      final ServedToCallRouter router = ServedToCallRouter(
        transport: transport,
        settingsRepository: ref.watch(settingsRepositoryProvider),
        shopId: shopId.value,
        ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
      );
      ref.onDispose(router.stop);
      return router;
    });

final FutureProvider<ProductMasterBroadcastUseCase?>
productMasterBroadcastUseCaseFutureProvider =
    FutureProvider<ProductMasterBroadcastUseCase?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      return ProductMasterBroadcastUseCase(
        productRepository: ref.watch(productRepositoryProvider),
        transport: transport,
        shopId: shopId.value,
      );
    });

final FutureProvider<ProductMasterAutoBroadcaster?>
productMasterAutoBroadcasterProvider =
    FutureProvider<ProductMasterAutoBroadcaster?>((
      ref,
    ) async {
      final ProductMasterBroadcastUseCase? broadcast = await ref.watch(
        productMasterBroadcastUseCaseFutureProvider.future,
      );
      if (broadcast == null) {
        return null;
      }
      final ProductMasterAutoBroadcaster b = ProductMasterAutoBroadcaster(
        productRepository: ref.watch(productRepositoryProvider),
        broadcast: broadcast,
      );
      ref.onDispose(b.stop);
      return b;
    });

// ============== キッチン役のサービス ==============

final Provider<KitchenIngestUseCase> kitchenIngestUseCaseProvider =
    Provider<KitchenIngestUseCase>((ref) {
      final KitchenIngestUseCase u = KitchenIngestUseCase(
        repository: ref.watch(kitchenOrderRepositoryProvider),
      );
      ref.onDispose(u.dispose);
      return u;
    });

final Provider<ProductMasterIngestUseCase> productMasterIngestUseCaseProvider =
    Provider<ProductMasterIngestUseCase>(
      (ref) => ProductMasterIngestUseCase(
        productRepository: ref.watch(productRepositoryProvider),
      ),
    );

final FutureProvider<KitchenIngestRouter?> kitchenIngestRouterProvider =
    FutureProvider<KitchenIngestRouter?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      final KitchenIngestRouter router = KitchenIngestRouter(
        transport: transport,
        ingest: ref.watch(kitchenIngestUseCaseProvider),
        productIngest: ref.watch(productMasterIngestUseCaseProvider),
        shopId: shopId.value,
      );
      ref.onDispose(router.stop);
      return router;
    });

// ============== 呼び出し役のサービス ==============

final Provider<CallingIngestUseCase> callingIngestUseCaseProvider =
    Provider<CallingIngestUseCase>(
      (ref) => CallingIngestUseCase(
        repository: ref.watch(callingOrderRepositoryProvider),
      ),
    );

final FutureProvider<CallingIngestRouter?> callingIngestRouterProvider =
    FutureProvider<CallingIngestRouter?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      final CallingIngestRouter router = CallingIngestRouter(
        transport: transport,
        ingest: ref.watch(callingIngestUseCaseProvider),
        shopId: shopId.value,
      );
      ref.onDispose(router.stop);
      return router;
    });

// ============== サーバから過去イベントを取り直す Backfill ==============

/// `device_events` から過去 24 時間分を replay する Backfill。
/// オフライン/Noop の場合は null。
final FutureProvider<DeviceEventsBackfill?> deviceEventsBackfillProvider =
    FutureProvider<DeviceEventsBackfill?>((ref) async {
      if (!Env.hasSupabaseCredentials) {
        return null;
      }
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      try {
        return DeviceEventsBackfill(
          client: Supabase.instance.client,
          shopId: shopId.value,
        );
      } catch (_) {
        return null;
      }
    });

// ============== 役割別の起動エントリポイント ==============

/// デバイス役割に応じて、起動時に必要なルーター/サービスをまとめて開始する。
class RoleStarter {
  RoleStarter(this.ref);
  final Ref ref;

  /// 起動時に呼ぶ。役割が未設定なら何もしない。
  Future<void> start() async {
    final DeviceRole? role = await ref
        .read(settingsRepositoryProvider)
        .getDeviceRole();
    if (role == null) {
      return;
    }
    switch (role) {
      case DeviceRole.register:
        final ServedToCallRouter? r = await ref.read(
          servedToCallRouterProvider.future,
        );
        r?.start();
        final ProductMasterAutoBroadcaster? b = await ref.read(
          productMasterAutoBroadcasterProvider.future,
        );
        b?.start();
        // レジ端末でも呼び出しイベントを受信して呼び出し画面プレビュー
        // (整理券タップで開く /regi/calling) に表示できるよう、
        // CallingIngestRouter を裏で走らせる。
        final CallingIngestRouter? c = await ref.read(
          callingIngestRouterProvider.future,
        );
        c?.start();
        final DeviceEventsBackfill? bf = await ref.read(
          deviceEventsBackfillProvider.future,
        );
        if (c != null && bf != null) {
          await bf.run(onEvent: c.handleEvent);
        }
      case DeviceRole.kitchen:
        final KitchenIngestRouter? r = await ref.read(
          kitchenIngestRouterProvider.future,
        );
        r?.start();
        // 過去イベントを replay（途中参加時のサーバ同期）
        final DeviceEventsBackfill? b = await ref.read(
          deviceEventsBackfillProvider.future,
        );
        if (r != null && b != null) {
          await b.run(onEvent: r.handleEvent);
        }
      case DeviceRole.calling:
        final CallingIngestRouter? r = await ref.read(
          callingIngestRouterProvider.future,
        );
        r?.start();
        final DeviceEventsBackfill? b = await ref.read(
          deviceEventsBackfillProvider.future,
        );
        if (r != null && b != null) {
          await b.run(onEvent: r.handleEvent);
        }
    }
  }
}

final Provider<RoleStarter> roleStarterProvider = Provider<RoleStarter>(
  RoleStarter.new,
);

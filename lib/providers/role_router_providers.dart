import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      case DeviceRole.kitchen:
        final KitchenIngestRouter? r = await ref.read(
          kitchenIngestRouterProvider.future,
        );
        r?.start();
      case DeviceRole.calling:
        final CallingIngestRouter? r = await ref.read(
          callingIngestRouterProvider.future,
        );
        r?.start();
    }
  }
}

final Provider<RoleStarter> roleStarterProvider = Provider<RoleStarter>(
  RoleStarter.new,
);

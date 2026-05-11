import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/transport/transport.dart';
import '../../../../domain/entities/kitchen_order.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/role_router_providers.dart';
import '../../../../providers/usecase_providers.dart';
import '../../domain/kitchen_alert.dart';
import '../../domain/mark_served_usecase.dart';

/// キッチン端末ローカルの注文一覧（仕様書 §5.5 / §6.2）。
final StreamProvider<List<KitchenOrder>> kitchenOrdersProvider =
    StreamProvider<List<KitchenOrder>>(
      (ref) =>
          ref.watch(kitchenOrderRepositoryProvider).watchAll(),
    );

/// 提供完了 UseCase（送信失敗時はリポジトリ側で pending に戻る）。
final FutureProvider<MarkServedUseCase?> markServedUseCaseProvider =
    FutureProvider<MarkServedUseCase?>((
      ref,
    ) async {
      final ShopId? shopId = await ref
          .watch(settingsRepositoryProvider)
          .getShopId();
      if (shopId == null) {
        return null;
      }
      final Transport transport = await ref.watch(transportProvider.future);
      return MarkServedUseCase(
        repository: ref.watch(kitchenOrderRepositoryProvider),
        transport: transport,
        shopId: shopId.value,
      );
    });

/// キッチン警告ストリーム（仕様書 §6.6.5 / §9.4）。
final StreamProvider<KitchenAlert> kitchenAlertsProvider =
    StreamProvider<KitchenAlert>((ref) async* {
      // KitchenIngestUseCase は role 起動時に生成され、
      // RoleStarter 経由で Router に渡されている。
      // UI からは UseCase の alerts ストリームを購読する。
      // dev_console_screen と同じく、UseCase Provider 経由で取り出す。
      yield* ref.watch(kitchenIngestUseCaseProvider).alerts;
    });

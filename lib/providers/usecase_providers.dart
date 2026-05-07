import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/transport/noop_transport.dart';
import '../core/transport/transport.dart';
import '../domain/usecases/cancel_order_usecase.dart';
import '../domain/usecases/checkout_usecase.dart';
import '../domain/usecases/daily_reset_usecase.dart';
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

final Provider<DailyResetUseCase> dailyResetUseCaseProvider =
    Provider<DailyResetUseCase>(
  (Ref<DailyResetUseCase> ref) => DailyResetUseCase(
    dailyResetRepository: ref.watch(dailyResetRepositoryProvider),
    ticketPoolRepository: ref.watch(ticketNumberPoolRepositoryProvider),
  ),
);

/// 端末間連携の Transport。
///
/// 現状は Noop（送受信なし）。今後 SupabaseTransport や LanTransport で差し替える。
final Provider<Transport> transportProvider = Provider<Transport>(
  (Ref<Transport> ref) {
    final NoopTransport t = NoopTransport();
    ref.onDispose(t.disconnect);
    return t;
  },
);

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
    return CheckoutFlowUseCase(
      checkoutUseCase: ref.watch(checkoutUseCaseProvider),
      transport: ref.watch(transportProvider),
      orderRepository: ref.watch(orderRepositoryProvider),
      shopId: shopId.value,
    );
  },
);

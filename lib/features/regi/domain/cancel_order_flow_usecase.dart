import 'package:uuid/uuid.dart';

import '../../../core/error/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/usecases/cancel_order_usecase.dart';
import '../../../domain/value_objects/feature_flags.dart';

/// 取消フロー全体（仕様書 §6.6）。
///
/// 1. CancelOrderUseCase でローカル取消（不可分）
/// 2. キッチン連携オンなら Transport 経由で「調理中止」通知（OrderCancelledEvent）
/// 3. 呼び出し連携オンなら Transport 経由で取消通知（OrderCancelledEvent、同じ型）
///
/// データ厳格性: 通信失敗が起きても、取消はローカルに反映済み（§1.2）。
/// 通信失敗時は [TransportDeliveryException] を投げて UI に伝える。
class CancelOrderFlowUseCase {
  CancelOrderFlowUseCase({
    required CancelOrderUseCase cancelOrderUseCase,
    required Transport transport,
    required String shopId,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  }) : _cancel = cancelOrderUseCase,
       _transport = transport,
       _shopId = shopId,
       _uuid = uuid,
       _now = now;

  final CancelOrderUseCase _cancel;
  final Transport _transport;
  final String _shopId;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<Order> execute({
    required int orderId,
    required FeatureFlags flags,
    required Map<int, int> originalCashDelta,
  }) async {
    // 1. ローカル取消（DB 反映、整理券返却、ログ記録）
    final Order cancelled = await _cancel.execute(
      orderId: orderId,
      flags: flags,
      originalCashDelta: originalCashDelta,
    );

    // 2. キッチン・呼び出しいずれかがオンなら通知
    if (!flags.kitchenLink && !flags.callingLink) {
      return cancelled;
    }

    final OrderCancelledEvent ev = OrderCancelledEvent(
      shopId: _shopId,
      eventId: _uuid.v4(),
      occurredAt: _now(),
      orderId: cancelled.id,
      ticketNumber: cancelled.ticketNumber,
    );

    try {
      await _transport.send(ev);
    } catch (e, st) {
      AppLogger.w(
        'CancelOrderFlow: cancellation notice failed for order #$orderId',
        error: e,
        stackTrace: st,
      );
      throw TransportDeliveryException('取消通知の送信に失敗しました（ローカルの取消は完了しています）: $e');
    }

    return cancelled;
  }
}

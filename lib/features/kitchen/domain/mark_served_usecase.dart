import 'package:uuid/uuid.dart';

import '../../../core/error/app_exceptions.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/kitchen_order.dart';
import '../../../domain/enums/kitchen_status.dart';
import '../../../domain/repositories/kitchen_order_repository.dart';

/// キッチン担当が「提供完了」を押したときの処理（仕様書 §6.2）。
///
/// 1. ローカル状態を done に更新
/// 2. レジ端末へ OrderServedEvent を送信（高緊急、失敗時は例外）
class MarkServedUseCase {
  MarkServedUseCase({
    required KitchenOrderRepository repository,
    required Transport transport,
    required String shopId,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  }) : _repo = repository,
       _transport = transport,
       _shopId = shopId,
       _uuid = uuid,
       _now = now;

  final KitchenOrderRepository _repo;
  final Transport _transport;
  final String _shopId;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<void> execute(int orderId) async {
    final KitchenOrder? order = await _repo.findByOrderId(orderId);
    if (order == null) {
      throw OrderNotCancellableException('注文が見つかりません: $orderId');
    }
    if (order.status == KitchenStatus.cancelled) {
      throw const OrderNotCancellableException('取消済みの注文は提供完了にできません');
    }

    await _repo.updateStatus(orderId, KitchenStatus.done);

    try {
      await _transport.send(
        OrderServedEvent(
          shopId: _shopId,
          eventId: _uuid.v4(),
          occurredAt: _now(),
          orderId: orderId,
          ticketNumber: order.ticketNumber,
        ),
      );
      Telemetry.instance.event(
        'kitchen.served',
        attrs: <String, Object?>{
          'order_id': orderId,
          'ticket': order.ticketNumber.value,
        },
      );
    } catch (e, st) {
      // 送信失敗時はステータスを戻す（ローカルは未確定にする）
      await _repo.updateStatus(orderId, KitchenStatus.pending);
      AppLogger.w('MarkServed: send failed, reverted to pending', error: e);
      Telemetry.instance.error(
        'transport.send.order_served.failed',
        message: '提供完了通知失敗',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{'order_id': orderId},
      );
      throw TransportDeliveryException('提供完了の通知に失敗しました: $e');
    }
  }

  /// Undo（仕様書 §9.4）: done を pending に戻す。
  /// レジ側への取り消し通知は送らない（DevConsole の補助操作）。
  Future<void> undo(int orderId) async {
    final KitchenOrder? order = await _repo.findByOrderId(orderId);
    if (order == null) {
      throw OrderNotCancellableException('注文が見つかりません: $orderId');
    }
    if (order.status != KitchenStatus.done) {
      throw const OrderNotCancellableException('提供完了状態の注文ではありません');
    }
    await _repo.updateStatus(orderId, KitchenStatus.pending);
  }
}

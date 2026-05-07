import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/kitchen_order.dart';
import '../../../domain/enums/kitchen_status.dart';
import '../../../domain/repositories/kitchen_order_repository.dart';

/// レジから受信した OrderSubmittedEvent をキッチン側ローカルストアに永続化する。
///
/// 仕様書 §6.2: 受信した注文は「未調理」状態でリストに表示される。
/// 仕様書 §6.6.5: 取消通知（OrderCancelledEvent）受信時はステータスを cancelled に。
class KitchenIngestUseCase {
  KitchenIngestUseCase({
    required KitchenOrderRepository repository,
    DateTime Function() now = DateTime.now,
  })  : _repo = repository,
        _now = now;

  final KitchenOrderRepository _repo;
  final DateTime Function() _now;

  /// OrderSubmittedEvent を取り込んで未調理状態で永続化。
  Future<void> ingestSubmitted(OrderSubmittedEvent ev) async {
    await _repo.upsert(KitchenOrder(
      orderId: ev.orderId,
      ticketNumber: ev.ticketNumber,
      itemsJson: ev.itemsJson,
      status: KitchenStatus.pending,
      receivedAt: _now(),
    ));
    AppLogger.i('Kitchen ingested order #${ev.orderId} ticket=${ev.ticketNumber}');
  }

  /// OrderCancelledEvent を取り込んでステータスを cancelled にする。
  /// 既に存在しなければ何もしない。
  Future<void> ingestCancelled(OrderCancelledEvent ev) async {
    final KitchenOrder? existing = await _repo.findByOrderId(ev.orderId);
    if (existing == null) {
      AppLogger.w('Kitchen ingest: cancelled event for unknown order #${ev.orderId}');
      return;
    }
    await _repo.updateStatus(ev.orderId, KitchenStatus.cancelled);
    AppLogger.w(
      'Kitchen: order #${ev.orderId} cancelled (was ${existing.status})',
    );
  }
}

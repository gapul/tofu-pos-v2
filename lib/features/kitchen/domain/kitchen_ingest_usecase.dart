import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/kitchen_order.dart';
import '../../../domain/enums/kitchen_status.dart';
import '../../../domain/repositories/kitchen_order_repository.dart';
import 'kitchen_alert.dart';

/// レジから受信した OrderSubmittedEvent / OrderCancelledEvent を
/// キッチン側ローカルストアに永続化する。
///
/// 仕様書 §6.2: 受信した注文は「未調理」状態でリストに表示される。
/// 仕様書 §6.6.5: 取消通知（OrderCancelledEvent）受信時はステータスを cancelled に。
///   既に調理中・調理完了済だった場合は、UI 層が「赤背景＋アラート音」を
///   出すために [alerts] ストリームへ通知する。
class KitchenIngestUseCase {
  KitchenIngestUseCase({
    required KitchenOrderRepository repository,
    DateTime Function() now = DateTime.now,
  })  : _repo = repository,
        _now = now;

  final KitchenOrderRepository _repo;
  final DateTime Function() _now;

  final StreamController<KitchenAlert> _alerts =
      StreamController<KitchenAlert>.broadcast();

  /// 重要通知（取消の中途処理など）を購読するためのストリーム。
  /// UI 層がこれを listen して画面警告・アラート音を出す。
  Stream<KitchenAlert> get alerts => _alerts.stream;

  /// 後始末（テストや role 切替時に呼ぶ）。
  Future<void> dispose() => _alerts.close();

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
  /// 既存ステータスが pending/cancelled 以外（=調理中／提供完了済）だった場合は
  /// alert を発火する（仕様書 §6.6.5）。
  Future<void> ingestCancelled(OrderCancelledEvent ev) async {
    final KitchenOrder? existing = await _repo.findByOrderId(ev.orderId);
    if (existing == null) {
      AppLogger.w(
        'Kitchen ingest: cancelled event for unknown order #${ev.orderId}',
      );
      return;
    }
    final KitchenStatus prev = existing.status;
    await _repo.updateStatus(ev.orderId, KitchenStatus.cancelled);
    AppLogger.w('Kitchen: order #${ev.orderId} cancelled (was $prev)');

    if (prev != KitchenStatus.pending && prev != KitchenStatus.cancelled) {
      _alerts.add(KitchenAlert.cancelledMidProcess(
        orderId: ev.orderId,
        ticketNumber: ev.ticketNumber,
        previousStatus: prev,
      ));
    }
  }
}

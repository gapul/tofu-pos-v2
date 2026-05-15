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
  }) : _repo = repository,
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
  ///
  /// 既に同 `orderId` が存在する場合（backfill replay や Realtime の冪等性
  /// 再受信）は、現在のステータス（done / cancelled 等）を保持したまま
  /// itemsJson / ticketNumber のみ最新値で更新する。
  /// 以前は無条件で `pending` 上書きしていたため、backfill 再生で
  /// 「提供済」が「未調理」に戻る不具合があった（仕様書 §6.2 不変条件）。
  Future<void> ingestSubmitted(OrderSubmittedEvent ev) async {
    final KitchenOrder? existing = await _repo.findByOrderId(ev.orderId);
    final KitchenOrder next = existing != null
        ? existing.copyWith(
            ticketNumber: ev.ticketNumber,
            itemsJson: ev.itemsJson,
            // status / receivedAt は既存値を保持
          )
        : KitchenOrder(
            orderId: ev.orderId,
            ticketNumber: ev.ticketNumber,
            itemsJson: ev.itemsJson,
            status: KitchenStatus.pending,
            receivedAt: _now(),
          );
    await _repo.upsert(next);
    AppLogger.event(
      'kitchen',
      'ingest_submitted',
      fields: <String, Object?>{
        'order_id': ev.orderId,
        'ticket': ev.ticketNumber.value,
        'preserved_status': existing?.status.name,
      },
    );
  }

  /// OrderCancelledEvent を取り込んでステータスを cancelled にする。
  /// 既に存在しなければ何もしない。
  /// 既存ステータスが pending/cancelled 以外（=調理中／提供完了済）だった場合は
  /// alert を発火する（仕様書 §6.6.5）。
  Future<void> ingestCancelled(OrderCancelledEvent ev) async {
    final KitchenOrder? existing = await _repo.findByOrderId(ev.orderId);
    if (existing == null) {
      AppLogger.event(
        'kitchen',
        'ingest_cancelled_unknown',
        fields: <String, Object?>{'order_id': ev.orderId},
        level: AppLogLevel.warn,
      );
      return;
    }
    final KitchenStatus prev = existing.status;
    await _repo.updateStatus(ev.orderId, KitchenStatus.cancelled);
    AppLogger.event(
      'kitchen',
      'ingest_cancelled',
      fields: <String, Object?>{
        'order_id': ev.orderId,
        'prev_status': prev.name,
      },
      level: AppLogLevel.warn,
    );

    if (prev != KitchenStatus.pending && prev != KitchenStatus.cancelled) {
      _alerts.add(
        KitchenAlert.cancelledMidProcess(
          orderId: ev.orderId,
          ticketNumber: ev.ticketNumber,
          previousStatus: prev,
        ),
      );
    }
  }
}

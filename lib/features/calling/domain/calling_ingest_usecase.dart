import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/calling_order.dart';
import '../../../domain/enums/calling_status.dart';
import '../../../domain/repositories/calling_order_repository.dart';

/// レジから受信した CallNumberEvent / OrderCancelledEvent を呼び出し端末側に取り込む。
class CallingIngestUseCase {
  CallingIngestUseCase({
    required CallingOrderRepository repository,
    DateTime Function() now = DateTime.now,
  }) : _repo = repository,
       _now = now;

  final CallingOrderRepository _repo;
  final DateTime Function() _now;

  /// 呼び出し依頼を未呼び出し状態で永続化。
  ///
  /// 既に同 `orderId` が存在する場合（backfill replay や Realtime の冪等性
  /// 再受信）は、現在のステータス（called / pickedUp / cancelled 等）を
  /// 保持したまま ticketNumber のみ最新値で更新する。
  /// 以前は無条件で `pending` 上書きしていたため、backfill 再生で
  /// 「呼び出し済」が「呼び出し前」に戻る不具合があった。
  Future<void> ingestCallNumber(CallNumberEvent ev) async {
    final CallingOrder? existing = await _repo.findByOrderId(ev.orderId);
    final CallingOrder next = existing != null
        ? existing.copyWith(
            ticketNumber: ev.ticketNumber,
            // status / receivedAt は既存値を保持
          )
        : CallingOrder(
            orderId: ev.orderId,
            ticketNumber: ev.ticketNumber,
            status: CallingStatus.pending,
            receivedAt: _now(),
          );
    await _repo.upsert(next);
    AppLogger.event(
      'calling',
      'ingest_call_number',
      fields: <String, Object?>{
        'order_id': ev.orderId,
        'ticket': ev.ticketNumber.value,
        'preserved_status': existing?.status.name,
      },
    );
  }

  /// 取消通知（仕様書 §6.6.6）。既存があれば cancelled に更新、なければ no-op。
  Future<void> ingestCancelled(OrderCancelledEvent ev) async {
    final CallingOrder? existing = await _repo.findByOrderId(ev.orderId);
    if (existing == null) {
      return;
    }
    await _repo.updateStatus(ev.orderId, CallingStatus.cancelled);
    AppLogger.event(
      'calling',
      'ingest_cancelled',
      fields: <String, Object?>{'order_id': ev.orderId},
      level: AppLogLevel.warn,
    );
  }

  /// マークだけ「呼び出し済み」に変える（仕様書 §6.3 の挙動）。
  Future<void> markCalled(int orderId) async {
    await _repo.updateStatus(orderId, CallingStatus.called);
  }

  /// Undo（§9.5）: 呼び出し済み → 呼び出し前に戻す。
  Future<void> undoCall(int orderId) async {
    await _repo.updateStatus(orderId, CallingStatus.pending);
  }
}

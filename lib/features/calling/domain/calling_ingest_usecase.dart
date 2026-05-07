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
  })  : _repo = repository,
        _now = now;

  final CallingOrderRepository _repo;
  final DateTime Function() _now;

  /// 呼び出し依頼を未呼び出し状態で永続化。
  Future<void> ingestCallNumber(CallNumberEvent ev) async {
    await _repo.upsert(CallingOrder(
      orderId: ev.orderId,
      ticketNumber: ev.ticketNumber,
      status: CallingStatus.pending,
      receivedAt: _now(),
    ));
    AppLogger.i('Calling: queued ticket=${ev.ticketNumber}');
  }

  /// 取消通知（仕様書 §6.6.6）。既存があれば cancelled に更新、なければ no-op。
  Future<void> ingestCancelled(OrderCancelledEvent ev) async {
    final CallingOrder? existing = await _repo.findByOrderId(ev.orderId);
    if (existing == null) {
      return;
    }
    await _repo.updateStatus(ev.orderId, CallingStatus.cancelled);
    AppLogger.w('Calling: order #${ev.orderId} cancelled');
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

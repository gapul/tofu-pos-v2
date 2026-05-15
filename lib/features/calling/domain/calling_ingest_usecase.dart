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

  /// 会計確定通知（OrderSubmittedEvent）を「調理待ち」状態で取り込む。
  ///
  /// 業務要件: 会計確定の瞬間から呼び出し端末の「呼び出し前」タブに整理券を
  /// 表示しておきたい（オペレータが調理状況を一覧で把握するため）。ただし
  /// 自動ポップアップ（整理券大画面）は **発火させない**。ポップアップは
  /// CallNumberEvent（提供完了がレジから転送）で [CallingStatus.pending] に
  /// 昇格したタイミングで初めて出す。
  ///
  /// 既に同 orderId が存在する場合は status を保持する（既に pending /
  /// called / pickedUp / cancelled に進んでいるなら戻さない）。
  Future<void> ingestSubmitted(OrderSubmittedEvent ev) async {
    final CallingOrder? existing = await _repo.findByOrderId(ev.orderId);
    final CallingOrder next = existing != null
        ? existing.copyWith(ticketNumber: ev.ticketNumber)
        : CallingOrder(
            orderId: ev.orderId,
            ticketNumber: ev.ticketNumber,
            status: CallingStatus.awaitingKitchen,
            receivedAt: _now(),
          );
    await _repo.upsert(next);
    AppLogger.event(
      'calling',
      'ingest_submitted',
      fields: <String, Object?>{
        'order_id': ev.orderId,
        'ticket': ev.ticketNumber.value,
        'preserved_status': existing?.status.name,
      },
    );
  }

  /// 呼び出し依頼を未呼び出し状態で永続化。
  ///
  /// 既存があれば:
  ///   - [CallingStatus.awaitingKitchen] → [CallingStatus.pending] に昇格
  ///     （会計確定で先行作成された行を、料理完成で呼び出し可能に切り替える）
  ///   - それ以外（called / pickedUp / cancelled）は status 保持
  ///     （backfill replay や Realtime の冪等性再受信に備える）
  ///
  /// 以前は無条件で `pending` 上書きしていたため、backfill 再生で
  /// 「呼び出し済」が「呼び出し前」に戻る不具合があった。
  Future<void> ingestCallNumber(CallNumberEvent ev) async {
    final CallingOrder? existing = await _repo.findByOrderId(ev.orderId);
    final CallingOrder next;
    if (existing == null) {
      next = CallingOrder(
        orderId: ev.orderId,
        ticketNumber: ev.ticketNumber,
        status: CallingStatus.pending,
        receivedAt: _now(),
      );
    } else if (existing.status == CallingStatus.awaitingKitchen) {
      // awaitingKitchen → pending に昇格（料理完成）。
      next = existing.copyWith(
        ticketNumber: ev.ticketNumber,
        status: CallingStatus.pending,
      );
    } else {
      // called / pickedUp / cancelled / 既に pending: status 保持
      next = existing.copyWith(ticketNumber: ev.ticketNumber);
      if (existing.status == CallingStatus.cancelled) {
        // P3 調査: 取消済みに対する CallNumberEvent はオペレータが
        // 「呼び出しが出ない」と感じる原因になり得る。手動再投入の
        // 判断材料として明示的に警告ログを残す。
        AppLogger.event(
          'calling',
          'call_number_on_cancelled',
          fields: <String, Object?>{
            'order_id': ev.orderId,
            'ticket': ev.ticketNumber.value,
          },
          level: AppLogLevel.warn,
        );
      }
    }
    await _repo.upsert(next);
    AppLogger.event(
      'calling',
      'ingest_call_number',
      fields: <String, Object?>{
        'order_id': ev.orderId,
        'ticket': ev.ticketNumber.value,
        'preserved_status': existing?.status.name,
        'promoted_to_pending':
            existing?.status == CallingStatus.awaitingKitchen,
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

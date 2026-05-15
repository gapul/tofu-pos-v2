import 'dart:convert';

import '../../core/error/app_exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/telemetry/telemetry.dart';
import '../entities/operation_log.dart';
import '../entities/order.dart';
import '../entities/order_item.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';
import '../repositories/cash_drawer_repository.dart';
import '../repositories/operation_log_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/ticket_number_pool_repository.dart';
import '../repositories/unit_of_work.dart';
import '../value_objects/denomination.dart';
import '../value_objects/feature_flags.dart';

/// 注文の取り消し（仕様書 §6.6）。
///
/// 整理券プールは DB と別永続層なので **UoW の外** で操作する:
///
///   1. UoW 内で 注文ステータス更新・在庫戻し・金種戻し・操作ログを記録
///   2. UoW 成功後に 整理券プールへ release を発行
///
/// UoW がロールバックされた場合は release を呼ばない → 整合性が保たれる。
/// 仮に release が独立で失敗してもログだけ残して呼び出し元には成功を返す
/// （注文は取消済みになっており、整理券が無駄遣いされるだけ）。
///
/// 通信フェーズ（キッチン・呼び出しへの取消通知）は本UseCaseの責務外。
class CancelOrderUseCase {
  CancelOrderUseCase({
    required UnitOfWork unitOfWork,
    required OrderRepository orderRepository,
    required ProductRepository productRepository,
    required CashDrawerRepository cashDrawerRepository,
    required TicketNumberPoolRepository ticketPoolRepository,
    OperationLogRepository? operationLogRepository,
    DateTime Function() now = DateTime.now,
  }) : _uow = unitOfWork,
       _orderRepo = orderRepository,
       _productRepo = productRepository,
       _cashRepo = cashDrawerRepository,
       _poolRepo = ticketPoolRepository,
       _logRepo = operationLogRepository,
       _now = now;

  final UnitOfWork _uow;
  final OrderRepository _orderRepo;
  final ProductRepository _productRepo;
  final CashDrawerRepository _cashRepo;
  final TicketNumberPoolRepository _poolRepo;
  final OperationLogRepository? _logRepo;
  final DateTime Function() _now;

  Future<Order> execute({
    required int orderId,
    required FeatureFlags flags,
    required Map<int, int> originalCashDelta,
  }) async {
    final Order updated = await _uow.run<Order>(() async {
      final Order? order = await _orderRepo.findById(orderId);
      if (order == null) {
        throw OrderNotCancellableException('注文が見つかりません: $orderId');
      }
      if (order.orderStatus == OrderStatus.cancelled) {
        throw const OrderNotCancellableException('既に取消済みの注文です');
      }
      // served も終端なので canTransitionTo(cancelled) は false。
      // ただし「提供済の取消」は業務上稀ながらありうるため、ここで弾かない。
      // → 監査用に operation_log を残しつつ、state machine の制約は
      //   通常の遷移にだけ適用する。

      // 1. ステータス更新（取消済 + 未同期）
      //    served（終端）からの取消は state machine 上は不正だが、
      //    業務上稀にある「提供済の事後取消」を許容するため override する。
      //    監査根拠は下記 operation_log に残す。
      await _orderRepo.updateStatus(
        orderId,
        OrderStatus.cancelled,
        allowTerminalOverride: true,
      );
      await _orderRepo.updateSyncStatus(orderId, SyncStatus.notSynced);

      // 2. 在庫を戻す
      if (flags.stockManagement) {
        for (final OrderItem item in order.items) {
          await _productRepo.adjustStock(item.productId, item.quantity);
        }
      }

      // 3. 金種を戻す（元の入出金を逆方向に適用）
      if (flags.cashManagement && originalCashDelta.isNotEmpty) {
        final Map<Denomination, int> reverse = <Denomination, int>{
          for (final MapEntry<int, int> e in originalCashDelta.entries)
            Denomination(e.key): -e.value,
        };
        await _cashRepo.apply(reverse);
      }

      // 4. 操作ログを記録（信用ベース監査の根拠、§6.6）
      if (_logRepo != null) {
        await _logRepo.record(
          kind: OperationKind.cancelOrder,
          targetId: orderId.toString(),
          detailJson: jsonEncode(<String, Object?>{
            'ticket_number': order.ticketNumber.value,
            'final_price_yen': order.finalPrice.yen,
            'item_count': order.items.length,
          }),
          at: _now(),
        );
      }

      return order.copyWith(
        orderStatus: OrderStatus.cancelled,
        syncStatus: SyncStatus.notSynced,
      );
    });

    // 5. 整理券番号を解放（UoW 成功後 / 直列化済み API）。
    //    UoW がロールバックされていれば、ここには来ない → 整理券は in_use の
    //    まま残る（次回 cancel/served で正しく release される）。
    try {
      await _poolRepo.release(updated.ticketNumber);
    } catch (e, st) {
      // release 失敗は業務継続を優先して swallow。
      // ただし「黙って番号が消える」のは避けたいので、
      //   1. error ログ + telemetry で可視化
      //   2. 再試行キューに積む（起動時の flushPendingReleases で消化）
      AppLogger.e(
        'CancelOrderUseCase: ticket release failed for #${updated.ticketNumber.value}',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.error(
        'ticket_pool.release.compensation_failed',
        message: 'cancel_order',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{
          'ticket_number': updated.ticketNumber.value,
          'order_id': updated.id,
          'context': 'cancel_order',
        },
      );
      try {
        await _poolRepo.enqueuePendingRelease(updated.ticketNumber);
      } catch (enqueueErr, enqueueSt) {
        // enqueue 自体の失敗はもう打つ手がない。日次リセットで清掃される前提。
        AppLogger.e(
          'CancelOrderUseCase: failed to enqueue pending release for #${updated.ticketNumber.value}',
          error: enqueueErr,
          stackTrace: enqueueSt,
        );
      }
    }

    return updated;
  }
}

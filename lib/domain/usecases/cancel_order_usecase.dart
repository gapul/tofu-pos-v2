import 'dart:convert';

import '../../core/error/app_exceptions.dart';
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
/// 不可分単位で:
///   1. 注文ステータスを取消済に更新
///   2. 在庫を戻す（在庫管理オン時）
///   3. 金種を戻す（金種管理オン時）
///   4. 整理券番号をプールへ返却
///   5. 同期ステータスを未同期に戻す（クラウドへ取消行を送るため）
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
    return _uow.run<Order>(() async {
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
      await _orderRepo.updateStatus(orderId, OrderStatus.cancelled);
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

      // 4. 整理券番号を解放
      // load + save の直書きは _synchronized を迂回し、並行する allocate と
      // 干渉して番号重複の温床になる。release() API を直接呼んで直列化する。
      await _poolRepo.release(order.ticketNumber);

      // 5. 操作ログを記録（信用ベース監査の根拠、§6.6）
      if (_logRepo != null) {
        await _logRepo.record(
          kind: 'cancel_order',
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
  }
}

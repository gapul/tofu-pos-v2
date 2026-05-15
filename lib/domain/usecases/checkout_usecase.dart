import 'dart:convert';

import '../../core/error/app_exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/telemetry/telemetry.dart';
import '../entities/operation_log.dart';
import '../entities/order.dart';
import '../entities/order_item.dart';
import '../entities/product.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';
import '../repositories/cash_drawer_repository.dart';
import '../repositories/operation_log_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/ticket_number_pool_repository.dart';
import '../repositories/unit_of_work.dart';
import '../value_objects/checkout_draft.dart';
import '../value_objects/denomination.dart';
import '../value_objects/feature_flags.dart';
import '../value_objects/ticket_number.dart';

/// 会計確定（仕様書 §6.1.4）。
///
/// 整理券プール（SharedPreferences I/O）と DB の UoW（drift transaction）は
/// 別系統の永続層なので、トランザクション境界を **分けて** 段階的に進める:
///
///   1. 整理券プールから番号を払い出す（pool.allocate / 直列化済み）
///   2. UoW 内で 注文・明細・在庫・金種 を保存
///      失敗時は外側 catch で pool.release を呼んで補償
///
/// この順にすることで:
///   - allocate が枯渇 → DB を一切触らずに終了
///   - DB 書き込みが失敗 → 整理券を返却して状態の整合性を取り戻す
///
/// 注意: 補償の `release` 自体が失敗する可能性はある（その場合は番号が
/// バッファに戻らず無駄遣いされる）。日次リセットで完全に清掃されるので
/// 業務インパクトは限定的。Telemetry に出して可視化はする。
class CheckoutUseCase {
  CheckoutUseCase({
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
    required CheckoutDraft draft,
    required FeatureFlags flags,
  }) async {
    if (draft.items.isEmpty) {
      throw ArgumentError('Cannot checkout an empty cart');
    }

    // 1. 整理券プールから払い出し（直列化済み API。枯渇は例外）。
    //    UoW の外で先に確定させる：DB を触る前にプールの可否を決める。
    final TicketNumber ticket = await _poolRepo.allocate();

    try {
      return await _uow.run<Order>(() async {
        // 2. 在庫検証（在庫管理オン時）
        if (flags.stockManagement) {
          for (final OrderItem item in draft.items) {
            final Product? product = await _productRepo.findById(
              item.productId,
            );
            if (product == null) {
              throw ArgumentError('Product not found: ${item.productId}');
            }
            if (product.stock < item.quantity) {
              throw InsufficientStockException(
                item.productName,
                item.quantity,
                product.stock,
              );
            }
          }
        }

        // 3. 注文を保存（採番される）
        final Order draftOrder = Order(
          id: 0, // DBが採番
          ticketNumber: ticket,
          items: draft.items,
          discount: draft.discount,
          receivedCash: draft.receivedCash,
          createdAt: _now(),
          orderStatus: OrderStatus.unsent,
          syncStatus: SyncStatus.notSynced,
          customerAttributes: draft.customerAttributes,
        );
        final Order saved = await _orderRepo.create(draftOrder);

        // 4. 在庫減算（在庫管理オン時）
        if (flags.stockManagement) {
          for (final OrderItem item in draft.items) {
            await _productRepo.adjustStock(item.productId, -item.quantity);
          }
        }

        // 5. 金種更新（金種管理オン時）
        if (flags.cashManagement && draft.cashDelta.isNotEmpty) {
          final Map<Denomination, int> delta = <Denomination, int>{
            for (final MapEntry<int, int> e in draft.cashDelta.entries)
              Denomination(e.key): e.value,
          };
          await _cashRepo.apply(delta);
        }

        // 6. 操作ログを記録（信用ベース監査の根拠、§6.6）
        if (_logRepo != null) {
          await _logRepo.record(
            kind: OperationKind.checkout,
            targetId: saved.id.toString(),
            detailJson: jsonEncode(<String, Object?>{
              'ticket_number': saved.ticketNumber.value,
              'final_price_yen': saved.finalPrice.yen,
              'item_count': saved.items.length,
              'received_cash_yen': saved.receivedCash.yen,
            }),
            at: _now(),
          );
        }

        return saved;
      });
    } catch (e, st) {
      // 補償: DB 書き込みが失敗したら整理券を返却する。
      // release 自体の失敗は握りつぶしてログだけ残す（本来の例外を遮らない）。
      try {
        await _poolRepo.release(ticket);
      } catch (releaseErr, releaseSt) {
        // 補償失敗は番号が永続的に in_use のまま残るリスクがある。
        // 致命級として可視化し、再試行キューに積んで起動時に消化させる。
        AppLogger.e(
          'CheckoutUseCase: ticket release compensation failed for #${ticket.value}',
          error: releaseErr,
          stackTrace: releaseSt,
        );
        Telemetry.instance.error(
          'ticket_pool.release.compensation_failed',
          message: 'checkout',
          error: releaseErr,
          stackTrace: releaseSt,
          attrs: <String, Object?>{
            'ticket_number': ticket.value,
            'context': 'checkout',
          },
        );
        try {
          await _poolRepo.enqueuePendingRelease(ticket);
        } catch (enqueueErr, enqueueSt) {
          AppLogger.e(
            'CheckoutUseCase: failed to enqueue pending release for #${ticket.value}',
            error: enqueueErr,
            stackTrace: enqueueSt,
          );
        }
      }
      // 元の例外をそのまま再 throw
      Error.throwWithStackTrace(e, st);
    }
  }
}

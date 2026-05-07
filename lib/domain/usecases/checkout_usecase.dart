import '../../core/error/app_exceptions.dart';
import '../entities/order.dart';
import '../entities/order_item.dart';
import '../entities/product.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';
import '../repositories/cash_drawer_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/ticket_number_pool_repository.dart';
import '../repositories/unit_of_work.dart';
import '../value_objects/checkout_draft.dart';
import '../value_objects/denomination.dart';
import '../value_objects/feature_flags.dart';
import '../value_objects/ticket_number.dart';
import '../value_objects/ticket_number_pool.dart';

/// 会計確定（仕様書 §6.1.4）。
///
/// 不可分単位で:
///   1. 整理券プールから番号を払い出す
///   2. 注文・注文明細を保存
///   3. 在庫を減算（在庫管理オン時）
///   4. 金種を更新（金種管理オン時）
///   5. プールの状態を保存
///
/// 不可分処理が成功した「あと」に通信フェーズへ移る（本UseCaseの責務外）。
class CheckoutUseCase {
  CheckoutUseCase({
    required UnitOfWork unitOfWork,
    required OrderRepository orderRepository,
    required ProductRepository productRepository,
    required CashDrawerRepository cashDrawerRepository,
    required TicketNumberPoolRepository ticketPoolRepository,
    DateTime Function() now = DateTime.now,
  }) : _uow = unitOfWork,
       _orderRepo = orderRepository,
       _productRepo = productRepository,
       _cashRepo = cashDrawerRepository,
       _poolRepo = ticketPoolRepository,
       _now = now;

  final UnitOfWork _uow;
  final OrderRepository _orderRepo;
  final ProductRepository _productRepo;
  final CashDrawerRepository _cashRepo;
  final TicketNumberPoolRepository _poolRepo;
  final DateTime Function() _now;

  Future<Order> execute({
    required CheckoutDraft draft,
    required FeatureFlags flags,
  }) async {
    if (draft.items.isEmpty) {
      throw ArgumentError('Cannot checkout an empty cart');
    }

    return _uow.run<Order>(() async {
      // 1. 在庫検証（在庫管理オン時）
      if (flags.stockManagement) {
        for (final OrderItem item in draft.items) {
          final Product? product = await _productRepo.findById(item.productId);
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

      // 2. 整理券プールから払い出し
      final TicketNumberPool pool = await _poolRepo.load();
      if (!pool.hasAvailable) {
        throw const TicketPoolExhaustedException();
      }
      final ({TicketNumberPool pool, TicketNumber number}) issued = pool
          .issue();

      // 3. 注文を保存（採番される）
      final Order draftOrder = Order(
        id: 0, // DBが採番
        ticketNumber: issued.number,
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

      // 6. プール状態を保存
      await _poolRepo.save(issued.pool);

      return saved;
    });
  }
}

import 'package:drift/drift.dart';

import '../../core/error/app_exceptions.dart';
import '../../domain/entities/customer_attributes.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/customer_attributes_enums.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/enums/sync_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/value_objects/discount.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../datasources/local/database.dart';

class DriftOrderRepository implements OrderRepository {
  DriftOrderRepository(this._db);

  final AppDatabase _db;

  Future<Order> _hydrate(OrderRow row) async {
    final List<OrderItemRow> itemRows = await (_db.select(
      _db.orderItems,
    )..where((t) => t.orderId.equals(row.id))).get();
    final List<OrderItem> items = itemRows
        .map(
          (r) => OrderItem(
            productId: r.productId,
            productName: r.productName,
            priceAtTime: Money(r.priceAtTimeYen),
            quantity: r.quantity,
          ),
        )
        .toList();

    return Order(
      id: row.id,
      ticketNumber: TicketNumber(row.ticketNumber),
      items: items,
      discount: _decodeDiscount(row.discountKind, row.discountValue),
      receivedCash: Money(row.receivedCashYen),
      createdAt: row.createdAt,
      orderStatus: OrderStatus.values.byName(row.orderStatus),
      syncStatus: SyncStatus.values.byName(row.syncStatus),
      customerAttributes: CustomerAttributes(
        age: row.customerAge == null
            ? null
            : CustomerAge.values.byName(row.customerAge!),
        gender: row.customerGender == null
            ? null
            : CustomerGender.values.byName(row.customerGender!),
        group: row.customerGroup == null
            ? null
            : CustomerGroup.values.byName(row.customerGroup!),
      ),
    );
  }

  Discount _decodeDiscount(String kind, int value) {
    if (kind == 'percent') {
      return PercentDiscount(value);
    }
    return AmountDiscount(Money(value));
  }

  ({String kind, int value}) _encodeDiscount(Discount discount) {
    switch (discount) {
      case AmountDiscount(:final Money amount):
        return (kind: 'amount', value: amount.yen);
      case PercentDiscount(:final int percent):
        return (kind: 'percent', value: percent);
    }
  }

  @override
  Future<Order?> findById(int id) async {
    final OrderRow? row = await (_db.select(
      _db.orders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _hydrate(row);
  }

  @override
  Future<List<Order>> findAll({
    DateTime? from,
    DateTime? to,
    int? limit,
    int offset = 0,
  }) async {
    final SimpleSelectStatement<$OrdersTable, OrderRow> q = _db.select(
      _db.orders,
    );
    // 半開区間 [from, to) で扱う。
    // 0:00:00 ちょうどの注文が前日後日両方に集計される事故を防ぐ。
    if (from != null) {
      q.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((t) => t.createdAt.isSmallerThanValue(to));
    }
    q.orderBy(<OrderClauseGenerator<$OrdersTable>>[
      ($OrdersTable t) =>
          OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    if (limit != null) {
      q.limit(limit, offset: offset);
    } else if (offset > 0) {
      // limit なしで offset だけ指定するケース対応（drift は limit 必須）
      q.limit(0x7fffffff, offset: offset);
    }
    final List<OrderRow> rows = await q.get();
    return Future.wait(rows.map(_hydrate));
  }

  @override
  Future<List<Order>> findUnsynced() async {
    final List<OrderRow> rows =
        await (_db.select(_db.orders)..where(
              (t) => t.syncStatus.equals(SyncStatus.notSynced.name),
            ))
            .get();
    return Future.wait(rows.map(_hydrate));
  }

  @override
  Stream<List<Order>> watchAll({DateTime? from, DateTime? to}) {
    final SimpleSelectStatement<$OrdersTable, OrderRow> q = _db.select(
      _db.orders,
    );
    // 半開区間 [from, to) で扱う。
    // 0:00:00 ちょうどの注文が前日後日両方に集計される事故を防ぐ。
    if (from != null) {
      q.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((t) => t.createdAt.isSmallerThanValue(to));
    }
    return q.watch().asyncMap(
      (rows) => Future.wait(rows.map(_hydrate)),
    );
  }

  @override
  Future<Order> create(Order order) async {
    return _db.transaction<Order>(() async {
      final ({String kind, int value}) discount = _encodeDiscount(
        order.discount,
      );
      final int orderId = await _db
          .into(_db.orders)
          .insert(
            OrdersCompanion(
              ticketNumber: Value<int>(order.ticketNumber.value),
              customerAge: Value<String?>(order.customerAttributes.age?.name),
              customerGender: Value<String?>(
                order.customerAttributes.gender?.name,
              ),
              customerGroup: Value<String?>(
                order.customerAttributes.group?.name,
              ),
              discountKind: Value<String>(discount.kind),
              discountValue: Value<int>(discount.value),
              receivedCashYen: Value<int>(order.receivedCash.yen),
              createdAt: Value<DateTime>(order.createdAt),
              orderStatus: Value<String>(order.orderStatus.name),
              syncStatus: Value<String>(order.syncStatus.name),
            ),
          );

      for (final OrderItem item in order.items) {
        await _db
            .into(_db.orderItems)
            .insert(
              OrderItemsCompanion(
                orderId: Value<int>(orderId),
                productId: Value<String>(item.productId),
                productName: Value<String>(item.productName),
                priceAtTimeYen: Value<int>(item.priceAtTime.yen),
                quantity: Value<int>(item.quantity),
              ),
            );
      }

      return order.copyWith(id: orderId);
    });
  }

  @override
  Future<void> updateStatus(
    int id,
    OrderStatus status, {
    bool allowTerminalOverride = false,
  }) async {
    // 状態遷移は OrderStatus.canTransitionTo に従って検証する（仕様書 §5.2）。
    // SELECT → assert → UPDATE をトランザクションで包んで他セッションとの
    // race を防ぐ。ただし行ロック相当はないので、SQLite 単一接続の前提に乗る。
    await _db.transaction(() async {
      final OrderRow? row = await (_db.select(
        _db.orders,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        // 未知 ID は no-op（既存契約を維持）。
        return;
      }
      final OrderStatus current = OrderStatus.values.byName(row.orderStatus);
      if (current == status) {
        // 同一状態は no-op（UPDATE をスキップ）。
        return;
      }
      final bool allowed =
          current.canTransitionTo(status) ||
          (allowTerminalOverride && status == OrderStatus.cancelled);
      if (!allowed) {
        throw InvalidStateTransitionException(
          'OrderStatus #$id: ${current.name} → ${status.name} は許可されていません',
          from: current.name,
          to: status.name,
        );
      }
      await (_db.update(_db.orders)..where((t) => t.id.equals(id))).write(
        OrdersCompanion(orderStatus: Value<String>(status.name)),
      );
    });
  }

  @override
  Future<void> updateSyncStatus(int id, SyncStatus status) async {
    await (_db.update(_db.orders)..where((t) => t.id.equals(id))).write(
      OrdersCompanion(syncStatus: Value<String>(status.name)),
    );
  }

  @override
  Future<void> updateCustomerAttributes(
    int id,
    CustomerAttributes attributes,
  ) async {
    await (_db.update(_db.orders)..where((t) => t.id.equals(id))).write(
      OrdersCompanion(
        customerAge: Value<String?>(attributes.age?.name),
        customerGender: Value<String?>(attributes.gender?.name),
        customerGroup: Value<String?>(attributes.group?.name),
        // 顧客属性追記後は再同期が必要なので notSynced に戻す。
        syncStatus: const Value<String>('notSynced'),
      ),
    );
  }
}

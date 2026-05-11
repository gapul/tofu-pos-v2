import 'package:drift/drift.dart';

import '../../domain/entities/kitchen_order.dart';
import '../../domain/enums/kitchen_status.dart';
import '../../domain/repositories/kitchen_order_repository.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../datasources/local/database.dart';

class DriftKitchenOrderRepository implements KitchenOrderRepository {
  DriftKitchenOrderRepository(this._db);

  final AppDatabase _db;

  KitchenOrder _toEntity(KitchenOrderRow row) {
    return KitchenOrder(
      orderId: row.orderId,
      ticketNumber: TicketNumber(row.ticketNumber),
      itemsJson: row.itemsJson,
      status: KitchenStatus.values.byName(row.status),
      receivedAt: row.receivedAt,
    );
  }

  @override
  Future<KitchenOrder?> findByOrderId(int orderId) async {
    final KitchenOrderRow? row =
        await (_db.select(_db.kitchenOrders)
              ..where((t) => t.orderId.equals(orderId)))
            .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<KitchenOrder>> findAll() async {
    final List<KitchenOrderRow> rows =
        await (_db.select(_db.kitchenOrders)
              ..orderBy(<OrderClauseGenerator<$KitchenOrdersTable>>[
                ($KitchenOrdersTable t) =>
                    OrderingTerm(expression: t.receivedAt),
              ]))
            .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<KitchenOrder>> watchAll() {
    return (_db.select(_db.kitchenOrders)
          ..orderBy(<OrderClauseGenerator<$KitchenOrdersTable>>[
            ($KitchenOrdersTable t) => OrderingTerm(expression: t.receivedAt),
          ]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<void> upsert(KitchenOrder order) async {
    await _db
        .into(_db.kitchenOrders)
        .insertOnConflictUpdate(
          KitchenOrdersCompanion(
            orderId: Value<int>(order.orderId),
            ticketNumber: Value<int>(order.ticketNumber.value),
            itemsJson: Value<String>(order.itemsJson),
            status: Value<String>(order.status.name),
            receivedAt: Value<DateTime>(order.receivedAt),
          ),
        );
  }

  @override
  Future<void> updateStatus(int orderId, KitchenStatus status) async {
    await (_db.update(_db.kitchenOrders)
          ..where((t) => t.orderId.equals(orderId)))
        .write(KitchenOrdersCompanion(status: Value<String>(status.name)));
  }
}

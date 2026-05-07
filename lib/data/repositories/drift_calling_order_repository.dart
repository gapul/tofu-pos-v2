import 'package:drift/drift.dart';

import '../../domain/entities/calling_order.dart';
import '../../domain/enums/calling_status.dart';
import '../../domain/repositories/calling_order_repository.dart';
import '../../domain/value_objects/ticket_number.dart';
import '../datasources/local/database.dart';

class DriftCallingOrderRepository implements CallingOrderRepository {
  DriftCallingOrderRepository(this._db);

  final AppDatabase _db;

  CallingOrder _toEntity(CallingOrderRow row) {
    return CallingOrder(
      orderId: row.orderId,
      ticketNumber: TicketNumber(row.ticketNumber),
      status: CallingStatus.values.byName(row.status),
      receivedAt: row.receivedAt,
    );
  }

  @override
  Future<CallingOrder?> findByOrderId(int orderId) async {
    final CallingOrderRow? row = await (_db.select(_db.callingOrders)
          ..where(($CallingOrdersTable t) => t.orderId.equals(orderId)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<List<CallingOrder>> findAll() async {
    final List<CallingOrderRow> rows = await (_db.select(_db.callingOrders)
          ..orderBy(<OrderClauseGenerator<$CallingOrdersTable>>[
            ($CallingOrdersTable t) =>
                OrderingTerm(expression: t.receivedAt),
          ]))
        .get();
    return rows.map(_toEntity).toList();
  }

  @override
  Stream<List<CallingOrder>> watchAll() {
    return (_db.select(_db.callingOrders)
          ..orderBy(<OrderClauseGenerator<$CallingOrdersTable>>[
            ($CallingOrdersTable t) =>
                OrderingTerm(expression: t.receivedAt),
          ]))
        .watch()
        .map((List<CallingOrderRow> rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<void> upsert(CallingOrder order) async {
    await _db.into(_db.callingOrders).insertOnConflictUpdate(
          CallingOrdersCompanion(
            orderId: Value<int>(order.orderId),
            ticketNumber: Value<int>(order.ticketNumber.value),
            status: Value<String>(order.status.name),
            receivedAt: Value<DateTime>(order.receivedAt),
          ),
        );
  }

  @override
  Future<void> updateStatus(int orderId, CallingStatus status) async {
    await (_db.update(_db.callingOrders)
          ..where(($CallingOrdersTable t) => t.orderId.equals(orderId)))
        .write(CallingOrdersCompanion(status: Value<String>(status.name)));
  }
}

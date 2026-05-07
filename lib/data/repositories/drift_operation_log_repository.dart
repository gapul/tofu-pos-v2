import 'package:drift/drift.dart';

import '../../domain/entities/operation_log.dart';
import '../../domain/repositories/operation_log_repository.dart';
import '../datasources/local/database.dart';

class DriftOperationLogRepository implements OperationLogRepository {
  DriftOperationLogRepository(this._db);

  final AppDatabase _db;

  OperationLog _toEntity(OperationLogRow row) {
    return OperationLog(
      id: row.id,
      kind: row.kind,
      targetId: row.targetId,
      detailJson: row.detailJson,
      occurredAt: row.occurredAt,
    );
  }

  @override
  Future<void> record({
    required String kind,
    String? targetId,
    String? detailJson,
    DateTime? at,
  }) async {
    await _db.into(_db.operationLogs).insert(
          OperationLogsCompanion(
            kind: Value<String>(kind),
            targetId: Value<String?>(targetId),
            detailJson: Value<String?>(detailJson),
            occurredAt: Value<DateTime>(at ?? DateTime.now()),
          ),
        );
  }

  @override
  Future<List<OperationLog>> findRecent({int limit = 100}) async {
    final List<OperationLogRow> rows = await (_db.select(_db.operationLogs)
          ..orderBy(<OrderClauseGenerator<$OperationLogsTable>>[
            ($OperationLogsTable t) =>
                OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
            // 同時刻のときは id 降順（後から記録した方が新しい）。
            ($OperationLogsTable t) =>
                OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows.map(_toEntity).toList();
  }
}

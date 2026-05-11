import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/data/repositories/drift_operation_log_repository.dart';
import 'package:tofu_pos/domain/entities/operation_log.dart';

void main() {
  late AppDatabase db;
  late DriftOperationLogRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DriftOperationLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('records and retrieves a log entry', () async {
    await repo.record(
      kind: 'cancel_order',
      targetId: '42',
      detailJson: '{"reason":"customer_request"}',
      at: DateTime(2026, 5, 7, 12),
    );

    final List<OperationLog> logs = await repo.findRecent();
    expect(logs, hasLength(1));
    expect(logs.single.kind, 'cancel_order');
    expect(logs.single.targetId, '42');
    expect(logs.single.detailJson, '{"reason":"customer_request"}');
  });

  test('findRecent orders by occurredAt desc and respects limit', () async {
    await repo.record(kind: 'a', at: DateTime(2026, 5, 7, 10));
    await repo.record(kind: 'b', at: DateTime(2026, 5, 7, 12));
    await repo.record(kind: 'c', at: DateTime(2026, 5, 7, 11));

    final List<OperationLog> recent = await repo.findRecent(limit: 2);
    expect(recent.map((l) => l.kind), <String>['b', 'c']);
  });
}

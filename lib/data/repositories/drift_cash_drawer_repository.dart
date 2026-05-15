import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/cash_drawer.dart';
import '../../domain/entities/operation_log.dart';
import '../../domain/repositories/cash_drawer_repository.dart';
import '../../domain/repositories/operation_log_repository.dart';
import '../../domain/value_objects/denomination.dart';
import '../datasources/local/database.dart';

class DriftCashDrawerRepository implements CashDrawerRepository {
  DriftCashDrawerRepository(
    this._db, {
    OperationLogRepository? operationLogRepository,
    DateTime Function() now = DateTime.now,
  }) : _logRepo = operationLogRepository,
       _now = now;

  final AppDatabase _db;
  final OperationLogRepository? _logRepo;
  final DateTime Function() _now;

  CashDrawer _toEntity(List<CashDrawerCountRow> rows) {
    final Map<Denomination, int> counts = <Denomination, int>{
      for (final Denomination d in Denomination.all) d: 0,
    };
    for (final CashDrawerCountRow r in rows) {
      counts[Denomination(r.denomination)] = r.count;
    }
    return CashDrawer(counts);
  }

  @override
  Future<CashDrawer> get() async {
    final List<CashDrawerCountRow> rows = await _db
        .select(_db.cashDrawerCounts)
        .get();
    return _toEntity(rows);
  }

  @override
  Stream<CashDrawer> watch() {
    return _db.select(_db.cashDrawerCounts).watch().map(_toEntity);
  }

  @override
  Future<void> apply(Map<Denomination, int> delta) async {
    await _db.transaction(() async {
      for (final MapEntry<Denomination, int> e in delta.entries) {
        final CashDrawerCountRow? row =
            await (_db.select(_db.cashDrawerCounts)..where(
                  (t) =>
                      t.denomination.equals(e.key.yen),
                ))
                .getSingleOrNull();
        final int current = row?.count ?? 0;
        final int next = current + e.value;
        if (next < 0) {
          throw StateError('CashDrawer: ${e.key} would go negative ($next)');
        }
        await _db
            .into(_db.cashDrawerCounts)
            .insertOnConflictUpdate(
              CashDrawerCountsCompanion(
                denomination: Value<int>(e.key.yen),
                count: Value<int>(next),
              ),
            );
      }
    });
  }

  @override
  Future<void> replace(CashDrawer drawer) async {
    // delete → insert を別ステートメントで実行すると、その間に他セッションが
    // SELECT した時に drawer が空に見える瞬間が生まれる。
    // transaction で囲み、さらに batch で単一の write 操作として束ねることで、
    // SQLite の単一トランザクション境界内に閉じて中間状態を露呈させない。
    // batch 失敗時はトランザクション全体が rollback され旧状態が保たれる。
    await _db.transaction(() async {
      await _db.batch((b) {
        b.deleteWhere(
          _db.cashDrawerCounts,
          (t) => const Constant<bool>(true),
        );
        b.insertAll(_db.cashDrawerCounts, <CashDrawerCountsCompanion>[
          for (final MapEntry<Denomination, int> e in drawer.counts.entries)
            CashDrawerCountsCompanion(
              denomination: Value<int>(e.key.yen),
              count: Value<int>(e.value),
            ),
        ]);
      });
      // 監査ログを **同一トランザクション内** で記録する（仕様書 §6.6）。
      // tx が rollback されればログも一緒に rollback されて整合性が保たれる。
      if (_logRepo != null) {
        await _logRepo.record(
          kind: OperationKind.cashDrawerReplace,
          detailJson: jsonEncode(<String, Object?>{
            'total_yen': drawer.totalAmount.yen,
            'counts': <String, int>{
              for (final MapEntry<Denomination, int> e in drawer.counts.entries)
                e.key.yen.toString(): e.value,
            },
          }),
          at: _now(),
        );
      }
    });
  }
}

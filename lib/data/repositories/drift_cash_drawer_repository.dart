import 'package:drift/drift.dart';

import '../../domain/entities/cash_drawer.dart';
import '../../domain/repositories/cash_drawer_repository.dart';
import '../../domain/value_objects/denomination.dart';
import '../datasources/local/database.dart';

class DriftCashDrawerRepository implements CashDrawerRepository {
  DriftCashDrawerRepository(this._db);

  final AppDatabase _db;

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
    await _db.transaction(() async {
      await _db.delete(_db.cashDrawerCounts).go();
      for (final MapEntry<Denomination, int> e in drawer.counts.entries) {
        await _db
            .into(_db.cashDrawerCounts)
            .insert(
              CashDrawerCountsCompanion(
                denomination: Value<int>(e.key.yen),
                count: Value<int>(e.value),
              ),
            );
      }
    });
  }
}

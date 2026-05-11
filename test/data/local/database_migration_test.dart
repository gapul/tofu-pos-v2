import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';

/// Drift マイグレーションのスモーク。
///
/// 現在は v1 のみで、`onCreate` の経路（新規端末）と「同一バージョンを
/// 開いて beforeOpen の PRAGMA が走る」経路を確認する。
///
/// 将来 v2+ を追加した際は drift_dev の schema_versions を生成して
/// 各バージョンの DB をテストフィクスチャ化することを推奨。
/// 現状は schema_versions tooling を有効化していないため、
/// onUpgrade の単体テストはこのファイルでは行わない（future work）。
void main() {
  test('schemaVersion は 1（更新時はテストも更新する）', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 1);
    await db.close();
  });

  test('新規 DB は onCreate で全テーブルを作成し、beforeOpen で foreign_keys が ON', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    // クエリが通れば onCreate と beforeOpen が動いている。
    final List<dynamic> products =
        await db.select(db.products).get();
    expect(products, isEmpty);

    // foreign_keys が有効化されているか PRAGMA で確認。
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data['foreign_keys'], 1);

    await db.close();
  });

  test('全テーブルへ select 可能（スキーマ完全性のスモーク）', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.orders).get(), isEmpty);
    expect(await db.select(db.orderItems).get(), isEmpty);
    expect(await db.select(db.cashDrawerCounts).get(), isEmpty);
    expect(await db.select(db.kitchenOrders).get(), isEmpty);
    expect(await db.select(db.callingOrders).get(), isEmpty);
    expect(await db.select(db.operationLogs).get(), isEmpty);
    await db.close();
  });
}

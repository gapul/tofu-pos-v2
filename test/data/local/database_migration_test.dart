import 'package:drift/drift.dart';
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
  test('schemaVersion は 2（更新時はテストも更新する）', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 2);
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

  group('v2: kitchen/calling.orderId に orders(id) FK が効く (#3)', () {
    test('存在しない orderId で kitchen_orders に insert すると FK 違反', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // FK enforce が ON であることを保証。
      await db.customStatement('PRAGMA foreign_keys = ON');

      // 親 orders が空の状態で kitchen_orders に直挿入 → FK 違反
      await expectLater(
        db.into(db.kitchenOrders).insert(
              KitchenOrdersCompanion.insert(
                orderId: const Value(999),
                ticketNumber: 1,
                itemsJson: '[]',
                status: 'waiting',
                receivedAt: DateTime(2026, 5, 8),
              ),
            ),
        throwsA(anything),
      );
    });

    test('存在しない orderId で calling_orders に insert すると FK 違反', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement('PRAGMA foreign_keys = ON');

      await expectLater(
        db.into(db.callingOrders).insert(
              CallingOrdersCompanion.insert(
                orderId: const Value(999),
                ticketNumber: 1,
                status: 'waiting',
                receivedAt: DateTime(2026, 5, 8),
              ),
            ),
        throwsA(anything),
      );
    });
  });
}

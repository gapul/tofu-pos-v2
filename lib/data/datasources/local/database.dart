import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

part 'database.g.dart';

// =================== Tables ===================

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get priceYen => integer()();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  IntColumn get displayColor => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DataClassName('OrderRow')
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ticketNumber => integer()();
  TextColumn get customerAge => text().nullable()();
  TextColumn get customerGender => text().nullable()();
  TextColumn get customerGroup => text().nullable()();

  /// 'amount' (円) または 'percent' (%)
  TextColumn get discountKind => text().withDefault(const Constant('amount'))();
  IntColumn get discountValue => integer().withDefault(const Constant(0))();

  IntColumn get receivedCashYen => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  /// OrderStatus.name
  TextColumn get orderStatus => text()();

  /// SyncStatus.name
  TextColumn get syncStatus => text()();
}

@DataClassName('OrderItemRow')
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId =>
      integer().references(Orders, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  IntColumn get priceAtTimeYen => integer()();
  IntColumn get quantity => integer()();
}

@DataClassName('CashDrawerCountRow')
class CashDrawerCounts extends Table {
  IntColumn get denomination => integer()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{denomination};
}

@DataClassName('KitchenOrderRow')
class KitchenOrders extends Table {
  /// orderId はレジ端末で発番された注文IDだが、キッチン端末側では Orders
  /// テーブルに親行が存在しないため、FK 制約は付けない（端末間で table
  /// 所有が異なるイベントソース構成）。
  IntColumn get orderId => integer()();
  IntColumn get ticketNumber => integer()();

  /// JSONエンコード済の明細配列
  TextColumn get itemsJson => text()();

  /// KitchenStatus.name
  TextColumn get status => text()();

  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{orderId};
}

@DataClassName('CallingOrderRow')
class CallingOrders extends Table {
  /// 理由は KitchenOrders と同じ（呼び出し端末側で Orders 親行は持たない）。
  IntColumn get orderId => integer()();
  IntColumn get ticketNumber => integer()();

  /// CallingStatus.name
  TextColumn get status => text()();

  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{orderId};
}

@DataClassName('OperationLogRow')
class OperationLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 操作種別: 'cancel_order' / 'product_master_update' / etc.
  TextColumn get kind => text()();

  /// 関連リソースID（注文ID等、文字列で保持）。
  /// NOTE: kind により注文ID以外（'summary' 等）も入るため orders(id) への
  /// FK は張れない（型も text vs int で不一致）。監査ログの性質上、
  /// 親が消えても残すべきレコードでもあるので、参照整合性は付けない方針。
  TextColumn get targetId => text().nullable()();

  /// 操作詳細のJSON
  TextColumn get detailJson => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
}

// =================== Database ===================

@DriftDatabase(
  tables: <Type>[
    Products,
    Orders,
    OrderItems,
    CashDrawerCounts,
    KitchenOrders,
    CallingOrders,
    OperationLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  /// 現在のスキーマバージョン。
  ///
  /// 変更フロー:
  ///  1. テーブル定義を編集
  ///  2. このバージョンを +1
  ///  3. [migration] の onUpgrade に v(N-1) → vN の遷移を追加
  ///  4. 新規/破壊的変更のテストを `test/data/local/database_migration_test.dart` に追加
  ///
  /// 本番データを破壊しないために守ること:
  ///  - 列追加: `Migrator.addColumn` を使う（DEFAULT を必ず付与）
  ///  - 列削除/型変更: 中間バージョンで「新列を追加 → データ移行 → 旧列を最後に削除」の2段階
  ///  - テーブル削除: 原則禁止。data backfill で空にしてから削除すること
  ///  - 既存ユーザーが居る本番では、決して `m.createAll()` を再実行しない
  ///    （現在の onCreate は新規端末専用）
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // 新規端末: 全テーブルを作成。
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v2: KitchenOrders / CallingOrders.orderId に orders(id) FK を追加（後で撤回）。
      if (from < 2) {
        await _migrateAddOrderFk(m);
      }
      // v3: v2 の FK 制約を撤回。キッチン / 呼び出し端末側では Orders 親行が
      //     存在しないイベントソース構成のため FK 違反で取り込みが失敗していた。
      if (from < 3) {
        await _migrateDropOrderFk(m);
      }
    },
    beforeOpen: (details) async {
      // 外部キー制約を有効化（SQLite はデフォルト無効）。
      // OrderItems → Orders の cascade delete 等が機能するように。
      await customStatement('PRAGMA foreign_keys = ON');
      // WAL モード: 並行 read/write の安定性向上。
      // 複数の Backfill / SyncService / UI クエリが同時走するときに
      // sqlite3 の prepared statement reuse race を避けるための保険。
      // 学園祭規模では性能ペナルティはほぼゼロ。
      await customStatement('PRAGMA journal_mode = WAL');
      // synchronous=NORMAL は WAL とセットで使うのが推奨設定。
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );

  /// v1 → v2: KitchenOrders / CallingOrders.orderId に orders(id) FK を追加。
  ///
  /// SQLite は ALTER TABLE で FK 制約を追加できないため、
  /// 「新スキーマで一時テーブル作成 → 旧テーブルからコピー → drop → rename」
  /// の 4 ステップで再作成する。
  ///
  /// 重要:
  ///  - PRAGMA foreign_keys は beforeOpen で ON されるが、Drift の Migrator は
  ///    `defer foreign keys` の下で実行されるため、コピー中の整合性エラーは
  ///    トランザクション末尾の `PRAGMA foreign_key_check` で検出される。
  ///  - もし v1 時点で既に孤児（親 Order が存在しない子）が残っていたら、
  ///    そのレコードはコピー時に弾く（FK 違反になる前に WHERE EXISTS で除外）。
  Future<void> _migrateAddOrderFk(Migrator m) async {
    Future<void> recreateWithFk({
      required String oldTable,
      required String createNew,
      required String copyFromOld,
    }) async {
      await customStatement('DROP TABLE IF EXISTS ${oldTable}_new');
      await customStatement(createNew);
      await customStatement(copyFromOld);
      await customStatement('DROP TABLE $oldTable');
      await customStatement('ALTER TABLE ${oldTable}_new RENAME TO $oldTable');
    }

    await recreateWithFk(
      oldTable: 'kitchen_orders',
      createNew: '''
        CREATE TABLE kitchen_orders_new (
          order_id INTEGER NOT NULL PRIMARY KEY REFERENCES orders(id) ON DELETE RESTRICT,
          ticket_number INTEGER NOT NULL,
          items_json TEXT NOT NULL,
          status TEXT NOT NULL,
          received_at INTEGER NOT NULL
        )
      ''',
      copyFromOld: '''
        INSERT INTO kitchen_orders_new (order_id, ticket_number, items_json, status, received_at)
        SELECT order_id, ticket_number, items_json, status, received_at
        FROM kitchen_orders
        WHERE EXISTS (SELECT 1 FROM orders WHERE orders.id = kitchen_orders.order_id)
      ''',
    );

    await recreateWithFk(
      oldTable: 'calling_orders',
      createNew: '''
        CREATE TABLE calling_orders_new (
          order_id INTEGER NOT NULL PRIMARY KEY REFERENCES orders(id) ON DELETE RESTRICT,
          ticket_number INTEGER NOT NULL,
          status TEXT NOT NULL,
          received_at INTEGER NOT NULL
        )
      ''',
      copyFromOld: '''
        INSERT INTO calling_orders_new (order_id, ticket_number, status, received_at)
        SELECT order_id, ticket_number, status, received_at
        FROM calling_orders
        WHERE EXISTS (SELECT 1 FROM orders WHERE orders.id = calling_orders.order_id)
      ''',
    );
  }

  /// v2 → v3: v2 で追加した FK 制約を撤回する。
  ///
  /// 端末間でテーブル所有が異なるイベントソース構成（Order はレジ端末側で
  /// 永続化、KitchenOrder/CallingOrder は別端末側）のため、子テーブルから
  /// 親テーブルへの FK は物理的に成立しない。FK 違反で OrderSubmittedEvent
  /// の取り込みが失敗していたため、テーブル再作成で FK を外す。
  Future<void> _migrateDropOrderFk(Migrator m) async {
    Future<void> rebuildWithoutFk({
      required String oldTable,
      required String createNew,
      required String copyFromOld,
    }) async {
      await customStatement('DROP TABLE IF EXISTS ${oldTable}_v3');
      await customStatement(createNew);
      await customStatement(copyFromOld);
      await customStatement('DROP TABLE $oldTable');
      await customStatement('ALTER TABLE ${oldTable}_v3 RENAME TO $oldTable');
    }

    await rebuildWithoutFk(
      oldTable: 'kitchen_orders',
      createNew: '''
        CREATE TABLE kitchen_orders_v3 (
          order_id INTEGER NOT NULL PRIMARY KEY,
          ticket_number INTEGER NOT NULL,
          items_json TEXT NOT NULL,
          status TEXT NOT NULL,
          received_at INTEGER NOT NULL
        )
      ''',
      copyFromOld: '''
        INSERT INTO kitchen_orders_v3 (order_id, ticket_number, items_json, status, received_at)
        SELECT order_id, ticket_number, items_json, status, received_at FROM kitchen_orders
      ''',
    );

    await rebuildWithoutFk(
      oldTable: 'calling_orders',
      createNew: '''
        CREATE TABLE calling_orders_v3 (
          order_id INTEGER NOT NULL PRIMARY KEY,
          ticket_number INTEGER NOT NULL,
          status TEXT NOT NULL,
          received_at INTEGER NOT NULL
        )
      ''',
      copyFromOld: '''
        INSERT INTO calling_orders_v3 (order_id, ticket_number, status, received_at)
        SELECT order_id, ticket_number, status, received_at FROM calling_orders
      ''',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'tofu_pos.sqlite'));

    final String cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    // cachePreparedStatements: false
    // 既定 true だが、macOS Release ビルドで sqlite3 prepared statement の
    // 再利用パス内 (vdbeUnbind → sqlite3_bind_null) で SIGSEGV が再現した。
    // 学園祭規模ではクエリ数が高々数十件/秒で、statement cache を無効化しても
    // 体感性能に影響しない一方、reuse race の根を断てる。
    return NativeDatabase.createInBackground(
      file,
      cachePreparedStatements: false,
    );
  });
}

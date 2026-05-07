import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

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
  TextColumn get discountKind =>
      text().withDefault(const Constant('amount'))();
  IntColumn get discountValue =>
      integer().withDefault(const Constant(0))();

  IntColumn get receivedCashYen =>
      integer().withDefault(const Constant(0))();
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

  /// 関連リソースID（注文ID等、文字列で保持）
  TextColumn get targetId => text().nullable()();

  /// 操作詳細のJSON
  TextColumn get detailJson => text().nullable()();

  DateTimeColumn get occurredAt => dateTime()();
}

// =================== Database ===================

@DriftDatabase(tables: <Type>[
  Products,
  Orders,
  OrderItems,
  CashDrawerCounts,
  KitchenOrders,
  CallingOrders,
  OperationLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          // 外部キー制約を有効化（SQLite はデフォルト無効）。
          // OrderItems → Orders の cascade delete 等が機能するように。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dbFolder = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dbFolder.path, 'tofu_pos.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final String cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

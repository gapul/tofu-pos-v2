import 'package:drift/drift.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/value_objects/money.dart';
import '../datasources/local/database.dart';

class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._db);

  final AppDatabase _db;

  Product _toEntity(ProductRow row) {
    return Product(
      id: row.id,
      name: row.name,
      price: Money(row.priceYen),
      stock: row.stock,
      displayColor: row.displayColor,
      isDeleted: row.isDeleted,
    );
  }

  ProductsCompanion _toCompanion(Product product) {
    return ProductsCompanion(
      id: Value<String>(product.id),
      name: Value<String>(product.name),
      priceYen: Value<int>(product.price.yen),
      stock: Value<int>(product.stock),
      displayColor: Value<int?>(product.displayColor),
      isDeleted: Value<bool>(product.isDeleted),
    );
  }

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) async {
    final SimpleSelectStatement<$ProductsTable, ProductRow> q = _db.select(
      _db.products,
    );
    if (!includeDeleted) {
      q.where(($ProductsTable t) => t.isDeleted.equals(false));
    }
    final List<ProductRow> rows = await q.get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<Product?> findById(String id) async {
    final ProductRow? row = await (_db.select(
      _db.products,
    )..where(($ProductsTable t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Stream<List<Product>> watchAll({bool includeDeleted = false}) {
    final SimpleSelectStatement<$ProductsTable, ProductRow> q = _db.select(
      _db.products,
    );
    if (!includeDeleted) {
      q.where(($ProductsTable t) => t.isDeleted.equals(false));
    }
    return q.watch().map(
      (List<ProductRow> rows) => rows.map(_toEntity).toList(),
    );
  }

  @override
  Future<void> upsert(Product product) async {
    await _db.into(_db.products).insertOnConflictUpdate(_toCompanion(product));
  }

  @override
  Future<void> markDeleted(String id) async {
    await (_db.update(_db.products)
          ..where(($ProductsTable t) => t.id.equals(id)))
        .write(const ProductsCompanion(isDeleted: Value<bool>(true)));
  }

  @override
  Future<void> adjustStock(String productId, int delta) async {
    await _db.transaction(() async {
      final ProductRow? row = await (_db.select(
        _db.products,
      )..where(($ProductsTable t) => t.id.equals(productId))).getSingleOrNull();
      if (row == null) {
        throw StateError('Product not found: $productId');
      }
      final int next = row.stock + delta;
      if (next < 0) {
        throw StateError('Stock would go negative: $productId ($next)');
      }
      await (_db.update(_db.products)
            ..where(($ProductsTable t) => t.id.equals(productId)))
          .write(ProductsCompanion(stock: Value<int>(next)));
    });
  }

  @override
  Future<void> replaceAll(List<Product> products) async {
    final Set<String> incomingIds = <String>{
      for (final Product p in products) p.id,
    };

    await _db.transaction(() async {
      // 1. 受信に含まれない既存商品を論理削除（履歴保護のため物理削除はしない）。
      final List<ProductRow> existing = await _db.select(_db.products).get();
      for (final ProductRow row in existing) {
        if (!incomingIds.contains(row.id) && !row.isDeleted) {
          await (_db.update(_db.products)
                ..where(($ProductsTable t) => t.id.equals(row.id)))
              .write(const ProductsCompanion(isDeleted: Value<bool>(true)));
        }
      }

      // 2. 受信した商品をすべて upsert（isDeleted は entity の値そのまま）。
      for (final Product p in products) {
        await _db.into(_db.products).insertOnConflictUpdate(_toCompanion(p));
      }
    });
  }
}

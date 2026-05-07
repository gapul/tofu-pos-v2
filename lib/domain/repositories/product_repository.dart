import '../entities/product.dart';

/// 商品マスタのリポジトリ抽象。
abstract interface class ProductRepository {
  Future<List<Product>> findAll({bool includeDeleted = false});
  Future<Product?> findById(String id);
  Stream<List<Product>> watchAll({bool includeDeleted = false});

  Future<void> upsert(Product product);
  Future<void> markDeleted(String id);

  /// 在庫を差分で増減する（負で減算）。
  /// 在庫管理オン時のみ呼ばれる前提。
  Future<void> adjustStock(String productId, int delta);
}

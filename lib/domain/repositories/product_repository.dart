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

  /// 商品マスタ全体を置換する（仕様書 §6.5 受信側）。
  ///
  /// 渡されたリストに含まれない既存商品は **論理削除（isDeleted=true）** にする。
  /// 含まれる商品は upsert する。
  /// キッチン端末がレジから ProductMasterUpdateEvent を受け取った時に使う。
  Future<void> replaceAll(List<Product> products);
}

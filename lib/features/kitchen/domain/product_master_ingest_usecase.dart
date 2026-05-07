import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';
import '../../../domain/value_objects/money.dart';

/// レジから受信した商品マスタ（ProductMasterUpdateEvent）をキッチン側ローカル
/// ProductRepository に取り込む UseCase（仕様書 §5.1 全端末が保持 / §6.5）。
class ProductMasterIngestUseCase {
  ProductMasterIngestUseCase({required ProductRepository productRepository})
      : _repo = productRepository;

  final ProductRepository _repo;

  Future<void> ingest(ProductMasterUpdateEvent ev) async {
    final List<dynamic> raw = jsonDecode(ev.productsJson) as List<dynamic>;
    final List<Product> products = raw
        .map((dynamic e) => e as Map<String, dynamic>)
        .map(_decodeProduct)
        .toList();
    await _repo.replaceAll(products);
    AppLogger.i('Kitchen ingested ${products.length} products from master update');
  }

  Product _decodeProduct(Map<String, dynamic> j) {
    return Product(
      id: j['id'] as String,
      name: j['name'] as String,
      price: Money((j['price_yen'] as num).toInt()),
      stock: (j['stock'] as num?)?.toInt() ?? 0,
      displayColor: (j['display_color'] as num?)?.toInt(),
    );
  }
}

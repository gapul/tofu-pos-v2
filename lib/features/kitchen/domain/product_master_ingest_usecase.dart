import 'dart:convert';

import '../../../core/logging/app_logger.dart';
import '../../../core/telemetry/telemetry.dart';
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

  /// 不正なペイロードは握りつぶさず drop + Telemetry。
  /// 1 件パース失敗で全件破棄せず、parseable な行だけ反映する。
  Future<void> ingest(ProductMasterUpdateEvent ev) async {
    final List<dynamic>? raw = _decodeArray(ev.productsJson);
    if (raw == null) {
      return;
    }
    final List<Product> products = <Product>[];
    int dropped = 0;
    for (final dynamic e in raw) {
      final Product? p = _safeDecodeProduct(e);
      if (p == null) {
        dropped++;
      } else {
        products.add(p);
      }
    }
    if (dropped > 0) {
      AppLogger.w(
        'Kitchen ingest dropped $dropped malformed product rows',
      );
      Telemetry.instance.warn(
        'product_master.ingest.partial',
        message: 'dropped malformed rows',
        attrs: <String, Object?>{
          'dropped': dropped,
          'accepted': products.length,
        },
      );
    }
    await _repo.replaceAll(products);
    AppLogger.i(
      'Kitchen ingested ${products.length} products from master update',
    );
  }

  List<dynamic>? _decodeArray(String json) {
    try {
      final dynamic decoded = jsonDecode(json);
      if (decoded is List) return decoded;
    } catch (e, st) {
      AppLogger.w('product master JSON parse failed', error: e, stackTrace: st);
    }
    Telemetry.instance.error(
      'product_master.ingest.parse_failed',
      message: 'productsJson did not decode to a List',
    );
    return null;
  }

  Product? _safeDecodeProduct(Object? e) {
    if (e is! Map) return null;
    try {
      final Map<String, dynamic> j = Map<String, dynamic>.from(e);
      final Object? id = j['id'];
      final Object? name = j['name'];
      final Object? priceYen = j['price_yen'];
      if (id is! String || name is! String || priceYen is! num) {
        return null;
      }
      return Product(
        id: id,
        name: name,
        price: Money(priceYen.toInt()),
        stock: (j['stock'] as num?)?.toInt() ?? 0,
        displayColor: (j['display_color'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

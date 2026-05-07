import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/transport/transport.dart';
import '../../../core/transport/transport_event.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';

/// 商品マスタの全件をキッチン端末へブロードキャスト送信する（仕様書 §6.5）。
///
/// 呼び出しタイミング:
///  - レジで商品を編集（追加/更新/削除）した直後
///  - キッチン端末との接続検知時（再接続後の同期）
///
/// 送信は **低緊急**（ProductMasterUpdateEvent.isHighPriority == false）。
/// 失敗してもユーザーに通知しない。Transport 実装の責務で静かに再試行する。
class ProductMasterBroadcastUseCase {
  ProductMasterBroadcastUseCase({
    required ProductRepository productRepository,
    required Transport transport,
    required String shopId,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _productRepo = productRepository,
        _transport = transport,
        _shopId = shopId,
        _uuid = uuid,
        _now = now;

  final ProductRepository _productRepo;
  final Transport _transport;
  final String _shopId;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<void> execute() async {
    final List<Product> products = await _productRepo.findAll();
    final List<Map<String, Object?>> payload = <Map<String, Object?>>[
      for (final Product p in products)
        <String, Object?>{
          'id': p.id,
          'name': p.name,
          'price_yen': p.price.yen,
          'stock': p.stock,
          'display_color': p.displayColor,
        },
    ];

    final ProductMasterUpdateEvent ev = ProductMasterUpdateEvent(
      shopId: _shopId,
      eventId: _uuid.v4(),
      occurredAt: _now(),
      productsJson: jsonEncode(payload),
    );

    try {
      await _transport.send(ev);
      AppLogger.d(
        'ProductMasterBroadcast: sent ${products.length} products',
      );
    } catch (e, st) {
      // 低緊急: 失敗してもユーザー通知しない（仕様書 §7.2）
      AppLogger.w(
        'ProductMasterBroadcast: send failed (will retry on next opportunity)',
        error: e,
        stackTrace: st,
      );
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';
import '../logging/app_logger.dart';
import '../retry/retry_policy.dart';

/// 商品マスタを Supabase `products` テーブルに upsert する。
///
/// 主キー: (shop_id, product_id)。ローカル DB の論理削除も
/// `is_deleted=true` でクラウドに反映する。
class SupabaseProductSyncClient {
  SupabaseProductSyncClient(
    this._client, {
    RetryPolicy retryPolicy = const RetryPolicy(
      maxDelay: Duration(seconds: 2),
    ),
  }) : _retry = retryPolicy;

  final SupabaseClient _client;
  final RetryPolicy _retry;

  static const String _table = 'products';

  /// 商品リスト全体を upsert する。is_deleted 含めて送る。
  Future<void> push(
    List<Product> products, {
    required String shopId,
  }) async {
    if (products.isEmpty) return;
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[
      for (final Product p in products)
        <String, Object?>{
          'shop_id': shopId,
          'product_id': p.id,
          'name': p.name,
          'price_yen': p.price.yen,
          'stock': p.stock,
          'display_color': p.displayColor,
          'is_deleted': p.isDeleted,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
    ];
    try {
      await _retry.run<void>(() async {
        await _client
            .from(_table)
            .upsert(rows, onConflict: 'shop_id,product_id');
      });
      AppLogger.event(
        'sync',
        'products_pushed',
        fields: <String, Object?>{'count': rows.length},
        level: AppLogLevel.debug,
      );
    } catch (e, st) {
      // 低緊急: ユーザー通知しない (次回 watch / periodic で再送される)。
      AppLogger.w(
        'SupabaseProductSyncClient: push failed (will retry on next opportunity)',
        error: e,
        stackTrace: st,
      );
    }
  }
}

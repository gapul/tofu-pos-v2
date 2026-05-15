import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/product.dart';
import '../../domain/value_objects/money.dart';
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

  /// Supabase から該当店舗の商品マスタを全件取得する。
  /// is_deleted=true も含めて返す (受け取り側が論理削除を尊重するため)。
  /// クラウド未投入で 0 件のときは空リストを返す。
  Future<List<Product>> pull({required String shopId}) async {
    try {
      final List<Map<String, dynamic>> rows = await _retry.run<List<Map<String, dynamic>>>(() async {
        final result = await _client
            .from(_table)
            .select(
              'product_id, name, price_yen, stock, display_color, is_deleted',
            )
            .eq('shop_id', shopId);
        return List<Map<String, dynamic>>.from(result as List);
      });
      return <Product>[
        for (final Map<String, dynamic> r in rows)
          Product(
            id: r['product_id'] as String,
            name: r['name'] as String,
            price: Money((r['price_yen'] as num).toInt()),
            stock: (r['stock'] as num?)?.toInt() ?? 0,
            displayColor: (r['display_color'] as num?)?.toInt(),
            isDeleted: (r['is_deleted'] as bool?) ?? false,
          ),
      ];
    } catch (e, st) {
      AppLogger.w(
        'SupabaseProductSyncClient: pull failed (returning empty)',
        error: e,
        stackTrace: st,
      );
      return const <Product>[];
    }
  }

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

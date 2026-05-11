import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/value_objects/money.dart';
import '../retry/retry_policy.dart';
import 'cloud_sync_client.dart';

/// Supabase 経由の注文同期実装（仕様書 §8）。
///
/// `order_lines` テーブル（仕様書 §8.2 の非正規化形式）に upsert する。
/// 同じ (shop_id, local_order_id, line_no) は冪等に上書きされる。
///
/// **冪等性キー（idempotency_key）**:
///   各行に決定論的な UUID v5（名前空間 = [_idempotencyNamespace]、
///   名前 = "$shopId/$orderId/$lineNo"）を付与する。
///   ネットワーク再試行で同じ行を複数回送っても、クラウド側は
///   `idempotency_key` の UNIQUE 制約 + INSERT ... ON CONFLICT DO NOTHING
///   （または upsert）で安全に重複排除できる。
///
///   **クラウド側スキーマ要件**（このリポジトリ管理外）:
///     - `order_lines.idempotency_key TEXT` カラムを持ち、UNIQUE 制約があること。
///     - 書き込みは upsert (ON CONFLICT (idempotency_key) DO NOTHING/UPDATE) で
///       受けること。
class SupabaseCloudSyncClient implements CloudSyncClient {
  SupabaseCloudSyncClient(
    this._client, {
    RetryPolicy retryPolicy = const RetryPolicy(
      maxDelay: Duration(seconds: 2),
    ),
  }) : _retry = retryPolicy;

  final SupabaseClient _client;
  final RetryPolicy _retry;

  static const String _table = 'order_lines';

  /// idempotency_key 生成用の名前空間 UUID（固定値）。
  /// 値そのものは任意だが、絶対に書き換えないこと（再試行の冪等性が壊れる）。
  static const String _idempotencyNamespace =
      'f6c8b8a2-2a8f-4d2a-9e3a-91f0a3c0d1e7';

  static const Uuid _uuid = Uuid();

  /// (shopId, orderId, lineNo) から決定論的に idempotency_key を生成する。
  ///
  /// 同じ入力に対して常に同じ UUID を返す（UUID v5 / SHA-1 ベース）。
  static String buildIdempotencyKey({
    required String shopId,
    required int orderId,
    required int lineNo,
  }) {
    final String name = '$shopId/$orderId/$lineNo';
    return _uuid.v5(_idempotencyNamespace, name);
  }

  /// Order を「1明細 = 1行」の形式に展開する（純粋関数、テスト容易）。
  static List<Map<String, Object?>> buildRows(
    Order order, {
    required String shopId,
  }) {
    final Money totalPrice = order.totalPrice;
    final Money discountAmount = order.discountAmount;
    final bool cancelled = order.orderStatus == OrderStatus.cancelled;

    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
    for (int i = 0; i < order.items.length; i++) {
      final OrderItem item = order.items[i];
      final int perItemDiscount = totalPrice.isZero
          ? 0
          : (discountAmount.yen * item.subtotal.yen / totalPrice.yen).round();

      final int lineNo = i + 1;
      rows.add(<String, Object?>{
        'shop_id': shopId,
        'local_order_id': order.id,
        'line_no': lineNo,
        'idempotency_key': buildIdempotencyKey(
          shopId: shopId,
          orderId: order.id,
          lineNo: lineNo,
        ),
        'ticket_number': order.ticketNumber.value,
        // 顧客属性は **粗いバケット enum 名**（例 'twenties', 'female'）として送る。
        // 細粒度化や生年齢への変更は ADR-0005 の再レビュー対象。
        // 詳細: docs/adr/0005-customer-enums-sent-to-cloud.md
        'customer_age': order.customerAttributes.age?.name,
        'customer_gender': order.customerAttributes.gender?.name,
        'customer_group': order.customerAttributes.group?.name,
        'order_created_at': order.createdAt.toUtc().toIso8601String(),
        'order_status': order.orderStatus.name,
        'is_cancelled': cancelled,
        'product_id': item.productId,
        'product_name': item.productName,
        'quantity': item.quantity,
        'price_at_time_yen': item.priceAtTime.yen,
        'total_item_price_yen': item.subtotal.yen,
        'discount_per_item_yen': perItemDiscount,
      });
    }
    return rows;
  }

  @override
  Future<void> push(Order order, {required String shopId}) async {
    final List<Map<String, Object?>> rows = buildRows(order, shopId: shopId);
    if (rows.isEmpty) {
      return;
    }
    // upsert は冪等なので一時的なネットワークエラーには自動再試行する。
    // 上位 SyncService 側にも周期再試行があるので、ここは「短時間の瞬断を吸収」
    // する目的で短いリトライにとどめる。
    await _retry.run<void>(() async {
      await _client
          .from(_table)
          .upsert(rows, onConflict: 'shop_id,local_order_id,line_no');
    });
  }
}

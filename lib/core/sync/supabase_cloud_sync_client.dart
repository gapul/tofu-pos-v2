import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/value_objects/money.dart';
import 'cloud_sync_client.dart';

/// Supabase 経由の注文同期実装（仕様書 §8）。
///
/// `order_lines` テーブル（仕様書 §8.2 の非正規化形式）に upsert する。
/// 同じ (shop_id, local_order_id, line_no) は冪等に上書きされる。
class SupabaseCloudSyncClient implements CloudSyncClient {
  SupabaseCloudSyncClient(this._client);

  final SupabaseClient _client;

  static const String _table = 'order_lines';

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

      rows.add(<String, Object?>{
        'shop_id': shopId,
        'local_order_id': order.id,
        'line_no': i + 1,
        'ticket_number': order.ticketNumber.value,
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
    final List<Map<String, Object?>> rows =
        buildRows(order, shopId: shopId);
    if (rows.isEmpty) {
      return;
    }
    await _client.from(_table).upsert(
          rows,
          onConflict: 'shop_id,local_order_id,line_no',
        );
  }
}

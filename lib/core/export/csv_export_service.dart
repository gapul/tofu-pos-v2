import 'package:csv/csv.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';
import '../../domain/enums/order_status.dart';
import '../../domain/value_objects/discount.dart';
import '../../domain/value_objects/money.dart';

/// 注文履歴を CSV として書き出すサービス（仕様書 §8.3）。
///
/// クラウド側のスキーマ（§8.2）に準拠した「1注文明細 = 1行」非正規化形式に加え、
/// アプリ独自項目（注文ID, 取消フラグ）を末尾に追加する。
class CsvExportService {
  const CsvExportService();

  /// クラウド側スキーマ + 拡張カラム。
  static const List<String> headers = <String>[
    'order_id', // アプリ独自: 注文の永続ID
    'shop_id', // 店舗ID
    'ticket_number', // 整理券番号
    'order_created_at', // 注文日時（ISO8601）
    'customer_age',
    'customer_gender',
    'customer_group',
    'product_name',
    'quantity',
    'price_at_time',
    'total_item_price', // quantity * price_at_time
    'discount_per_item', // 全体割引額の按分
    'order_status', // unsent / sent / served / cancelled
    'is_cancelled', // 'true' / 'false'
  ];

  /// 注文リストを CSV 文字列にシリアライズする。
  ///
  /// [shopId] は付加情報として全行に埋め込む。
  String serialize({required Iterable<Order> orders, required String shopId}) {
    final List<List<String>> rows = <List<String>>[headers];

    for (final Order order in orders) {
      final Money totalPrice = order.totalPrice;
      final Money discountAmount = order.discountAmount;
      final bool cancelled = order.orderStatus == OrderStatus.cancelled;

      for (final OrderItem item in order.items) {
        final int perItemDiscount = totalPrice.isZero
            ? 0
            : (discountAmount.yen * item.subtotal.yen / totalPrice.yen).round();

        rows.add(<String>[
          order.id.toString(),
          shopId,
          order.ticketNumber.value.toString(),
          order.createdAt.toIso8601String(),
          order.customerAttributes.age?.name ?? '',
          order.customerAttributes.gender?.name ?? '',
          order.customerAttributes.group?.name ?? '',
          item.productName,
          item.quantity.toString(),
          item.priceAtTime.yen.toString(),
          item.subtotal.yen.toString(),
          perItemDiscount.toString(),
          order.orderStatus.name,
          if (cancelled) 'true' else 'false',
        ]);
      }
    }

    return Csv().encode(rows);
  }
}

/// Discount を読みやすい文字列に変換するヘルパー（参考、CSVには使わない）。
String formatDiscount(Discount d) {
  return switch (d) {
    AmountDiscount(:final Money amount) => '${amount.yen}円',
    PercentDiscount(:final int percent) => '$percent%',
  };
}

import 'package:meta/meta.dart';

import '../value_objects/money.dart';

/// 注文明細（仕様書 §5.3）。
@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.priceAtTime,
    required this.quantity,
  }) : assert(quantity > 0, 'quantity must be positive');

  final String productId;

  /// 注文時点の商品名（マスタ変更に備えてスナップショット）。
  final String productName;

  /// 注文時点の単価（マスタ変更に備えてスナップショット）。
  final Money priceAtTime;

  /// 数量。
  final int quantity;

  /// この明細の小計。
  Money get subtotal => priceAtTime * quantity;

  OrderItem copyWith({
    String? productId,
    String? productName,
    Money? priceAtTime,
    int? quantity,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      priceAtTime: priceAtTime ?? this.priceAtTime,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrderItem &&
          productId == other.productId &&
          productName == other.productName &&
          priceAtTime == other.priceAtTime &&
          quantity == other.quantity);

  @override
  int get hashCode =>
      Object.hash(productId, productName, priceAtTime, quantity);

  @override
  String toString() =>
      'OrderItem($productName x$quantity @ $priceAtTime = $subtotal)';
}

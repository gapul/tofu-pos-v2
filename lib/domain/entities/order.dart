import 'package:meta/meta.dart';

import '../enums/order_status.dart';
import '../enums/sync_status.dart';
import '../value_objects/discount.dart';
import '../value_objects/money.dart';
import '../value_objects/ticket_number.dart';
import 'customer_attributes.dart';
import 'order_item.dart';

/// 注文（仕様書 §5.2）。
///
/// 注文IDはシステム内部の永続連番（DB主キー）、整理券番号は顧客提示用の循環番号。
@immutable
class Order {
  const Order({
    required this.id,
    required this.ticketNumber,
    required this.items,
    required this.discount,
    required this.receivedCash,
    required this.createdAt,
    required this.orderStatus,
    required this.syncStatus,
    this.customerAttributes = CustomerAttributes.empty,
  });

  /// 注文ID（DB主キー、永続連番、再利用なし）。
  final int id;

  /// 整理券番号（顧客提示用、循環）。
  final TicketNumber ticketNumber;

  /// 注文明細。
  final List<OrderItem> items;

  /// 割引・割増。
  final Discount discount;

  /// 預り金。
  final Money receivedCash;

  /// 注文確定時刻。
  final DateTime createdAt;

  /// 注文ステータス。
  final OrderStatus orderStatus;

  /// クラウド同期ステータス。
  final SyncStatus syncStatus;

  /// 顧客属性（顧客属性入力オン時のみ意味を持つ）。
  final CustomerAttributes customerAttributes;

  /// 割引適用前の合計金額（明細小計の合計）。
  Money get totalPrice {
    Money sum = Money.zero;
    for (final OrderItem item in items) {
      sum = sum + item.subtotal;
    }
    return sum;
  }

  /// 割引・割増の適用金額（負の値で割引）。
  Money get discountAmount => discount.asAmount(totalPrice);

  /// 請求金額（= 合計金額 + 割引・割増額）。
  Money get finalPrice => totalPrice + discountAmount;

  /// お釣り（= 預り金 − 請求金額）。負になる場合は不足。
  Money get changeCash => receivedCash - finalPrice;

  bool get isCancelled => orderStatus == OrderStatus.cancelled;

  Order copyWith({
    int? id,
    TicketNumber? ticketNumber,
    List<OrderItem>? items,
    Discount? discount,
    Money? receivedCash,
    DateTime? createdAt,
    OrderStatus? orderStatus,
    SyncStatus? syncStatus,
    CustomerAttributes? customerAttributes,
  }) {
    return Order(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      receivedCash: receivedCash ?? this.receivedCash,
      createdAt: createdAt ?? this.createdAt,
      orderStatus: orderStatus ?? this.orderStatus,
      syncStatus: syncStatus ?? this.syncStatus,
      customerAttributes: customerAttributes ?? this.customerAttributes,
    );
  }

  @override
  String toString() =>
      'Order(id: $id, ticket: $ticketNumber, items: ${items.length}, total: $finalPrice, status: $orderStatus)';
}

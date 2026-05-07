import 'package:meta/meta.dart';

import '../enums/kitchen_status.dart';
import '../value_objects/ticket_number.dart';

/// キッチン端末側の注文（仕様書 §5.5）。
///
/// レジから受信した注文を、調理担当が処理する単位として保持する。
/// 注文ID と整理券番号はレジ側のものをそのまま使う（同期キーになる）。
@immutable
class KitchenOrder {
  const KitchenOrder({
    required this.orderId,
    required this.ticketNumber,
    required this.itemsJson,
    required this.status,
    required this.receivedAt,
  });

  /// レジ側の注文ID。
  final int orderId;

  /// 整理券番号。
  final TicketNumber ticketNumber;

  /// 注文内容（商品名と数量のリスト）の JSON 文字列。
  /// 例: `[{"name": "焼きそば", "qty": 2}]`
  final String itemsJson;

  final KitchenStatus status;
  final DateTime receivedAt;

  KitchenOrder copyWith({
    int? orderId,
    TicketNumber? ticketNumber,
    String? itemsJson,
    KitchenStatus? status,
    DateTime? receivedAt,
  }) {
    return KitchenOrder(
      orderId: orderId ?? this.orderId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      itemsJson: itemsJson ?? this.itemsJson,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  @override
  String toString() =>
      'KitchenOrder(#$orderId ticket=$ticketNumber status=$status)';
}

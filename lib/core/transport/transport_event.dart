import 'package:meta/meta.dart';

import '../../domain/value_objects/ticket_number.dart';

/// 端末間通信で流れるイベント（仕様書 §7.3）。
@immutable
sealed class TransportEvent {
  const TransportEvent({
    required this.shopId,
    required this.eventId,
    required this.occurredAt,
  });

  final String shopId;

  /// 重複検知用の一意ID。
  final String eventId;

  final DateTime occurredAt;

  /// 高緊急（受信ACK必須・失敗時に送信側エラー）。
  bool get isHighPriority;
}

/// 商品マスタ全件配信（レジ → キッチン、低緊急）。
@immutable
class ProductMasterUpdateEvent extends TransportEvent {
  const ProductMasterUpdateEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.productsJson,
  });

  /// JSONエンコード済みの商品マスタ配列。
  final String productsJson;

  @override
  bool get isHighPriority => false;
}

/// 新規注文の通知（レジ → キッチン、高緊急）。
@immutable
class OrderSubmittedEvent extends TransportEvent {
  const OrderSubmittedEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.orderId,
    required this.ticketNumber,
    required this.itemsJson,
  });

  final int orderId;
  final TicketNumber ticketNumber;

  /// JSONエンコード済みの明細配列。
  final String itemsJson;

  @override
  bool get isHighPriority => true;
}

/// 提供完了通知（キッチン → レジ、高緊急）。
@immutable
class OrderServedEvent extends TransportEvent {
  const OrderServedEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.orderId,
    required this.ticketNumber,
  });

  final int orderId;
  final TicketNumber ticketNumber;

  @override
  bool get isHighPriority => true;
}

/// 呼び出し転送（レジ → 呼び出し、高緊急）。
@immutable
class CallNumberEvent extends TransportEvent {
  const CallNumberEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.orderId,
    required this.ticketNumber,
  });

  final int orderId;
  final TicketNumber ticketNumber;

  @override
  bool get isHighPriority => true;
}

/// 呼び出し完了通知（呼び出し → 全端末、低緊急）。
///
/// 呼び出し端末で「呼び出し済」マークを付けたタイミングで発行する。
/// 主目的はサーバ側監査と他端末の状態同期。
@immutable
class CallCompletedEvent extends TransportEvent {
  const CallCompletedEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.orderId,
    required this.ticketNumber,
  });

  final int orderId;
  final TicketNumber ticketNumber;

  @override
  bool get isHighPriority => false;
}

/// 注文取消通知（レジ → キッチン／呼び出し、高緊急）。
///
/// キッチン側ではこれを「調理中止」として扱う（§6.6.5）。
@immutable
class OrderCancelledEvent extends TransportEvent {
  const OrderCancelledEvent({
    required super.shopId,
    required super.eventId,
    required super.occurredAt,
    required this.orderId,
    required this.ticketNumber,
  });

  final int orderId;
  final TicketNumber ticketNumber;

  @override
  bool get isHighPriority => true;
}

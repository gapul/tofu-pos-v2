import 'package:meta/meta.dart';

import '../enums/calling_status.dart';
import '../value_objects/ticket_number.dart';

/// 呼び出し端末側の注文（仕様書 §5.6）。
@immutable
class CallingOrder {
  const CallingOrder({
    required this.orderId,
    required this.ticketNumber,
    required this.status,
    required this.receivedAt,
  });

  final int orderId;
  final TicketNumber ticketNumber;
  final CallingStatus status;
  final DateTime receivedAt;

  CallingOrder copyWith({
    int? orderId,
    TicketNumber? ticketNumber,
    CallingStatus? status,
    DateTime? receivedAt,
  }) {
    return CallingOrder(
      orderId: orderId ?? this.orderId,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      status: status ?? this.status,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }

  @override
  String toString() =>
      'CallingOrder(#$orderId ticket=$ticketNumber status=$status)';
}

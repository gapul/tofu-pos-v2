import 'package:meta/meta.dart';

import '../../../domain/enums/kitchen_status.dart';
import '../../../domain/value_objects/ticket_number.dart';

/// キッチン担当に対する重要通知（仕様書 §6.6.5 / §9.4）。
///
/// 例: 既に調理中・調理完了済の注文が取消されたとき、
/// 赤背景＋アラート音で「現物の処分」を促す必要がある。
@immutable
class KitchenAlert {
  const KitchenAlert._({
    required this.kind,
    required this.orderId,
    required this.ticketNumber,
    required this.previousStatus,
  });

  /// 既に調理開始済みの注文が取消された警告。
  factory KitchenAlert.cancelledMidProcess({
    required int orderId,
    required TicketNumber ticketNumber,
    required KitchenStatus previousStatus,
  }) => KitchenAlert._(
    kind: KitchenAlertKind.cancelledMidProcess,
    orderId: orderId,
    ticketNumber: ticketNumber,
    previousStatus: previousStatus,
  );

  final KitchenAlertKind kind;
  final int orderId;
  final TicketNumber ticketNumber;
  final KitchenStatus previousStatus;

  @override
  String toString() =>
      'KitchenAlert($kind, ticket=$ticketNumber, was=$previousStatus)';
}

enum KitchenAlertKind {
  /// 既に調理中／提供完了の注文が取消された。現物の処分が必要。
  cancelledMidProcess,
}

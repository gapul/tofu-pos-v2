import 'dart:convert';

import 'package:meta/meta.dart';

import '../../../core/transport/transport_event.dart';
import '../../../domain/value_objects/ticket_number.dart';

/// LanProtocol.tryDecode の結果。
///
/// 例外を投げずに成功/失敗を表現するためのシール型。
@immutable
sealed class LanDecodeResult {
  const LanDecodeResult();
}

class LanDecodeOk extends LanDecodeResult {
  const LanDecodeOk(this.event);
  final TransportEvent event;
}

class LanDecodeFailure extends LanDecodeResult {
  const LanDecodeFailure(this.reason, [this.raw]);
  final String reason;
  final String? raw;

  @override
  String toString() => 'LanDecodeFailure($reason)';
}

/// LAN Transport で使うワイヤープロトコル（仕様書 §7）。
///
/// JSON テキストフレームでやり取りする。
/// すべての TransportEvent を共通の `{"kind": "...", ...}` フォーマットに直交化。
///
/// 純粋関数の集合体としてテスト可能に保つ（ソケット非依存）。
class LanProtocol {
  LanProtocol._();

  // ===== Encode =====

  static String encode(TransportEvent event) => jsonEncode(toJson(event));

  static Map<String, Object?> toJson(TransportEvent event) {
    final Map<String, Object?> base = <String, Object?>{
      'shopId': event.shopId,
      'eventId': event.eventId,
      'occurredAt': event.occurredAt.toUtc().toIso8601String(),
    };
    return switch (event) {
      ProductMasterUpdateEvent(:final String productsJson) => <String, Object?>{
        ...base,
        'kind': 'ProductMasterUpdate',
        'productsJson': productsJson,
      },
      OrderSubmittedEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
        :final String itemsJson,
      ) =>
        <String, Object?>{
          ...base,
          'kind': 'OrderSubmitted',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
          'itemsJson': itemsJson,
        },
      OrderServedEvent(:final int orderId, :final TicketNumber ticketNumber) =>
        <String, Object?>{
          ...base,
          'kind': 'OrderServed',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
        },
      CallNumberEvent(:final int orderId, :final TicketNumber ticketNumber) =>
        <String, Object?>{
          ...base,
          'kind': 'CallNumber',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
        },
      CallCompletedEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
        <String, Object?>{
          ...base,
          'kind': 'CallCompleted',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
        },
      OrderPickedUpEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
        <String, Object?>{
          ...base,
          'kind': 'OrderPickedUp',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
        },
      OrderCancelledEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
        <String, Object?>{
          ...base,
          'kind': 'OrderCancelled',
          'orderId': orderId,
          'ticketNumber': ticketNumber.value,
        },
    };
  }

  // ===== Decode =====

  /// JSON 文字列から TransportEvent を復元。失敗時は [FormatException]。
  static TransportEvent decode(String wire) {
    final Object? raw = jsonDecode(wire);
    if (raw is! Map<String, Object?>) {
      throw const FormatException('LAN payload must be a JSON object');
    }
    return fromJson(raw);
  }

  /// 失敗を例外ではなく結果型で返す decode。
  /// 信頼境界（受信ハンドラ）では `decode` ではなくこちらを使い、失敗時は
  /// メッセージを **drop** し、Telemetry に流す（業務を止めない）。
  static LanDecodeResult tryDecode(String wire) {
    final Object? raw;
    try {
      raw = jsonDecode(wire);
    } on FormatException catch (e) {
      return LanDecodeFailure('invalid_json: ${e.message}', wire);
    }
    if (raw is! Map<String, Object?>) {
      return LanDecodeFailure('not_a_json_object', wire);
    }
    final String kind = (raw['kind'] as String?) ?? '';
    if (kind.isEmpty) {
      return LanDecodeFailure('missing_kind', wire);
    }
    try {
      return LanDecodeOk(fromJson(raw));
    } on FormatException catch (e) {
      return LanDecodeFailure('unknown_kind: ${e.message}', wire);
      // strict-cast 配下では数値フィールドへの型不一致は TypeError として伝播する。
      // 信頼境界では業務継続のため Error も握り潰し、failure として上位に返す。
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      return LanDecodeFailure('type_error: $e', wire);
    }
  }

  static TransportEvent fromJson(Map<String, Object?> json) {
    final String kind = (json['kind'] as String?) ?? '';
    final String shopId = (json['shopId'] as String?) ?? '';
    final String eventId = (json['eventId'] as String?) ?? '';
    final DateTime occurredAt =
        DateTime.tryParse((json['occurredAt'] as String?) ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    switch (kind) {
      case 'ProductMasterUpdate':
        return ProductMasterUpdateEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          productsJson: (json['productsJson'] as String?) ?? '[]',
        );
      case 'OrderSubmitted':
        return OrderSubmittedEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
          itemsJson: (json['itemsJson'] as String?) ?? '[]',
        );
      case 'OrderServed':
        return OrderServedEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
        );
      case 'CallNumber':
        return CallNumberEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
        );
      case 'CallCompleted':
        return CallCompletedEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
        );
      case 'OrderPickedUp':
        return OrderPickedUpEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
        );
      case 'OrderCancelled':
        return OrderCancelledEvent(
          shopId: shopId,
          eventId: eventId,
          occurredAt: occurredAt,
          orderId: (json['orderId'] as num?)?.toInt() ?? 0,
          ticketNumber: TicketNumber(
            (json['ticketNumber'] as num?)?.toInt() ?? 1,
          ),
        );
      default:
        throw FormatException('Unknown event kind: $kind');
    }
  }
}

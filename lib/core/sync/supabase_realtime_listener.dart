import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/value_objects/ticket_number.dart';
import '../telemetry/telemetry.dart';

/// Supabase Realtime で `order_lines` テーブルの変更を購読する受信側サービス。
///
/// 仕様書 §7 オンライン主経路の受信側実装。
///
/// 注: `order_lines` は1注文 = 複数行の構造のため、Realtime は明細行ごとに発火する。
/// このサービスはそれをそのまま [RealtimeOrderLineEvent] として公開し、
/// 上位層（Notifier 等）で重複排除や再フェッチを判断する。
class SupabaseRealtimeListener {
  SupabaseRealtimeListener(this._client, {required this.shopId});

  final SupabaseClient _client;
  final String shopId;

  RealtimeChannel? _channel;
  final StreamController<RealtimeOrderLineEvent> _events =
      StreamController<RealtimeOrderLineEvent>.broadcast();

  Stream<RealtimeOrderLineEvent> events() => _events.stream;

  bool get isConnected => _channel != null;

  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    final RealtimeChannel ch = _client
        .channel('order_lines:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_lines',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: _handlePayload,
        );
    _channel = ch;
    ch.subscribe();
  }

  Future<void> disconnect() async {
    final RealtimeChannel? ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  void _handlePayload(PostgresChangePayload payload) {
    final RealtimeOrderLineEvent? ev = parsePayload(payload);
    if (ev != null) {
      _events.add(ev);
    } else {
      Telemetry.instance.warn(
        'realtime.parse.failure',
        attrs: <String, Object?>{'event_type': payload.eventType.name},
      );
    }
  }

  /// 純粋関数化したペイロード変換（テスト用に切り出し）。
  ///
  /// 不正なペイロード（空 row / 必須フィールド欠落 / 型不一致など）は
  /// 例外を投げず null を返す。`_handlePayload` が Telemetry に流して drop する。
  static RealtimeOrderLineEvent? parsePayload(PostgresChangePayload payload) {
    final Map<String, dynamic> row =
        payload.eventType == PostgresChangeEvent.delete
        ? payload.oldRecord
        : payload.newRecord;
    if (row.isEmpty) {
      return null;
    }
    // 必須: shop_id / local_order_id。これらが欠けたら不正ペイロードとして drop。
    final String? shopId = row['shop_id'] as String?;
    final num? localOrderId = row['local_order_id'] as num?;
    if (shopId == null || shopId.isEmpty || localOrderId == null) {
      return null;
    }
    try {
      return RealtimeOrderLineEvent(
        eventType: payload.eventType,
        shopId: shopId,
        localOrderId: localOrderId.toInt(),
        lineNo: (row['line_no'] as num?)?.toInt() ?? 0,
        ticketNumber: TicketNumber(
          (row['ticket_number'] as num?)?.toInt() ?? 1,
        ),
        productName: row['product_name'] as String? ?? '',
        quantity: (row['quantity'] as num?)?.toInt() ?? 0,
        isCancelled: row['is_cancelled'] as bool? ?? false,
        orderStatus: row['order_status'] as String? ?? '',
      );
      // 信頼境界では業務継続のため、型不一致 (TypeError) も握り潰して drop する。
      // ignore: avoid_catching_errors
    } on TypeError {
      return null;
    }
  }
}

/// Realtime で受信した1明細行の変更イベント。
class RealtimeOrderLineEvent {
  const RealtimeOrderLineEvent({
    required this.eventType,
    required this.shopId,
    required this.localOrderId,
    required this.lineNo,
    required this.ticketNumber,
    required this.productName,
    required this.quantity,
    required this.isCancelled,
    required this.orderStatus,
  });

  final PostgresChangeEvent eventType;
  final String shopId;
  final int localOrderId;
  final int lineNo;
  final TicketNumber ticketNumber;
  final String productName;
  final int quantity;
  final bool isCancelled;
  final String orderStatus;

  bool get isInsert => eventType == PostgresChangeEvent.insert;
  bool get isUpdate => eventType == PostgresChangeEvent.update;
}

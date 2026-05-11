import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/value_objects/ticket_number.dart';
import '../error/app_exceptions.dart' show TransportDeliveryException;
import '../logging/app_logger.dart';
import '../retry/retry_policy.dart';
import '../telemetry/telemetry.dart';
import 'transport.dart';
import 'transport_event.dart';

/// Supabase Realtime + `device_events` テーブルを使う Transport 実装。
///
/// 仕様書 §7 オンライン主経路の **シグナリング**部分（端末間メッセージング）。
/// 注文本体の同期は `SyncService` + `order_lines` が担い、こちらとは別経路。
///
/// 送信: `device_events` に INSERT（短いリトライ付き）。
/// 受信: 同テーブルへの INSERT を `shop_id` でフィルタして購読し、`TransportEvent` に復元。
///
/// 自端末の送信が Realtime でエコーバックしてくる重複処理を防ぐため、
/// 直近送信 ID を [_selfIds] に保持して受信側でフィルタする。
class SupabaseTransport implements Transport {
  SupabaseTransport({
    required SupabaseClient client,
    required this.shopId,
    Set<String>? selfEventIds,
    RetryPolicy retryPolicy = const RetryPolicy(
      initialDelay: Duration(milliseconds: 150),
      maxDelay: Duration(milliseconds: 800),
    ),
  }) : _client = client,
       _retry = retryPolicy,
       _selfIds = _SelfIdRing(initial: selfEventIds);

  final SupabaseClient _client;
  final String shopId;
  final RetryPolicy _retry;

  /// 自送信 ID のリングバッファ（[_SelfIdRing] の max=200 件保持）。
  /// Realtime のエコーバック遅延を吸収するため、即時には捨てない。
  final _SelfIdRing _selfIds;

  static const String _table = 'device_events';

  RealtimeChannel? _channel;
  final StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  bool get isConnected => _channel != null;

  @override
  Stream<TransportEvent> events() => _events.stream;

  @override
  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    final RealtimeChannel ch = _client
        .channel('tofu-pos:device-events:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _table,
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

  @override
  Future<void> disconnect() async {
    final RealtimeChannel? ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
    if (!_events.isClosed) {
      await _events.close();
    }
  }

  @override
  Future<void> send(TransportEvent event) async {
    // ループバックフィルタに先に積む。送信失敗しても捨てない（多少残るだけで害は無い）。
    _selfIds.add(event.eventId);

    final Map<String, Object?> row = <String, Object?>{
      'shop_id': event.shopId,
      'event_id': event.eventId,
      'event_type': eventTypeNameOf(event),
      // クラウド整合性のため UTC ISO 8601 で送る。
      'occurred_at': event.occurredAt.toUtc().toIso8601String(),
      'payload': encodePayload(event),
    };

    try {
      await _retry.run<void>(() async {
        await _client.from(_table).insert(row);
      });
    } catch (e, st) {
      AppLogger.w(
        'SupabaseTransport: send failed',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.error(
        'transport.supabase.send.failure',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{
          'event_type': eventTypeNameOf(event),
          'shop_id': event.shopId,
        },
      );
      throw TransportDeliveryException(
        'Supabase Transport 送信失敗 (type=${eventTypeNameOf(event)} '
        'shop=${event.shopId}): $e',
      );
    }
  }

  void _handlePayload(PostgresChangePayload payload) {
    final Map<String, dynamic> row = payload.newRecord;
    if (row.isEmpty) {
      return;
    }
    final String? evId = row['event_id'] as String?;
    if (evId != null && _selfIds.contains(evId)) {
      // 自分が送ったイベントのエコーバック。無視。
      return;
    }
    final TransportEvent? ev = decodeRow(row);
    if (ev == null) {
      AppLogger.w(
        'SupabaseTransport: malformed device_event row (event_type='
        '${row['event_type']})',
      );
      Telemetry.instance.warn(
        'transport.supabase.parse.failure',
        attrs: <String, Object?>{'event_type': row['event_type']},
      );
      return;
    }
    _events.add(ev);
  }

  // ---------------------------------------------------------------------------
  // Encoding / decoding (純粋関数。テスト容易性のため static で公開)
  // ---------------------------------------------------------------------------

  /// `TransportEvent` のサブタイプ名（テーブルの `event_type` 列で使う）。
  static String eventTypeNameOf(TransportEvent event) {
    return switch (event) {
      OrderSubmittedEvent() => 'order_submitted',
      OrderServedEvent() => 'order_served',
      CallNumberEvent() => 'call_number',
      OrderCancelledEvent() => 'order_cancelled',
      ProductMasterUpdateEvent() => 'product_master_update',
    };
  }

  /// 型ごとの非ベースフィールドを Map に変換する（jsonb payload 用）。
  static Map<String, Object?> encodePayload(TransportEvent event) {
    return switch (event) {
      OrderSubmittedEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
        :final String itemsJson,
      ) =>
        <String, Object?>{
          'order_id': orderId,
          'ticket_number': ticketNumber.value,
          'items_json': itemsJson,
        },
      OrderServedEvent(:final int orderId, :final TicketNumber ticketNumber) =>
        <String, Object?>{
          'order_id': orderId,
          'ticket_number': ticketNumber.value,
        },
      CallNumberEvent(:final int orderId, :final TicketNumber ticketNumber) =>
        <String, Object?>{
          'order_id': orderId,
          'ticket_number': ticketNumber.value,
        },
      OrderCancelledEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
        <String, Object?>{
          'order_id': orderId,
          'ticket_number': ticketNumber.value,
        },
      ProductMasterUpdateEvent(:final String productsJson) =>
        <String, Object?>{'products_json': productsJson},
    };
  }

  /// `device_events` の 1 行から `TransportEvent` を復元する。
  ///
  /// 不正な行（必須欠落 / 型不一致 / 未知の event_type）は null を返す。
  /// 信頼境界では業務継続のため、TypeError も握り潰す。
  static TransportEvent? decodeRow(Map<String, dynamic> row) {
    final String? shopId = row['shop_id'] as String?;
    final String? eventId = row['event_id'] as String?;
    final String? type = row['event_type'] as String?;
    final String? occurredAtRaw = row['occurred_at'] as String?;
    if (shopId == null ||
        shopId.isEmpty ||
        eventId == null ||
        eventId.isEmpty ||
        type == null ||
        occurredAtRaw == null) {
      return null;
    }
    final DateTime? occurredAt = DateTime.tryParse(occurredAtRaw);
    if (occurredAt == null) {
      return null;
    }
    // payload は jsonb なので Map で来る想定だが、安全のため緩く受ける。
    final Map<String, dynamic> payload = _asMap(row['payload']);

    try {
      // 多くの型で (order_id, ticket_number) を共通で読むためまとめて取り出す。
      final int? orderId = (payload['order_id'] as num?)?.toInt();
      final int? ticket = (payload['ticket_number'] as num?)?.toInt();
      switch (type) {
        case 'order_submitted':
          final String? itemsJson = payload['items_json'] as String?;
          if (orderId == null || ticket == null || itemsJson == null) {
            return null;
          }
          return OrderSubmittedEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            orderId: orderId,
            ticketNumber: TicketNumber(ticket),
            itemsJson: itemsJson,
          );
        case 'order_served':
          if (orderId == null || ticket == null) return null;
          return OrderServedEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            orderId: orderId,
            ticketNumber: TicketNumber(ticket),
          );
        case 'call_number':
          if (orderId == null || ticket == null) return null;
          return CallNumberEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            orderId: orderId,
            ticketNumber: TicketNumber(ticket),
          );
        case 'order_cancelled':
          if (orderId == null || ticket == null) return null;
          return OrderCancelledEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            orderId: orderId,
            ticketNumber: TicketNumber(ticket),
          );
        case 'product_master_update':
          final String? productsJson = payload['products_json'] as String?;
          if (productsJson == null) return null;
          return ProductMasterUpdateEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            productsJson: productsJson,
          );
        default:
          return null;
      }
      // 型不一致は drop する（信頼境界での既存方針と同じ）。
      // ignore: avoid_catching_errors
    } on TypeError {
      return null;
    }
  }

  static Map<String, dynamic> _asMap(Object? v) {
    if (v is Map) {
      return v.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  /// テスト用: 自送信フィルタの内容（読み取り専用ビュー）。
  Set<String> debugSelfIds() => _selfIds.snapshot();
}

/// 直近送信 ID をリングバッファで保持する小さなヘルパ。
///
/// `LinkedHashSet` で挿入順を保ち、上限超過時に最古を捨てる FIFO 動作。
class _SelfIdRing {
  _SelfIdRing({Set<String>? initial, int max = 200})
    : _max = max,
      _ids = LinkedHashSet<String>() {
    initial?.forEach(add);
  }

  final int _max;
  final LinkedHashSet<String> _ids;

  void add(String id) {
    // 既に持っていたら一度抜いて末尾に積み直す（LRU 的に新しいまま）。
    _ids.remove(id);
    _ids.add(id);
    while (_ids.length > _max) {
      _ids.remove(_ids.first);
    }
  }

  bool contains(String id) => _ids.contains(id);

  Set<String> snapshot() => Set<String>.unmodifiable(_ids);
}

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
  StreamController<TransportEvent> _events =
      StreamController<TransportEvent>.broadcast();

  /// subscribe 完了を待つ際の最大時間。Realtime チャネル張りに数秒程度かかる
  /// ことはあるが、それ以上は業務継続を優先して諦める（HTTP 経由の送信は動く）。
  static const Duration _subscribeTimeout = Duration(seconds: 5);

  /// subscribe 失敗時に自動再試行する初期間隔。Wi-Fi の一時瞬断や Supabase 側
  /// チャネルの timeout/closed を素早くリカバリする。
  /// 3 回失敗するごとに 2 倍に延ばし、`_resubscribeDelayMax` で頭打ちにする。
  static const Duration _resubscribeDelayInitial = Duration(seconds: 3);
  static const Duration _resubscribeDelayMax = Duration(seconds: 30);

  Timer? _resubscribeTimer;
  bool _disposed = false;
  bool _subscribed = false;

  /// 連続した resubscribe 失敗カウント（成功で 0 に戻る）。
  int _resubscribeAttempts = 0;

  /// 「subscribe 成功」を通知する broadcast stream。
  /// IngestRouter 側はこのイベントを受け取ったタイミングで backfill を
  /// 再走させ、Realtime 購読開始**前**にサーバに insert されたイベントを
  /// 取り込み直す。これにより Pull-to-Refresh しなくても新規注文が
  /// キッチン/呼出端末に反映される。
  StreamController<void> _subscribedEvents =
      StreamController<void>.broadcast();
  Stream<void> get onSubscribed => _subscribedEvents.stream;

  bool get isConnected => _channel != null;
  bool get isSubscribed => _subscribed;

  @override
  Stream<TransportEvent> events() => _events.stream;

  @override
  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    // disconnect で StreamController を閉じてしまった後でも再接続できるよう、
    // ここで必要なら新しい broadcast controller を作り直す。
    if (_events.isClosed) {
      _events = StreamController<TransportEvent>.broadcast();
    }
    if (_subscribedEvents.isClosed) {
      _subscribedEvents = StreamController<void>.broadcast();
    }

    final Completer<void> ready = Completer<void>();
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
    _subscribed = false;
    ch.subscribe((status, [_]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _subscribed = true;
        _resubscribeAttempts = 0;
        if (!ready.isCompleted) ready.complete();
        AppLogger.event(
          'transport.supabase',
          'subscribe.ok',
          fields: <String, Object?>{'shop_id': shopId},
        );
        // IngestRouter に通知 → backfill を再走（subscribe **後**到着の遅延
        // 到達分も含めて取り込み直す）。controller が閉じている (dispose 後)
        // 場合の add は ignore。
        if (!_subscribedEvents.isClosed) {
          _subscribedEvents.add(null);
        }
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        // subscribe 失敗は send には影響しない。ready を完了させて connect
        // をブロックしないようにする（receive ができないだけで業務継続）。
        if (!ready.isCompleted) ready.complete();
        // ただし receive ができないままだと P2 として致命なので、自動再試行を
        // スケジュールする。途中で disconnect/dispose されたら止まる。
        final bool wasSubscribed = _subscribed;
        _subscribed = false;
        AppLogger.w(
          'SupabaseTransport: channel status=$status (wasSubscribed=$wasSubscribed); '
          'will resubscribe (attempt ${_resubscribeAttempts + 1})',
        );
        Telemetry.instance.warn(
          'transport.supabase.subscribe.lost',
          attrs: <String, Object?>{
            'shop_id': shopId,
            'status': status.toString(),
            'was_subscribed': wasSubscribed,
          },
        );
        _scheduleResubscribe();
      }
    });
    try {
      await ready.future.timeout(_subscribeTimeout);
    } on TimeoutException catch (e, st) {
      // タイムアウト時もチャネル自体は維持し、送信機能（HTTP insert）で
      // 業務継続。Telemetry にだけ落として可視化する。
      AppLogger.w(
        'SupabaseTransport: subscribe did not confirm in '
        '${_subscribeTimeout.inSeconds}s; continuing without realtime receive',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.warn(
        'transport.supabase.subscribe.timeout',
        attrs: <String, Object?>{
          'shop_id': shopId,
          'timeout_seconds': _subscribeTimeout.inSeconds,
        },
      );
      _scheduleResubscribe();
    }
  }

  /// 一定遅延後に subscribe を張り直す。disconnect/dispose で停止。
  ///
  /// 連続失敗時は指数バックオフ:
  ///   1..3 回目 → 3s, 4..6 回目 → 6s, 7..9 回目 → 12s, 以降 30s (頭打ち)
  /// 3 回連続失敗するごとに 2 倍に伸ばすが、業務継続のため 30s で上限を打つ。
  void _scheduleResubscribe() {
    if (_disposed) return;
    _resubscribeAttempts += 1;
    final int doublings = (_resubscribeAttempts - 1) ~/ 3;
    final int rawSeconds =
        _resubscribeDelayInitial.inSeconds * (1 << doublings);
    final Duration delay = Duration(
      seconds: rawSeconds > _resubscribeDelayMax.inSeconds
          ? _resubscribeDelayMax.inSeconds
          : rawSeconds,
    );
    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(delay, () async {
      if (_disposed) return;
      AppLogger.event(
        'transport.supabase',
        'subscribe.retry',
        fields: <String, Object?>{'shop_id': shopId},
      );
      try {
        // 既存チャネルを捨てて、新しく張り直す。
        final RealtimeChannel? old = _channel;
        _channel = null;
        if (old != null) {
          try {
            await _client.removeChannel(old);
          } catch (_) {
            /* ignore */
          }
        }
        await connect();
      } catch (e, st) {
        AppLogger.w(
          'SupabaseTransport: resubscribe attempt failed',
          error: e,
          stackTrace: st,
        );
        // さらに延ばして retry。
        _scheduleResubscribe();
      }
    });
  }

  @override
  Future<void> disconnect() async {
    // チャネルだけを閉じる。StreamController は閉じないので、`connect()` で
    // 再購読すれば同じ Stream で受信を再開できる（既存リスナーを切らない）。
    _resubscribeTimer?.cancel();
    _resubscribeTimer = null;
    _subscribed = false;
    final RealtimeChannel? ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
  }

  /// アプリ終了時の完全な後始末。これを呼ぶと `events()` の Stream は close
  /// され、以降の `connect()` でも新規 Stream を張り直すことになる。
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    if (!_events.isClosed) {
      await _events.close();
    }
    if (!_subscribedEvents.isClosed) {
      await _subscribedEvents.close();
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
      // 送信失敗は致命級。エラーレベルでログ + 構造化イベントの両方を残す。
      AppLogger.event(
        'transport.supabase',
        'send.failed',
        fields: <String, Object?>{
          'event_type': eventTypeNameOf(event),
          'shop_id': event.shopId,
          'error': e.toString(),
        },
        level: AppLogLevel.error,
      );
      AppLogger.e(
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
      CallCompletedEvent() => 'call_completed',
      OrderPickedUpEvent() => 'order_picked_up',
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
      CallCompletedEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
        <String, Object?>{
          'order_id': orderId,
          'ticket_number': ticketNumber.value,
        },
      OrderPickedUpEvent(
        :final int orderId,
        :final TicketNumber ticketNumber,
      ) =>
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
      ProductMasterUpdateEvent(:final String productsJson) => <String, Object?>{
        'products_json': productsJson,
      },
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
        case 'call_completed':
          if (orderId == null || ticket == null) return null;
          return CallCompletedEvent(
            shopId: shopId,
            eventId: eventId,
            occurredAt: occurredAt,
            orderId: orderId,
            ticketNumber: TicketNumber(ticket),
          );
        case 'order_picked_up':
          if (orderId == null || ticket == null) return null;
          return OrderPickedUpEvent(
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

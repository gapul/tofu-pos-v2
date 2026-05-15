import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/logging/app_logger.dart';
import '../../core/telemetry/telemetry.dart';
import '../../core/transport/supabase_transport.dart';
import '../../core/transport/transport_event.dart';

/// Supabase `device_events` から過去イベントを引いて再生する仕組み。
///
/// 目的:
///  - 新しい役割端末が途中参加した場合、Realtime 購読開始**前**に挿入された
///    イベントを見逃すと既存の注文がキッチン/呼び出し画面に出ない。
///  - 取り込みは upsert で冪等なので、起動時 / Pull-to-Refresh 時に
///    過去 N 時間分を replay すればよい。
class DeviceEventsBackfill {
  DeviceEventsBackfill({
    required SupabaseClient client,
    required String shopId,
    this.window = const Duration(hours: 24),
  })  : _client = client,
        _shopId = shopId;

  final SupabaseClient _client;
  final String _shopId;
  final Duration window;

  /// 現在進行中の run。複数の呼び出し元（RoleStarter / RefreshFromServer / 役割毎の
  /// 起動フック）が同じ backfill を同時に走らせると、drift の prepared statement
  /// が同一 isolate 内で並列に reuse されるパスで NULL ポインタ参照が発生して
  /// macOS Release ビルドが SIGSEGV で落ちる事象が観測された。
  /// 同じ run を共有することで二重実行を avoid する。
  Future<int>? _inFlight;

  /// 過去イベントを取得して [onEvent] に流す。
  ///
  /// 返り値: 正常に取り込めたイベント件数。
  ///
  /// 同時に複数の呼び出しがあった場合は、最初の呼び出しの future を共有して
  /// 二重実行を防ぐ。これにより drift / native sqlite3 の prepared statement
  /// race を回避する。
  Future<int> run({
    required Future<void> Function(TransportEvent) onEvent,
  }) {
    final Future<int>? existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    final Future<int> fut = _runInternal(onEvent);
    _inFlight = fut;
    return fut.whenComplete(() {
      _inFlight = null;
    });
  }

  Future<int> _runInternal(
    Future<void> Function(TransportEvent) onEvent,
  ) async {
    final DateTime since = DateTime.now().toUtc().subtract(window);
    try {
      final List<dynamic> rows = await _client
          .from('device_events')
          .select()
          .eq('shop_id', _shopId)
          .gte('inserted_at', since.toIso8601String())
          .order('inserted_at', ascending: true);
      int processed = 0;
      for (final dynamic raw in rows) {
        final Map<String, dynamic> row = (raw as Map).cast<String, dynamic>();
        final TransportEvent? ev = SupabaseTransport.decodeRow(row);
        if (ev == null) {
          continue;
        }
        try {
          await onEvent(ev);
          processed += 1;
        } catch (e, st) {
          AppLogger.w(
            'DeviceEventsBackfill: event handler failed',
            error: e,
            stackTrace: st,
          );
        }
      }
      Telemetry.instance.event(
        'backfill.completed',
        attrs: <String, Object?>{
          'shop_id': _shopId,
          'count': processed,
          'window_hours': window.inHours,
        },
      );
      return processed;
    } catch (e, st) {
      AppLogger.w(
        'DeviceEventsBackfill: query failed',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.error(
        'backfill.failed',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{'shop_id': _shopId},
      );
      return 0;
    }
  }
}

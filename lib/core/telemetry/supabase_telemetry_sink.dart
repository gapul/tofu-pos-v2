import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';
import 'telemetry_event.dart';
import 'telemetry_sink.dart';

/// Supabase の `telemetry_events` テーブルにバッチ書き込みする実装。
///
/// 1イベントごとに HTTP を打つと負荷が高いので、`batchWindow` 内に積まれた
/// 分をまとめて1回 insert する。送信失敗は AppLogger に warn を出すだけで
/// 握りつぶす（業務を止めない）。
class SupabaseTelemetrySink implements TelemetrySink {
  SupabaseTelemetrySink(
    this._client, {
    Duration batchWindow = const Duration(milliseconds: 300),
    int maxBatchSize = 50,
    int maxBufferSize = 2000,
  }) : _batchWindow = batchWindow,
       _maxBatchSize = maxBatchSize,
       _maxBufferSize = maxBufferSize;

  final SupabaseClient _client;
  final Duration _batchWindow;
  final int _maxBatchSize;

  /// バッファに保持できる上限。超えると古い側から捨てる（オーバーフロー対策）。
  /// 8 時間稼働で 1 端末数千イベント想定なので 2000 で 1 時間分弱を担保。
  final int _maxBufferSize;

  static const String _table = 'telemetry_events';

  final List<TelemetryEvent> _buffer = <TelemetryEvent>[];
  Timer? _timer;
  Future<void>? _inflight;
  int _droppedSinceLastFlush = 0;

  @override
  void enqueue(TelemetryEvent event) {
    if (_buffer.length >= _maxBufferSize) {
      // 古い側を捨てる。クラウド側で「最新の状況」を見たい用途なので
      // 新しいイベントを優先する。
      _buffer.removeAt(0);
      _droppedSinceLastFlush++;
    }
    _buffer.add(event);
    if (_buffer.length >= _maxBatchSize) {
      unawaited(_flushNow());
      return;
    }
    _timer ??= Timer(_batchWindow, _flushNow);
  }

  @override
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await _flushNow();
    await _inflight;
  }

  Future<void> _flushNow() async {
    _timer?.cancel();
    _timer = null;
    if (_buffer.isEmpty) return;
    final List<TelemetryEvent> drained = List<TelemetryEvent>.of(_buffer);
    _buffer.clear();

    final Future<void> task = _send(drained);
    _inflight = task;
    try {
      await task;
    } finally {
      if (identical(_inflight, task)) _inflight = null;
    }
  }

  Future<void> _send(List<TelemetryEvent> events) async {
    try {
      final List<Map<String, Object?>> rows = <Map<String, Object?>>[
        for (final TelemetryEvent e in events) e.toRow(),
      ];
      await _client.from(_table).insert(rows);
      if (_droppedSinceLastFlush > 0) {
        AppLogger.w(
          'Telemetry overflow: $_droppedSinceLastFlush events dropped to keep newest',
        );
        _droppedSinceLastFlush = 0;
      }
    } catch (e, st) {
      // 送信失敗。可能ならバッファに戻して次回再送するが、すでに新規イベントで
      // 溢れてる可能性もあるので _maxBufferSize の範囲で再投入する。
      //
      // 重要: `enqueue` のオーバーフロー drop は「先頭（古い側）から捨てる」。
      // 再投入を先頭に積むと、直後の overflow drop で「再投入したばかりの
      // イベント」が真っ先に捨てられてしまう。`enqueue` の優先方針
      // （新しいイベントを保つ）を尊重するため、再投入は **末尾** に積む。
      final int reinsertable = _maxBufferSize - _buffer.length;
      final int take = reinsertable <= 0
          ? 0
          : (events.length < reinsertable ? events.length : reinsertable);
      if (take > 0) {
        // 再投入対象は古い方から（events の先頭から）取る。新しい側は
        // バッファに残っている可能性が高いので、再送漏れを最小化する。
        _buffer.addAll(events.sublist(0, take));
      }
      final int dropped = events.length - take;
      // 送信失敗は重要：警告ではなく error 相当として可視化する。
      AppLogger.event(
        'telemetry',
        'send.failed',
        fields: <String, Object?>{
          'attempted': events.length,
          'dropped': dropped,
          'error': e.toString(),
        },
        level: AppLogLevel.error,
      );
      // スタックトレースは event() に乗せられないので別途 e() でも出す。
      AppLogger.e(
        'Telemetry send failed (${events.length} events, $dropped dropped)',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 残バッファを送信して内部 Timer を停止する。
  /// 8時間以上連続稼働を想定するためアプリ終了時に必ず呼ぶこと。
  Future<void> close() async {
    _timer?.cancel();
    _timer = null;
    await flush();
  }
}

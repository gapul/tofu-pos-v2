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
  }) : _batchWindow = batchWindow,
       _maxBatchSize = maxBatchSize;

  final SupabaseClient _client;
  final Duration _batchWindow;
  final int _maxBatchSize;

  static const String _table = 'telemetry_events';

  final List<TelemetryEvent> _buffer = <TelemetryEvent>[];
  Timer? _timer;
  Future<void>? _inflight;

  @override
  void enqueue(TelemetryEvent event) {
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
    } catch (e, st) {
      AppLogger.w(
        'Telemetry send failed (${events.length} events dropped)',
        error: e,
        stackTrace: st,
      );
    }
  }
}

import 'telemetry_event.dart';

/// テレメトリイベントの送信先。
///
/// 実装は Supabase 等への非同期 push を想定。失敗時は内部で握りつぶすこと
/// （テレメトリ自体の失敗で業務を止めない）。
abstract interface class TelemetrySink {
  /// バッファに積む（即時送信は保証しない）。
  void enqueue(TelemetryEvent event);

  /// 残った分を直ちに flush する。
  Future<void> flush();
}

/// テレメトリ無効時のデフォルト。何もしない。
class NoopTelemetrySink implements TelemetrySink {
  const NoopTelemetrySink();

  @override
  void enqueue(TelemetryEvent event) {}

  @override
  Future<void> flush() async {}
}

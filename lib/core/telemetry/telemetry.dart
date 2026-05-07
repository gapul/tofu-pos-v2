import 'telemetry_event.dart';
import 'telemetry_sink.dart';

/// アプリ全体で参照するテレメトリのファサード。
///
/// 使い方:
/// ```dart
/// Telemetry.instance.event('order.created', attrs: {'order_id': 42});
/// Telemetry.instance.error('transport.send', error: e, stackTrace: st);
/// ```
///
/// ProviderScope の起動時に [configure] を呼んで shop / device / role を設定する。
/// 未設定時は内部で Noop となり、業務に影響しない。
class Telemetry {
  Telemetry._();

  static final Telemetry instance = Telemetry._();

  TelemetrySink _sink = const NoopTelemetrySink();
  String _shopId = '';
  String _deviceId = '';
  String _deviceRole = '';
  String? _appVersion;
  DateTime Function() _now = DateTime.now;

  bool get isConfigured => _shopId.isNotEmpty && _deviceId.isNotEmpty;

  void configure({
    required TelemetrySink sink,
    required String shopId,
    required String deviceId,
    required String deviceRole,
    String? appVersion,
    DateTime Function()? now,
  }) {
    _sink = sink;
    _shopId = shopId;
    _deviceId = deviceId;
    _deviceRole = deviceRole;
    _appVersion = appVersion;
    if (now != null) _now = now;
  }

  /// 現在のシナリオ ID。DevConsole の Tester から起動・上書きできる。
  /// null でクリア。
  String? scenarioId;

  /// 任意のイベント。
  void event(
    String kind, {
    String? message,
    Map<String, Object?> attrs = const <String, Object?>{},
    TelemetryLevel level = TelemetryLevel.info,
  }) {
    if (!isConfigured) return;
    _sink.enqueue(
      TelemetryEvent(
        shopId: _shopId,
        deviceId: _deviceId,
        deviceRole: _deviceRole,
        kind: kind,
        level: level,
        occurredAt: _now(),
        message: message,
        scenarioId: scenarioId,
        appVersion: _appVersion,
        attrs: attrs,
      ),
    );
  }

  /// 警告レベル（業務継続可能だが要観察）。
  void warn(
    String kind, {
    String? message,
    Map<String, Object?> attrs = const <String, Object?>{},
  }) => event(kind, message: message, attrs: attrs, level: TelemetryLevel.warn);

  /// エラーレベル。例外と stack trace を attrs に展開する。
  void error(
    String kind, {
    String? message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> attrs = const <String, Object?>{},
  }) {
    final Map<String, Object?> merged = <String, Object?>{
      ...attrs,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    event(kind, message: message, attrs: merged, level: TelemetryLevel.error);
  }

  /// テスト用: 内部状態を素のまま戻す。
  void reset() {
    _sink = const NoopTelemetrySink();
    _shopId = '';
    _deviceId = '';
    _deviceRole = '';
    _appVersion = null;
    scenarioId = null;
    _now = DateTime.now;
  }

  Future<void> flush() => _sink.flush();
}

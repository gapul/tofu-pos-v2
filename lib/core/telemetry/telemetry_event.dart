/// テレメトリの重大度。
enum TelemetryLevel { debug, info, warn, error }

/// 端末から Web ダッシュボードに送る単一イベント。
///
/// ペイロードはサイズを抑える。文字列キーで `attrs` に詰め、サーバ側で JSON として保存する。
class TelemetryEvent {
  TelemetryEvent({
    required this.shopId,
    required this.deviceId,
    required this.deviceRole,
    required this.kind,
    required this.level,
    required this.occurredAt,
    this.message,
    this.scenarioId,
    this.appVersion,
    this.attrs = const <String, Object?>{},
  });

  final String shopId;
  final String deviceId;
  final String deviceRole;
  final String kind;
  final TelemetryLevel level;
  final DateTime occurredAt;
  final String? message;
  final String? scenarioId;
  final String? appVersion;
  final Map<String, Object?> attrs;

  Map<String, Object?> toRow() => <String, Object?>{
    'shop_id': shopId,
    'device_id': deviceId,
    'device_role': deviceRole,
    'scenario_id': scenarioId,
    'app_version': appVersion,
    'level': level.name,
    'kind': kind,
    'message': message,
    'attrs': attrs,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
  };
}

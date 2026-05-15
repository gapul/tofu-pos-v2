import '../enums/device_role.dart';
import '../enums/transport_mode.dart';
import '../value_objects/feature_flags.dart';
import '../value_objects/shop_id.dart';

/// 端末ローカル設定の永続化（仕様書 §3, §4, §11）。
///
/// 保存対象: 店舗ID、役割、機能フラグ、現在の通信モード、
/// 整理券プールの状態（数値部分は別Repositoryで管理）。
abstract interface class SettingsRepository {
  Future<ShopId?> getShopId();
  Future<void> setShopId(ShopId shopId);

  /// 店舗ID をクリア（ログアウト）。
  /// ローカル DB / 整理券プール / 精算ログは破棄しない。
  Future<void> clearShopId();

  Future<DeviceRole?> getDeviceRole();
  Future<void> setDeviceRole(DeviceRole role);
  Future<void> clearDeviceRole();

  Future<FeatureFlags> getFeatureFlags();
  Future<void> setFeatureFlags(FeatureFlags flags);
  Stream<FeatureFlags> watchFeatureFlags();

  Future<TransportMode> getTransportMode();
  Future<void> setTransportMode(TransportMode mode);
  Stream<TransportMode> watchTransportMode();

  /// LAN Transport の高緊急 send タイムアウト（仕様書 §7.2、既定: 5秒）。
  Future<Duration> getLanSendTimeout();
  Future<void> setLanSendTimeout(Duration value);

  /// BLE Transport の高緊急 send タイムアウト（既定: 10秒）。
  Future<Duration> getBleSendTimeout();
  Future<void> setBleSendTimeout(Duration value);

  /// 端末の安定IDを返す。未設定なら新規生成して永続化する。
  /// テレメトリでの端末識別に用いる（個人情報ではなく不可視のランダム値）。
  Future<String> getOrCreateDeviceId();
}

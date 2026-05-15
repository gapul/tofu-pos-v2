import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../domain/enums/device_role.dart';
import '../../domain/enums/transport_mode.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/value_objects/feature_flags.dart';
import '../../domain/value_objects/shop_id.dart';

/// SharedPreferences ベースの SettingsRepository（仕様書 §3, §4）。
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _kShopId = 'shopId';
  static const String _kDeviceRole = 'deviceRole';
  static const String _kTransportMode = 'transportMode';
  static const String _kFlagStock = 'flag.stockManagement';
  static const String _kFlagCash = 'flag.cashManagement';
  static const String _kFlagAttr = 'flag.customerAttributes';
  static const String _kFlagKitchen = 'flag.kitchenLink';
  static const String _kFlagCalling = 'flag.callingLink';
  static const String _kLanSendTimeoutMs = 'lanSendTimeoutMs';
  static const String _kBleSendTimeoutMs = 'bleSendTimeoutMs';
  static const String _kDeviceId = 'deviceId';

  static const Duration _defaultLanTimeout = Duration(seconds: 5);
  static const Duration _defaultBleTimeout = Duration(seconds: 10);

  final StreamController<FeatureFlags> _flagsController =
      StreamController<FeatureFlags>.broadcast();
  final StreamController<TransportMode> _modeController =
      StreamController<TransportMode>.broadcast();

  @override
  Future<ShopId?> getShopId() async {
    final String? raw = _prefs.getString(_kShopId);
    return raw == null ? null : ShopId(raw);
  }

  @override
  Future<void> setShopId(ShopId shopId) async {
    await _prefs.setString(_kShopId, shopId.value);
  }

  @override
  Future<DeviceRole?> getDeviceRole() async {
    final String? raw = _prefs.getString(_kDeviceRole);
    if (raw == null) {
      return null;
    }
    return DeviceRole.values.byName(raw);
  }

  @override
  Future<void> setDeviceRole(DeviceRole role) async {
    await _prefs.setString(_kDeviceRole, role.name);
  }

  @override
  Future<void> clearDeviceRole() async {
    await _prefs.remove(_kDeviceRole);
  }

  @override
  Future<FeatureFlags> getFeatureFlags() async {
    // 既定: 全フラグ ON（フル機能でセットアップが即完了する状態）
    return FeatureFlags(
      stockManagement: _prefs.getBool(_kFlagStock) ?? true,
      cashManagement: _prefs.getBool(_kFlagCash) ?? true,
      customerAttributes: _prefs.getBool(_kFlagAttr) ?? true,
      kitchenLink: _prefs.getBool(_kFlagKitchen) ?? true,
      callingLink: _prefs.getBool(_kFlagCalling) ?? true,
    );
  }

  @override
  Future<void> setFeatureFlags(FeatureFlags flags) async {
    await Future.wait(<Future<void>>[
      _prefs.setBool(_kFlagStock, flags.stockManagement),
      _prefs.setBool(_kFlagCash, flags.cashManagement),
      _prefs.setBool(_kFlagAttr, flags.customerAttributes),
      _prefs.setBool(_kFlagKitchen, flags.kitchenLink),
      _prefs.setBool(_kFlagCalling, flags.callingLink),
    ]);
    _flagsController.add(flags);
  }

  @override
  Stream<FeatureFlags> watchFeatureFlags() async* {
    yield await getFeatureFlags();
    yield* _flagsController.stream;
  }

  @override
  Future<TransportMode> getTransportMode() async {
    final String? raw = _prefs.getString(_kTransportMode);
    if (raw == null) {
      // online mode は `device_events` テーブルが必要。
      // `supabase/migrations/0004_device_events.sql` を本番に適用してから運用。
      return TransportMode.online;
    }
    return TransportMode.values.byName(raw);
  }

  @override
  Future<void> setTransportMode(TransportMode mode) async {
    await _prefs.setString(_kTransportMode, mode.name);
    _modeController.add(mode);
  }

  @override
  Stream<TransportMode> watchTransportMode() async* {
    yield await getTransportMode();
    yield* _modeController.stream;
  }

  @override
  Future<Duration> getLanSendTimeout() async {
    final int? ms = _prefs.getInt(_kLanSendTimeoutMs);
    return ms == null ? _defaultLanTimeout : Duration(milliseconds: ms);
  }

  @override
  Future<void> setLanSendTimeout(Duration value) async {
    await _prefs.setInt(_kLanSendTimeoutMs, value.inMilliseconds);
  }

  @override
  Future<Duration> getBleSendTimeout() async {
    final int? ms = _prefs.getInt(_kBleSendTimeoutMs);
    return ms == null ? _defaultBleTimeout : Duration(milliseconds: ms);
  }

  @override
  Future<void> setBleSendTimeout(Duration value) async {
    await _prefs.setInt(_kBleSendTimeoutMs, value.inMilliseconds);
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    final String? existing = _prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final String fresh = const Uuid().v4();
    await _prefs.setString(_kDeviceId, fresh);
    return fresh;
  }

  /// プロセス終了 / ProviderContainer 破棄時に呼ぶ。
  /// テストで多数の container を作る場合のリーク防止用途が主。
  /// 本番では App 単一インスタンスなので影響は軽微。
  Future<void> dispose() async {
    await _flagsController.close();
    await _modeController.close();
  }
}

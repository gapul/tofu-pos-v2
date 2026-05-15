import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/enums/device_role.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../../../../providers/database_providers.dart';
import '../../../../providers/repository_providers.dart';
import '../../../../providers/role_router_providers.dart';
import '../../../../providers/sync_providers.dart';
import '../../../../providers/telemetry_providers.dart';
import '../../../../providers/usecase_providers.dart';

/// 初期設定の現在状態（仕様書 §3）。
///
/// `loading` フィールドは持たない。ロード中かどうかは
/// [setupNotifierProvider] の `AsyncValue` で表現する。
class SetupState {
  const SetupState({
    required this.shopId,
    required this.role,
  });

  static const SetupState empty = SetupState(shopId: null, role: null);

  final ShopId? shopId;
  final DeviceRole? role;

  bool get isComplete => shopId != null && role != null;

  SetupState copyWith({
    ShopId? shopId,
    DeviceRole? role,
    bool clearShop = false,
    bool clearRole = false,
  }) {
    return SetupState(
      shopId: clearShop ? null : (shopId ?? this.shopId),
      role: clearRole ? null : (role ?? this.role),
    );
  }
}

/// 初期設定の読み込み・更新を担う AsyncNotifier。
///
/// `build()` で永続層から読み込み、`saveShopId` / `saveRole` で
/// state を `AsyncData` として更新する。
class SetupNotifier extends AsyncNotifier<SetupState> {
  late final SettingsRepository _repo = ref.read(settingsRepositoryProvider);

  @override
  Future<SetupState> build() async {
    final ShopId? shop = await _repo.getShopId();
    final DeviceRole? role = await _repo.getDeviceRole();
    return SetupState(shopId: shop, role: role);
  }

  /// 起動後の shop_id / role 変更で各種 provider を再初期化する。
  /// telemetry / transport / sync / presence / RoleStarter を作り直し、
  /// 新しい設定値でサーバに接続し直す。
  Future<void> _reconfigureAfterSetupChange() async {
    ref.invalidate(telemetryInitProvider);
    ref.invalidate(transportProvider);
    ref.invalidate(supabaseRealtimeListenerProvider);
    ref.invalidate(peerPresenceServiceProvider);
    try {
      await ref.read(telemetryInitProvider.future);
    } catch (_) {/* telemetry 失敗は致命でないので継続 */}
    try {
      await ref.read(roleStarterProvider).start();
    } catch (e, st) {
      AppLogger.w(
        'SetupNotifier: roleStarter restart failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> saveShopId(ShopId shopId) async {
    // 別店舗の shopId に切り替わる場合は前店舗のローカルデータをパージ
    // （仕様: 異なる shop_id への上書きは前店舗の注文・キッチン/呼出・会計
    //  ・操作ログ・整理券プールを全削除する。同一 shop_id 再ログインでは保持）。
    final ShopId? before = await _repo.getShopId();
    final bool shopChanged = before != null && before.value != shopId.value;

    // 初回 shop_id 設定時、旧スキーマ（プレフィクスなし）の店舗依存キーを
    // 新スキーマ（`key:<shopId>`）にリネーム移行する。複数 shop_id 切替で
    // 番号衝突や日次リセット誤判定を起こさないため、確実に 1 回だけ行う。
    if (before == null) {
      await _migrateLegacyShopScopedKeys(shopId.value);
    }

    await _repo.setShopId(shopId);

    if (shopChanged) {
      try {
        await ref.read(appDatabaseProvider).purgeShopScopedData();
        await ref.read(ticketNumberPoolRepositoryProvider).reset();
      } catch (e, st) {
        AppLogger.e(
          'SetupNotifier: purge shop-scoped data failed on shop change',
          error: e,
          stackTrace: st,
        );
      }
      // PeerPresence は接続中の shopId をコンストラクタで握っているので
      // shopId 変更時は invalidate して作り直す。
      ref.invalidate(peerPresenceServiceProvider);
    }

    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(shopId: shopId));
    await _reconfigureAfterSetupChange();
  }

  /// 旧スキーマで保存された店舗依存キーを `<key>:<shopId>` 形式へ移行する。
  /// 既存ユーザの初回起動（または shop_id 未設定状態からのログイン）でのみ実行。
  /// 失敗してもログだけ残して続行（リネーム失敗 = 一部データ取り溢しになるが
  /// 整理券プールの番号衝突よりは小さい問題）。
  Future<void> _migrateLegacyShopScopedKeys(String shopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const List<String> legacyKeys = <String>[
        'ticketPool',
        'ticketPool.pendingReleases',
        'lastResetDate',
        'sync.lastStartedToken',
        'sync.lastCompletedToken',
      ];
      for (final String key in legacyKeys) {
        final String? value = prefs.getString(key);
        if (value == null) continue;
        final String scoped = '$key:$shopId';
        if (prefs.getString(scoped) != null) {
          // 既に新スキーマがあるなら旧を捨てる（同居させない）。
          await prefs.remove(key);
          continue;
        }
        await prefs.setString(scoped, value);
        await prefs.remove(key);
      }
    } catch (e, st) {
      AppLogger.w(
        'SetupNotifier: legacy shop-scoped key migration failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> saveRole(DeviceRole role) async {
    await _repo.setDeviceRole(role);
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(role: role));
    await _reconfigureAfterSetupChange();
  }

  Future<void> clearRole() async {
    await _repo.clearDeviceRole();
    ref.invalidate(peerPresenceServiceProvider);
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(clearRole: true));
  }

  /// ログアウト: 店舗ID をクリアし state を shopId=null にする。
  /// 役割や機能フラグ等は保持される。
  Future<void> clearShop() async {
    await _repo.clearShopId();
    ref.invalidate(peerPresenceServiceProvider);
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(clearShop: true));
  }
}

final AsyncNotifierProvider<SetupNotifier, SetupState> setupNotifierProvider =
    AsyncNotifierProvider<SetupNotifier, SetupState>(SetupNotifier.new);

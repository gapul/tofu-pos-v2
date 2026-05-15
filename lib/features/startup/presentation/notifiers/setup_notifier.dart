import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/enums/device_role.dart';
import '../../../../domain/repositories/settings_repository.dart';
import '../../../../domain/value_objects/shop_id.dart';
import '../../../../providers/repository_providers.dart';

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

  Future<void> saveShopId(ShopId shopId) async {
    await _repo.setShopId(shopId);
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(shopId: shopId));
  }

  Future<void> saveRole(DeviceRole role) async {
    await _repo.setDeviceRole(role);
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(role: role));
  }

  Future<void> clearRole() async {
    await _repo.clearDeviceRole();
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(clearRole: true));
  }

  /// ログアウト: 店舗ID をクリアし state を shopId=null にする。
  /// 役割や機能フラグ等は保持される。
  Future<void> clearShop() async {
    await _repo.clearShopId();
    final SetupState current = state.value ?? SetupState.empty;
    state = AsyncData<SetupState>(current.copyWith(clearShop: true));
  }
}

final AsyncNotifierProvider<SetupNotifier, SetupState> setupNotifierProvider =
    AsyncNotifierProvider<SetupNotifier, SetupState>(SetupNotifier.new);

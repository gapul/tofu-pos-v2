import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/repositories/settings_repository.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/features/startup/presentation/notifiers/setup_notifier.dart';
import 'package:tofu_pos/providers/repository_providers.dart';

/// セットアップフローのテストに必要な分だけ実装した Fake。
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({ShopId? initialShopId, DeviceRole? initialRole})
    : _shopId = initialShopId,
      _role = initialRole;

  ShopId? _shopId;
  DeviceRole? _role;

  @override
  Future<ShopId?> getShopId() async => _shopId;

  @override
  Future<void> setShopId(ShopId shopId) async {
    _shopId = shopId;
  }

  @override
  Future<void> clearShopId() async {
    _shopId = null;
  }

  @override
  Future<DeviceRole?> getDeviceRole() async => _role;

  @override
  Future<void> setDeviceRole(DeviceRole role) async {
    _role = role;
  }

  @override
  Future<void> clearDeviceRole() async {
    _role = null;
  }

  // 以下はテストで使わないので未実装でよい。
  @override
  Future<FeatureFlags> getFeatureFlags() => throw UnimplementedError();

  @override
  Future<void> setFeatureFlags(FeatureFlags flags) =>
      throw UnimplementedError();

  @override
  Stream<FeatureFlags> watchFeatureFlags() => throw UnimplementedError();

  @override
  Future<TransportMode> getTransportMode() => throw UnimplementedError();

  @override
  Future<void> setTransportMode(TransportMode mode) =>
      throw UnimplementedError();

  @override
  Stream<TransportMode> watchTransportMode() => throw UnimplementedError();

  @override
  Future<Duration> getLanSendTimeout() => throw UnimplementedError();

  @override
  Future<void> setLanSendTimeout(Duration value) => throw UnimplementedError();

  @override
  Future<Duration> getBleSendTimeout() => throw UnimplementedError();

  @override
  Future<void> setBleSendTimeout(Duration value) => throw UnimplementedError();

  @override
  Future<String> getOrCreateDeviceId() => throw UnimplementedError();

  @override
  Future<String?> getUserName() async => null;

  @override
  Future<void> setUserName(String? value) async {}
}

ProviderContainer _makeContainer(_FakeSettingsRepository repo) {
  return ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('SetupNotifier (AsyncNotifier)', () {
    test('build 直後は AsyncLoading', () {
      final ProviderContainer container = _makeContainer(
        _FakeSettingsRepository(),
      );
      addTearDown(container.dispose);

      final AsyncValue<SetupState> initial = container.read(
        setupNotifierProvider,
      );
      expect(initial.isLoading, isTrue);
      expect(initial.hasValue, isFalse);
    });

    test('ロード完了後、未設定なら shopId/role はともに null', () async {
      final ProviderContainer container = _makeContainer(
        _FakeSettingsRepository(),
      );
      addTearDown(container.dispose);

      final SetupState s = await container.read(
        setupNotifierProvider.future,
      );
      expect(s.shopId, isNull);
      expect(s.role, isNull);
      expect(s.isComplete, isFalse);
    });

    test('既存設定が両方ある場合は復元され isComplete=true', () async {
      final ProviderContainer container = _makeContainer(
        _FakeSettingsRepository(
          initialShopId: ShopId('yakisoba_A'),
          initialRole: DeviceRole.register,
        ),
      );
      addTearDown(container.dispose);

      final SetupState s = await container.read(
        setupNotifierProvider.future,
      );
      expect(s.shopId?.value, 'yakisoba_A');
      expect(s.role, DeviceRole.register);
      expect(s.isComplete, isTrue);
    });

    test('shopId のみが既存の場合、role は null のまま isComplete=false', () async {
      final ProviderContainer container = _makeContainer(
        _FakeSettingsRepository(initialShopId: ShopId('only_shop')),
      );
      addTearDown(container.dispose);

      final SetupState s = await container.read(
        setupNotifierProvider.future,
      );
      expect(s.shopId?.value, 'only_shop');
      expect(s.role, isNull);
      expect(s.isComplete, isFalse);
    });

    test('saveShopId は state と repository の両方に反映される', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository();
      final ProviderContainer container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      await container
          .read(setupNotifierProvider.notifier)
          .saveShopId(ShopId('takoyaki_B'));

      final SetupState s = container.read(setupNotifierProvider).requireValue;
      expect(s.shopId?.value, 'takoyaki_B');
      expect((await repo.getShopId())?.value, 'takoyaki_B');
    });

    test('saveRole は state と repository の両方に反映される', () async {
      final _FakeSettingsRepository repo = _FakeSettingsRepository(
        initialShopId: ShopId('yakisoba_A'),
      );
      final ProviderContainer container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      await container
          .read(setupNotifierProvider.notifier)
          .saveRole(DeviceRole.kitchen);

      final SetupState s = container.read(setupNotifierProvider).requireValue;
      expect(s.role, DeviceRole.kitchen);
      expect(s.shopId?.value, 'yakisoba_A');
      expect(s.isComplete, isTrue);
      expect(await repo.getDeviceRole(), DeviceRole.kitchen);
    });

    test('saveShopId → saveRole の連続で isComplete に遷移', () async {
      final ProviderContainer container = _makeContainer(
        _FakeSettingsRepository(),
      );
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      final SetupNotifier n = container.read(setupNotifierProvider.notifier);

      await n.saveShopId(ShopId('yakisoba_A'));
      expect(
        container.read(setupNotifierProvider).requireValue.isComplete,
        isFalse,
      );

      await n.saveRole(DeviceRole.calling);
      expect(
        container.read(setupNotifierProvider).requireValue.isComplete,
        isTrue,
      );
    });
  });

  group('SetupState', () {
    test('SetupState.empty は shopId/role が null', () {
      const SetupState s = SetupState.empty;
      expect(s.shopId, isNull);
      expect(s.role, isNull);
      expect(s.isComplete, isFalse);
    });

    test('copyWith.clearShop で shopId が null になる', () {
      final SetupState s = SetupState(
        shopId: ShopId('x'),
        role: DeviceRole.register,
      );
      final SetupState cleared = s.copyWith(clearShop: true);

      expect(cleared.shopId, isNull);
      expect(cleared.role, DeviceRole.register);
    });

    test('copyWith.clearRole で role が null になる', () {
      final SetupState s = SetupState(
        shopId: ShopId('x'),
        role: DeviceRole.register,
      );
      final SetupState cleared = s.copyWith(clearRole: true);

      expect(cleared.role, isNull);
      expect(cleared.shopId?.value, 'x');
    });
  });
}

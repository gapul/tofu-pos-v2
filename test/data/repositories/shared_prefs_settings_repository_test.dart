import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_settings_repository.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';

void main() {
  late SharedPreferences prefs;
  late SharedPrefsSettingsRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsSettingsRepository(prefs);
  });

  test('shopId round-trip', () async {
    expect(await repo.getShopId(), isNull);
    await repo.setShopId(ShopId('yakisoba_A'));
    final ShopId? loaded = await repo.getShopId();
    expect(loaded?.value, 'yakisoba_A');
  });

  test('deviceRole round-trip', () async {
    expect(await repo.getDeviceRole(), isNull);
    await repo.setDeviceRole(DeviceRole.kitchen);
    expect(await repo.getDeviceRole(), DeviceRole.kitchen);
  });

  test('feature flags default all on (フル機能既定)', () async {
    expect(await repo.getFeatureFlags(), FeatureFlags.allOn);
  });

  test('feature flags round-trip', () async {
    const FeatureFlags flags = FeatureFlags.allOff;
    await repo.setFeatureFlags(flags);
    expect(await repo.getFeatureFlags(), flags);
  });

  test('transportMode default is online', () async {
    expect(await repo.getTransportMode(), TransportMode.online);
  });

  test('transportMode round-trip', () async {
    await repo.setTransportMode(TransportMode.localLan);
    expect(await repo.getTransportMode(), TransportMode.localLan);
  });
}

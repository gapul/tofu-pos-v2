import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/datasources/local/database.dart';
import 'package:tofu_pos/domain/enums/device_role.dart';
import 'package:tofu_pos/domain/enums/transport_mode.dart';
import 'package:tofu_pos/domain/repositories/settings_repository.dart';
import 'package:tofu_pos/domain/repositories/ticket_number_pool_repository.dart';
import 'package:tofu_pos/domain/value_objects/feature_flags.dart';
import 'package:tofu_pos/domain/value_objects/shop_id.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number_pool.dart';
import 'package:tofu_pos/features/startup/presentation/notifiers/setup_notifier.dart';
import 'package:tofu_pos/providers/database_providers.dart';
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

/// テスト用のミニマル ticket pool repository。reset 回数を観測するだけ。
class _FakeTicketPoolRepository implements TicketNumberPoolRepository {
  int resetCount = 0;

  @override
  Future<void> reset() async {
    resetCount += 1;
  }

  @override
  Future<TicketNumberPool> load() async => TicketNumberPool.empty();

  @override
  Future<void> save(TicketNumberPool pool) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

ProviderContainer _makeContainer(
  _FakeSettingsRepository repo, {
  AppDatabase? db,
  _FakeTicketPoolRepository? ticketPool,
}) {
  return ProviderContainer(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repo),
      if (db != null) appDatabaseProvider.overrideWithValue(db),
      if (ticketPool != null)
        ticketNumberPoolRepositoryProvider.overrideWithValue(ticketPool),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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

    test('ログアウト → 別 shop_id で再ログインすると purge と pool reset が走る', () async {
      // 前提: 既にログイン中だったが clearShop でログアウトした状態を再現する。
      // 旧実装は repo.getShopId()==null との比較だったので shopChanged=false に
      // なって purge がスキップされていた。lastKnownShopId 経由で検出する。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lastKnownShopId': 'shopA',
      });

      final _FakeSettingsRepository repo = _FakeSettingsRepository();
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // 前店舗のデータを 1 行ずつ入れて、purge で消えることを確認する。
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'p1',
              name: 'たこ焼き',
              priceYen: 500,
            ),
          );
      await db
          .into(db.callingOrders)
          .insert(
            CallingOrdersCompanion.insert(
              orderId: const Value(1),
              ticketNumber: 1,
              status: 'waiting',
              receivedAt: DateTime(2026, 5, 8),
            ),
          );

      final _FakeTicketPoolRepository pool = _FakeTicketPoolRepository();
      final ProviderContainer container = _makeContainer(
        repo,
        db: db,
        ticketPool: pool,
      );
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      await container
          .read(setupNotifierProvider.notifier)
          .saveShopId(ShopId('shopB'));

      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.callingOrders).get(), isEmpty);
      expect(pool.resetCount, 1);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastKnownShopId'), 'shopB');
    });

    test('同一 shop_id で再ログインしたら purge は走らない', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'lastKnownShopId': 'shopA',
      });

      final _FakeSettingsRepository repo = _FakeSettingsRepository();
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'p1',
              name: 'たこ焼き',
              priceYen: 500,
            ),
          );

      final _FakeTicketPoolRepository pool = _FakeTicketPoolRepository();
      final ProviderContainer container = _makeContainer(
        repo,
        db: db,
        ticketPool: pool,
      );
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      await container
          .read(setupNotifierProvider.notifier)
          .saveShopId(ShopId('shopA'));

      // 同一 shop_id への再ログインではローカルデータは保持する。
      expect((await db.select(db.products).get()).length, 1);
      expect(pool.resetCount, 0);
    });

    test('clearShop は lastKnownShopId を保持する（次回再ログインで検出するため）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final _FakeSettingsRepository repo = _FakeSettingsRepository();
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = _makeContainer(
        repo,
        db: db,
        ticketPool: _FakeTicketPoolRepository(),
      );
      addTearDown(container.dispose);

      await container.read(setupNotifierProvider.future);
      final SetupNotifier n = container.read(setupNotifierProvider.notifier);

      await n.saveShopId(ShopId('shopA'));
      await n.clearShop();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('lastKnownShopId'), 'shopA');
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

import 'dart:async';

import '../../domain/entities/cash_drawer.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/cash_drawer_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../logging/app_logger.dart';
import 'supabase_cash_drawer_sync_client.dart';
import 'supabase_product_sync_client.dart';

/// 店舗 ID 確定後に商品マスタ / 釣銭スナップショットを Supabase に
/// アップロードし続けるオートランナー。
///
/// トリガ:
///  1. リポジトリ watch() の変更検知 (デバウンス付き)
///  2. periodic (既定 5 分) で再送 (ネット回復・直し漏れに対する保険)
///  3. start() 直後に即 1 回送信
///
/// 失敗時はログのみで吐いてユーザー通知はしない (master 系は低緊急)。
class MasterDataCloudSync {
  MasterDataCloudSync({
    required ProductRepository productRepository,
    required CashDrawerRepository cashDrawerRepository,
    required SupabaseProductSyncClient productClient,
    required SupabaseCashDrawerSyncClient cashClient,
    required String shopId,
    Duration debounce = const Duration(milliseconds: 800),
    Duration periodicInterval = const Duration(minutes: 5),
  }) : _productRepo = productRepository,
       _cashRepo = cashDrawerRepository,
       _productClient = productClient,
       _cashClient = cashClient,
       _shopId = shopId,
       _debounce = debounce,
       _periodicInterval = periodicInterval;

  final ProductRepository _productRepo;
  final CashDrawerRepository _cashRepo;
  final SupabaseProductSyncClient _productClient;
  final SupabaseCashDrawerSyncClient _cashClient;
  final String _shopId;
  final Duration _debounce;
  final Duration _periodicInterval;

  StreamSubscription<List<Product>>? _productSub;
  StreamSubscription<CashDrawer>? _cashSub;
  Timer? _productDebounce;
  Timer? _cashDebounce;
  Timer? _periodicTimer;
  bool _started = false;

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _productSub = _productRepo
        .watchAll(includeDeleted: true)
        .listen((_) => _scheduleProductPush());
    _cashSub = _cashRepo.watch().listen((_) => _scheduleCashPush());
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      unawaited(_pushProductsNow());
      unawaited(_pushCashNow());
    });
    _started = true;
    AppLogger.i('MasterDataCloudSync started (shop=$_shopId)');
    // 起動直後に 1 回送る (新しい端末が立ち上がった時点で最新を上げる)
    unawaited(_pushProductsNow());
    unawaited(_pushCashNow());
  }

  Future<void> stop() async {
    _started = false;
    _productDebounce?.cancel();
    _productDebounce = null;
    _cashDebounce?.cancel();
    _cashDebounce = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _productSub?.cancel();
    _productSub = null;
    await _cashSub?.cancel();
    _cashSub = null;
  }

  void _scheduleProductPush() {
    _productDebounce?.cancel();
    _productDebounce = Timer(_debounce, () => unawaited(_pushProductsNow()));
  }

  void _scheduleCashPush() {
    _cashDebounce?.cancel();
    _cashDebounce = Timer(_debounce, () => unawaited(_pushCashNow()));
  }

  Future<void> _pushProductsNow() async {
    try {
      final List<Product> products = await _productRepo.findAll(
        includeDeleted: true,
      );
      if (products.isEmpty) return;
      await _productClient.push(products, shopId: _shopId);
    } catch (e, st) {
      AppLogger.w(
        'MasterDataCloudSync: product push failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _pushCashNow() async {
    try {
      final CashDrawer drawer = await _cashRepo.get();
      await _cashClient.push(drawer, shopId: _shopId);
    } catch (e, st) {
      AppLogger.w(
        'MasterDataCloudSync: cash push failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

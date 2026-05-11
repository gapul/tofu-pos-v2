import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/repositories/product_repository.dart';
import 'product_master_broadcast_usecase.dart';

/// 商品マスタの自動ブロードキャスト（仕様書 §6.5）。
///
/// 2 つのトリガーで [ProductMasterBroadcastUseCase] を呼ぶ:
///   1. ProductRepository.watchAll() の変更検知（編集後ただちに）
///   2. 周期再送（既定 5 分間隔、接続遅れに備える）
///
/// 連続編集に対しては [_debounce] で短時間まとめて1回送信。
class ProductMasterAutoBroadcaster {
  ProductMasterAutoBroadcaster({
    required ProductRepository productRepository,
    required ProductMasterBroadcastUseCase broadcast,
    Duration debounce = const Duration(milliseconds: 500),
    Duration periodicInterval = const Duration(minutes: 5),
  }) : _productRepo = productRepository,
       _broadcast = broadcast,
       _debounce = debounce,
       _periodicInterval = periodicInterval;

  final ProductRepository _productRepo;
  final ProductMasterBroadcastUseCase _broadcast;
  final Duration _debounce;
  final Duration _periodicInterval;

  StreamSubscription<List<Product>>? _watchSub;
  Timer? _debounceTimer;
  Timer? _periodicTimer;
  bool _started = false;

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _watchSub = _productRepo.watchAll(includeDeleted: true).listen((_) {
      _scheduleDebounced();
    });
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      unawaited(_trigger('periodic'));
    });
    _started = true;
    AppLogger.i('ProductMasterAutoBroadcaster started');
  }

  Future<void> stop() async {
    _started = false;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    await _watchSub?.cancel();
    _watchSub = null;
  }

  void _scheduleDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _trigger('change'));
  }

  Future<void> _trigger(String reason) async {
    try {
      await _broadcast.execute();
      AppLogger.d('ProductMasterAutoBroadcaster: triggered ($reason)');
    } catch (e, st) {
      // ProductMasterBroadcastUseCase は低緊急で例外を握り込むはずだが
      // 念のため二重ガード
      AppLogger.w(
        'ProductMasterAutoBroadcaster: trigger failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

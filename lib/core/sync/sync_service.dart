import 'dart:async';

import '../../domain/entities/order.dart';
import '../../domain/enums/sync_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../connectivity/connectivity_monitor.dart';
import '../connectivity/connectivity_status.dart';
import 'cloud_sync_client.dart';

/// 未同期注文をクラウドに送る同期サービス（仕様書 §8.1 / §8.2）。
///
/// トリガー:
///  - アプリ起動時の `runOnce()`
///  - オンライン復帰イベント
///  - 周期的な再試行
///
/// **長期失敗の通知**（§8.2 「1時間継続したら通知」）は、
/// 呼び出し側（Notifier 等）が `lastFailureSince` を監視して実装する。
class SyncResult {
  const SyncResult({required this.successCount, required this.failureCount});
  final int successCount;
  final int failureCount;

  bool get hadFailure => failureCount > 0;
}

class SyncService {
  SyncService({
    required OrderRepository orderRepository,
    required SettingsRepository settingsRepository,
    required ConnectivityMonitor connectivityMonitor,
    required CloudSyncClient client,
    Duration retryInterval = const Duration(minutes: 5),
  })  : _orderRepo = orderRepository,
        _settingsRepo = settingsRepository,
        _connectivity = connectivityMonitor,
        _client = client,
        _retryInterval = retryInterval;

  final OrderRepository _orderRepo;
  final SettingsRepository _settingsRepo;
  final ConnectivityMonitor _connectivity;
  final CloudSyncClient _client;
  final Duration _retryInterval;

  StreamSubscription<ConnectivityStatus>? _connSub;
  Timer? _retryTimer;
  DateTime? _firstFailureAt;
  bool _running = false;

  /// オンライン復帰と周期再試行を起動する。
  void start() {
    _connSub ??= _connectivity.watch().listen((ConnectivityStatus status) {
      if (status == ConnectivityStatus.online) {
        unawaited(runOnce());
      }
    });
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(runOnce());
    });
  }

  Future<void> stop() async {
    await _connSub?.cancel();
    _connSub = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// 直近の失敗継続開始時刻。null なら直近は成功状態。
  /// §8.2 の「1時間継続で通知」判定に使う。
  DateTime? get lastFailureSince => _firstFailureAt;

  /// 1回だけ同期を試みる。並行起動はガード。
  Future<SyncResult> runOnce() async {
    if (_running) {
      return const SyncResult(successCount: 0, failureCount: 0);
    }
    _running = true;
    try {
      if (_connectivity.current != ConnectivityStatus.online) {
        return const SyncResult(successCount: 0, failureCount: 0);
      }
      final shopId = await _settingsRepo.getShopId();
      if (shopId == null) {
        return const SyncResult(successCount: 0, failureCount: 0);
      }
      final List<Order> unsynced = await _orderRepo.findUnsynced();
      int success = 0;
      int failure = 0;
      for (final Order order in unsynced) {
        try {
          await _client.push(order, shopId: shopId.value);
          await _orderRepo.updateSyncStatus(order.id, SyncStatus.synced);
          success++;
        } catch (_) {
          failure++;
        }
      }
      if (failure == 0) {
        _firstFailureAt = null;
      } else {
        _firstFailureAt ??= DateTime.now();
      }
      return SyncResult(successCount: success, failureCount: failure);
    } finally {
      _running = false;
    }
  }
}

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/order.dart';
import '../../domain/enums/sync_status.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../connectivity/connectivity_monitor.dart';
import '../connectivity/connectivity_status.dart';
import '../logging/app_logger.dart';
import '../telemetry/telemetry.dart';
import '../time/clock.dart';
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
    SharedPreferences? prefs,
    Clock clock = const SystemClock(),
    Duration retryInterval = const Duration(minutes: 5),
    Duration runOnceTimeout = const Duration(seconds: 30),
  }) : _orderRepo = orderRepository,
       _settingsRepo = settingsRepository,
       _connectivity = connectivityMonitor,
       _client = client,
       _prefs = prefs,
       _clock = clock,
       _retryInterval = retryInterval,
       _runOnceTimeout = runOnceTimeout;

  final OrderRepository _orderRepo;
  final SettingsRepository _settingsRepo;
  final ConnectivityMonitor _connectivity;
  final CloudSyncClient _client;
  final SharedPreferences? _prefs;
  final Clock _clock;
  final Duration _retryInterval;
  final Duration _runOnceTimeout;

  /// 「最後に開始した run のトークン」を永続化するキー。
  /// 起動時に [_kLastCompletedToken] と比較し、不一致なら前回クラッシュとみなす。
  static const String _kLastStartedToken = 'sync.lastStartedToken';

  /// 「最後に正常終了した run のトークン」を永続化するキー。
  static const String _kLastCompletedToken = 'sync.lastCompletedToken';

  /// 起動直後に 1 度だけ「前回クラッシュ」チェックを行うためのフラグ。
  bool _crashCheckPerformed = false;

  StreamSubscription<ConnectivityStatus>? _connSub;
  Timer? _retryTimer;
  DateTime? _firstFailureAt;
  bool _running = false;

  /// 現在実行中の runOnce の所有トークン。
  /// タイムアウトで強制リセットされた後、古い runOnce が完了しても
  /// `_running` を勝手にクリアしないようにするための識別子。
  Object? _runToken;

  /// オンライン復帰と周期再試行を起動する。
  void start() {
    _connSub ??= _connectivity.watch().listen((status) {
      if (status == ConnectivityStatus.online) {
        unawaited(_runOnceGuarded());
      }
    });
    _retryTimer ??= Timer.periodic(_retryInterval, (_) {
      unawaited(_runOnceGuarded());
    });
  }

  /// fire-and-forget 用のラッパー。
  /// タイムアウトと例外を Telemetry に流して、再試行チェーンを止めない。
  Future<void> _runOnceGuarded() async {
    try {
      await runOnce().timeout(_runOnceTimeout);
    } on TimeoutException catch (e, st) {
      AppLogger.w(
        'Sync runOnce timed out after ${_runOnceTimeout.inSeconds}s',
        error: e,
        stackTrace: st,
      );
      Telemetry.instance.error(
        'sync.runOnce.timeout',
        message: 'runOnce timed out',
        error: e,
        stackTrace: st,
        attrs: <String, Object?>{
          'timeout_seconds': _runOnceTimeout.inSeconds,
        },
      );
      // 元の runOnce はバックグラウンドで生きているが、_runToken を
      // 切り替えて「孤児」化することで、後続の runOnce を即時許可する。
      // 古い runOnce の finally は token 比較に失敗して _running を
      // 触らないので、新しい run の進行を邪魔しない。
      _running = false;
      _runToken = null;
    } catch (e, st) {
      AppLogger.w('Sync runOnce failed', error: e, stackTrace: st);
      Telemetry.instance.error(
        'sync.runOnce.failed',
        error: e,
        stackTrace: st,
      );
    }
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

  /// テスト用: 強制的に runToken を孤児化する（タイムアウト同等）。
  /// 既存の runOnce ループはこの直後に break して終了する。
  @visibleForTesting
  void debugInvalidateRunToken() {
    _running = false;
    _runToken = null;
  }

  /// 前回プロセスで「開始したが完了しなかった runOnce」がいたかどうかを検出する。
  /// 検出時は WARN ログと telemetry を出し、prefs から started を消す
  /// （次回 runOnce が始まれば新しい started が書かれる）。
  void _detectPreviousCrash() {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) return;
    final String? started = prefs.getString(_kLastStartedToken);
    final String? completed = prefs.getString(_kLastCompletedToken);
    if (started == null) return; // 初回起動 or 前回が綺麗に終わった
    if (started == completed) return; // 前回も正常終了
    AppLogger.w(
      'Sync: previous run did not complete (started=$started, completed=$completed)',
    );
    Telemetry.instance.warn(
      'sync.previous_run.incomplete',
      attrs: <String, Object?>{
        'last_started_token': started,
        'last_completed_token': completed ?? '',
      },
    );
    // started を消すことで「以前のクラッシュを 1 回だけ通知する」を担保。
    unawaited(prefs.remove(_kLastStartedToken));
  }

  Future<void> _writeToken(String key, String value) async {
    try {
      await _prefs?.setString(key, value);
    } catch (e, st) {
      // prefs 書き込み失敗は致命ではない（idempotency_key で重複は吸収される）。
      AppLogger.w('Sync: failed to persist $key', error: e, stackTrace: st);
    }
  }

  /// 1回だけ同期を試みる。並行起動はガード。
  Future<SyncResult> runOnce() async {
    if (_running) {
      return const SyncResult(successCount: 0, failureCount: 0);
    }
    // 初回起動時に「前回開始 != 前回成功」なら前回クラッシュとみなして通知する。
    // 二重発火そのものは idempotency_key で吸収できるが、
    // 「気付けるようにする」のがここの目的（仕様書 §8.2 の長期失敗観測の補助）。
    if (!_crashCheckPerformed) {
      _crashCheckPerformed = true;
      _detectPreviousCrash();
    }
    _running = true;
    final Object myToken = Object();
    _runToken = myToken;
    // 開始トークンを永続化（成功で同じ値が completed に書かれる）。
    final String tokenId = '${_clock.now().microsecondsSinceEpoch}'
        '_${identityHashCode(myToken)}';
    unawaited(_writeToken(_kLastStartedToken, tokenId));
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
        // タイムアウトで token がすり替わった「孤児 runOnce」は、新 run に
        // 道を譲って早期終了する。これにより DB の `updateSyncStatus` や
        // `sync.order.ok` テレメトリの二重発行を防ぐ。
        if (!identical(_runToken, myToken)) {
          AppLogger.event(
            'sync',
            'orphan_break',
            fields: <String, Object?>{'pending': unsynced.length - success - failure},
            level: AppLogLevel.debug,
          );
          break;
        }
        try {
          await _client.push(order, shopId: shopId.value);
          await _orderRepo.updateSyncStatus(order.id, SyncStatus.synced);
          success++;
          Telemetry.instance.event(
            'sync.order.ok',
            attrs: <String, Object?>{'order_id': order.id},
          );
        } catch (e, st) {
          failure++;
          AppLogger.w(
            'Sync failed for order #${order.id}',
            error: e,
            stackTrace: st,
          );
          Telemetry.instance.error(
            'sync.order.failed',
            message: 'Sync failed for order #${order.id}',
            error: e,
            stackTrace: st,
            attrs: <String, Object?>{'order_id': order.id},
          );
        }
      }
      if (failure == 0) {
        if (_firstFailureAt != null) {
          AppLogger.event('sync', 'recovered');
          Telemetry.instance.event('sync.recovered');
        }
        _firstFailureAt = null;
      } else {
        _firstFailureAt ??= _clock.now();
      }
      AppLogger.event(
        'sync',
        'run_once',
        fields: <String, Object?>{'success': success, 'failure': failure},
        level: AppLogLevel.debug,
      );
      Telemetry.instance.event(
        'sync.run',
        attrs: <String, Object?>{'success': success, 'failure': failure},
      );
      // 正常終了（全件失敗でも runOnce 自体は完了）。completed トークンを更新。
      // タイムアウトや例外で抜けた場合は finally でも completed を書かないため、
      // 次回起動で「started != completed」が検出される。
      unawaited(_writeToken(_kLastCompletedToken, tokenId));
      return SyncResult(successCount: success, failureCount: failure);
    } finally {
      // _runOnceGuarded のタイムアウトで token がすり替わっていたら
      // 自分は孤児扱い。後発の runOnce の状態は触らない。
      if (identical(_runToken, myToken)) {
        _running = false;
        _runToken = null;
      }
    }
  }
}

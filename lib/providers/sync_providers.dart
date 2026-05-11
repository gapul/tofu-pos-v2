import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/sync/cloud_sync_client.dart';
import '../core/sync/supabase_cloud_sync_client.dart';
import '../core/sync/supabase_realtime_listener.dart';
import '../core/sync/sync_service.dart';
import '../core/time/clock.dart';
import '../domain/value_objects/shop_id.dart';
import 'connectivity_providers.dart';
import 'repository_providers.dart';

/// CloudSyncClient: Supabase接続情報があれば本実装、無ければ Noop。
final Provider<CloudSyncClient> cloudSyncClientProvider =
    Provider<CloudSyncClient>((ref) {
      if (Env.hasSupabaseCredentials) {
        return SupabaseCloudSyncClient(Supabase.instance.client);
      }
      return NoopCloudSyncClient();
    });

/// SupabaseRealtimeListener: 店舗ID と Supabase 接続情報が揃っていれば購読、無ければ null。
final FutureProvider<SupabaseRealtimeListener?>
supabaseRealtimeListenerProvider = FutureProvider<SupabaseRealtimeListener?>((
  ref,
) async {
  if (!Env.hasSupabaseCredentials) {
    return null;
  }
  final ShopId? shopId = await ref
      .watch(settingsRepositoryProvider)
      .getShopId();
  if (shopId == null) {
    return null;
  }
  final SupabaseRealtimeListener listener = SupabaseRealtimeListener(
    Supabase.instance.client,
    shopId: shopId.value,
  );
  await listener.connect();
  ref.onDispose(listener.dispose);
  return listener;
});

/// 受信した Realtime イベントを Stream で公開。
final StreamProvider<RealtimeOrderLineEvent> realtimeOrderLineEventsProvider =
    StreamProvider<RealtimeOrderLineEvent>((
      ref,
    ) async* {
      final SupabaseRealtimeListener? listener = await ref.watch(
        supabaseRealtimeListenerProvider.future,
      );
      if (listener == null) {
        return;
      }
      yield* listener.events();
    });

/// SyncService: ライフサイクル付き Provider。
/// `ref.read(syncServiceProvider).start()` を起動時に1回呼ぶ。
final Provider<SyncService> syncServiceProvider = Provider<SyncService>((
  ref,
) {
  final SyncService service = SyncService(
    orderRepository: ref.watch(orderRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
    client: ref.watch(cloudSyncClientProvider),
  );
  ref.onDispose(service.stop);
  return service;
});

/// 同期警告のしきい値（仕様書 §8.2 「1時間継続したら通知」）。
const Duration kSyncFailureWarningThreshold = Duration(hours: 1);

/// 同期警告状態。
enum SyncWarningLevel {
  /// 失敗なし、または失敗継続が短時間。
  ok,

  /// 失敗が長時間継続している（既定: 1時間以上）。
  prolongedFailure,
}

/// 同期失敗が長時間続いているかを定期判定する Stream Provider。
///
/// 1分間隔で SyncService.lastFailureSince を確認し、
/// しきい値（デフォルト1時間）を超えたら prolongedFailure を emit する。
final StreamProvider<SyncWarningLevel> syncWarningProvider =
    StreamProvider<SyncWarningLevel>((ref) {
      final SyncService service = ref.watch(syncServiceProvider);
      final Clock clock = ref.watch(clockProvider);
      return Stream<SyncWarningLevel>.periodic(
        const Duration(minutes: 1),
        (_) => _evaluate(service.lastFailureSince, clock),
      ).distinct();
    });

SyncWarningLevel _evaluate(DateTime? since, Clock clock) {
  if (since == null) {
    return SyncWarningLevel.ok;
  }
  if (clock.now().difference(since) >= kSyncFailureWarningThreshold) {
    return SyncWarningLevel.prolongedFailure;
  }
  return SyncWarningLevel.ok;
}

/// 直接呼び出して即時判定する関数（UIの初回チェック用）。
SyncWarningLevel evaluateSyncWarningNow(
  SyncService service, {
  Clock clock = const SystemClock(),
}) => _evaluate(service.lastFailureSince, clock);

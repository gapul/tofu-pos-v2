import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/sync/cloud_sync_client.dart';
import '../core/sync/peer_presence.dart';
import '../core/sync/supabase_cloud_sync_client.dart';
import '../core/sync/supabase_realtime_listener.dart';
import '../core/sync/sync_service.dart';
import '../domain/enums/device_role.dart';
import '../core/time/clock.dart';
import '../domain/value_objects/shop_id.dart';
import 'connectivity_providers.dart';
import 'database_providers.dart';
import 'repository_providers.dart';

/// CloudSyncClient: Supabase接続情報があれば本実装、無ければ Noop。
///
/// `Supabase.instance.client` は `Supabase.initialize` が未完了 / 失敗時に
/// `LateInitializationError` を投げる。起動順の競合で発生し得るため
/// try/catch で Noop に落として、sync.start で全体が落ちないようにする。
final Provider<CloudSyncClient> cloudSyncClientProvider =
    Provider<CloudSyncClient>((ref) {
      if (!Env.hasSupabaseCredentials) {
        return NoopCloudSyncClient();
      }
      try {
        return SupabaseCloudSyncClient(Supabase.instance.client);
      } catch (_) {
        return NoopCloudSyncClient();
      }
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

/// Realtime の **生イベント Stream** を公開する Provider。
///
/// 仕様書 §8.2 / 監査メモ: ここは「Stream を出すだけ」に純化している。
/// フィルタや変換は本 Provider では行わず、別の Provider で合成すること。
/// 例: 整理券一致だけを取りたいなら、本 Provider を watch する派生 Provider を作る。
final StreamProvider<RealtimeOrderLineEvent>
rawRealtimeOrderLineEventsProvider = StreamProvider<RealtimeOrderLineEvent>((
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

/// 旧 API 互換: `realtimeOrderLineEventsProvider` は生イベント Provider と同義。
///
/// 既存の参照（DevConsole 等）を壊さないために残しているエイリアス。
/// 新規コードからは [rawRealtimeOrderLineEventsProvider] を直接参照してよい。
final StreamProvider<RealtimeOrderLineEvent> realtimeOrderLineEventsProvider =
    rawRealtimeOrderLineEventsProvider;

/// PeerPresenceService: 同一店舗内の他端末状況を取得する（仕様 §9.1 ヘッダーバッジ）。
///
/// 店舗ID / 役割 / Supabase 接続情報が揃っていれば接続、欠けていれば null。
/// 起動時に track し、container 破棄時に untrack + removeChannel する。
final FutureProvider<PeerPresenceService?> peerPresenceServiceProvider =
    FutureProvider<PeerPresenceService?>((ref) async {
      if (!Env.hasSupabaseCredentials) {
        return null;
      }
      final settings = ref.watch(settingsRepositoryProvider);
      final ShopId? shopId = await settings.getShopId();
      final DeviceRole? role = await settings.getDeviceRole();
      if (shopId == null || role == null) {
        return null;
      }
      final String deviceId = await settings.getOrCreateDeviceId();
      final String? userName = await settings.getUserName();
      final service = PeerPresenceService(
        client: Supabase.instance.client,
        shopId: shopId.value,
        role: role,
        deviceId: deviceId,
        userName: userName,
      );
      try {
        await service.connect();
      } catch (_) {
        // 接続失敗時はそのまま service を返す（空 peers を流す）。
      }
      ref.onDispose(service.dispose);
      return service;
    });

/// 同一店舗の接続中ピア一覧 Stream（自分自身を含む）。
final StreamProvider<List<PeerInfo>> peersProvider =
    StreamProvider<List<PeerInfo>>((ref) async* {
      final PeerPresenceService? svc = await ref.watch(
        peerPresenceServiceProvider.future,
      );
      if (svc == null) {
        yield const <PeerInfo>[];
        return;
      }
      yield* svc.peers;
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
    prefs: ref.watch(sharedPreferencesProvider),
    clock: ref.watch(clockProvider),
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

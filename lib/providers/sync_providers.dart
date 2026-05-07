import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/sync/cloud_sync_client.dart';
import '../core/sync/supabase_cloud_sync_client.dart';
import '../core/sync/supabase_realtime_listener.dart';
import '../core/sync/sync_service.dart';
import '../domain/value_objects/shop_id.dart';
import 'connectivity_providers.dart';
import 'repository_providers.dart';

/// CloudSyncClient: Supabase接続情報があれば本実装、無ければ Noop。
final Provider<CloudSyncClient> cloudSyncClientProvider =
    Provider<CloudSyncClient>((Ref<CloudSyncClient> ref) {
  if (Env.hasSupabaseCredentials) {
    return SupabaseCloudSyncClient(Supabase.instance.client);
  }
  return NoopCloudSyncClient();
});

/// SupabaseRealtimeListener: 店舗ID と Supabase 接続情報が揃っていれば購読、無ければ null。
final FutureProvider<SupabaseRealtimeListener?> supabaseRealtimeListenerProvider =
    FutureProvider<SupabaseRealtimeListener?>(
  (Ref<AsyncValue<SupabaseRealtimeListener?>> ref) async {
    if (!Env.hasSupabaseCredentials) {
      return null;
    }
    final ShopId? shopId =
        await ref.watch(settingsRepositoryProvider).getShopId();
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
  },
);

/// 受信した Realtime イベントを Stream で公開。
final StreamProvider<RealtimeOrderLineEvent> realtimeOrderLineEventsProvider =
    StreamProvider<RealtimeOrderLineEvent>(
  (Ref<AsyncValue<RealtimeOrderLineEvent>> ref) async* {
    final SupabaseRealtimeListener? listener =
        await ref.watch(supabaseRealtimeListenerProvider.future);
    if (listener == null) {
      return;
    }
    yield* listener.events();
  },
);

/// SyncService: ライフサイクル付き Provider。
/// `ref.read(syncServiceProvider).start()` を起動時に1回呼ぶ。
final Provider<SyncService> syncServiceProvider =
    Provider<SyncService>((Ref<SyncService> ref) {
  final SyncService service = SyncService(
    orderRepository: ref.watch(orderRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    connectivityMonitor: ref.watch(connectivityMonitorProvider),
    client: ref.watch(cloudSyncClientProvider),
  );
  ref.onDispose(service.stop);
  return service;
});

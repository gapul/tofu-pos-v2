import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/sync/cloud_sync_client.dart';
import '../core/sync/supabase_cloud_sync_client.dart';
import '../core/sync/sync_service.dart';
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

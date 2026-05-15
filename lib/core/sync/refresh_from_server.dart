import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calling/domain/calling_ingest_router.dart';
import '../../features/kitchen/domain/kitchen_ingest_router.dart';
import '../../providers/role_router_providers.dart';
import '../logging/app_logger.dart';
import 'device_events_backfill.dart';

/// 役割別の Pull-to-Refresh 用ヘルパ。
///
/// サーバの `device_events` から過去イベントを取得して、対応する
/// IngestRouter に流す。取り込みは upsert で冪等。
class RefreshFromServer {
  static Future<int> kitchen(WidgetRef ref) async {
    final DeviceEventsBackfill? b = await ref.read(
      deviceEventsBackfillProvider.future,
    );
    final KitchenIngestRouter? r = await ref.read(
      kitchenIngestRouterProvider.future,
    );
    if (b == null || r == null) {
      AppLogger.i('RefreshFromServer.kitchen: skipped (offline or not ready)');
      return 0;
    }
    return b.run(onEvent: r.handleEvent);
  }

  static Future<int> calling(WidgetRef ref) async {
    final DeviceEventsBackfill? b = await ref.read(
      deviceEventsBackfillProvider.future,
    );
    final CallingIngestRouter? r = await ref.read(
      callingIngestRouterProvider.future,
    );
    if (b == null || r == null) {
      AppLogger.i('RefreshFromServer.calling: skipped (offline or not ready)');
      return 0;
    }
    return b.run(onEvent: r.handleEvent);
  }
}

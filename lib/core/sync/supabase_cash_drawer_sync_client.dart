import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/cash_drawer.dart';
import '../../domain/value_objects/denomination.dart';
import '../logging/app_logger.dart';
import '../retry/retry_policy.dart';

/// 釣銭スナップショットを Supabase `cash_drawer_snapshots` に upsert する。
///
/// 主キー: (shop_id, denomination_yen)。常に全 9 金種を一括 upsert する
/// (履歴は持たず「いまの理論枚数」だけを保持)。
class SupabaseCashDrawerSyncClient {
  SupabaseCashDrawerSyncClient(
    this._client, {
    RetryPolicy retryPolicy = const RetryPolicy(
      maxDelay: Duration(seconds: 2),
    ),
  }) : _retry = retryPolicy;

  final SupabaseClient _client;
  final RetryPolicy _retry;

  static const String _table = 'cash_drawer_snapshots';

  Future<void> push(
    CashDrawer drawer, {
    required String shopId,
  }) async {
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[
      for (final Denomination d in Denomination.all)
        <String, Object?>{
          'shop_id': shopId,
          'denomination_yen': d.yen,
          'count': drawer.countOf(d),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
    ];
    try {
      await _retry.run<void>(() async {
        await _client
            .from(_table)
            .upsert(rows, onConflict: 'shop_id,denomination_yen');
      });
      AppLogger.event(
        'sync',
        'cash_drawer_pushed',
        fields: <String, Object?>{'total_yen': drawer.totalAmount.yen},
        level: AppLogLevel.debug,
      );
    } catch (e, st) {
      AppLogger.w(
        'SupabaseCashDrawerSyncClient: push failed (will retry on next opportunity)',
        error: e,
        stackTrace: st,
      );
    }
  }
}

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

  /// Supabase から該当店舗の釣銭スナップショットを取得して CashDrawer を組む。
  /// クラウド未投入で 0 件のときは null を返す (呼び出し側がローカル温存判断)。
  Future<CashDrawer?> pull({required String shopId}) async {
    try {
      final List<Map<String, dynamic>> rows = await _retry.run<List<Map<String, dynamic>>>(() async {
        final result = await _client
            .from(_table)
            .select('denomination_yen, count')
            .eq('shop_id', shopId);
        return List<Map<String, dynamic>>.from(result as List);
      });
      if (rows.isEmpty) return null;
      final Map<Denomination, int> counts = <Denomination, int>{
        for (final Denomination d in Denomination.all) d: 0,
      };
      for (final Map<String, dynamic> r in rows) {
        final int yen = (r['denomination_yen'] as num).toInt();
        final int count = (r['count'] as num).toInt();
        try {
          counts[Denomination(yen)] = count;
        } catch (_) {
          // 未知金種は無視
        }
      }
      return CashDrawer(counts);
    } catch (e, st) {
      AppLogger.w(
        'SupabaseCashDrawerSyncClient: pull failed (returning null)',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

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

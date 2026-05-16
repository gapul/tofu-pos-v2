import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/local/database.dart';
import '../config/env.dart';
import '../logging/app_logger.dart';
import '../telemetry/telemetry.dart';

/// Supabase の接続先 (URL) が前回起動時と変わっていたら、
/// ローカル DB の `orders.sync_status` を全て `notSynced` に戻す。
///
/// 用途: 別の Supabase project に切り替えたときに、旧クラウドに送信済の
/// orders を新クラウドにも上げ直す。ローカルが正本でクラウドはミラー
/// という前提なので、idempotency_key (UUID v5) によって何度送られても
/// 同じ行に収束する = 安全。
///
/// fingerprint は SHA-1 等は使わず生 URL をそのまま比較 (URL は秘匿性
/// ゼロなので難読化不要)。
class CloudTargetReset {
  CloudTargetReset(this._db, this._prefs);

  final AppDatabase _db;
  final SharedPreferences _prefs;

  static const String _kCurrentCloudUrl = 'sync.lastKnownCloudUrl';

  Future<void> runIfTargetChanged() async {
    final String current = Env.supabaseUrl;
    if (current.isEmpty) return; // Noop モードなのでスキップ
    final String? lastKnown = _prefs.getString(_kCurrentCloudUrl);
    if (lastKnown == current) return; // 同じ project: 何もしない

    // lastKnown が null のケースを 2 つ区別する:
    //   1. 真の新規端末 (orders テーブルが空) → reset しても影響なし
    //   2. 旧ビルドからのアップグレード (orders はあるが lastKnownCloudUrl が
    //      未保存) → 旧クラウドへ送信済 (に見える) 行を新クラウドへ再 push
    //      する必要があるので reset 必須
    // 両ケースとも reset を実行する。idempotency_key (UUID v5) で
    // 多重送信は冪等に吸収される。
    try {
      final int affected = await _db.customUpdate(
        "UPDATE orders SET sync_status = 'notSynced' WHERE sync_status = 'synced'",
      );
      AppLogger.event(
        'sync',
        'cloud_target_changed',
        fields: <String, Object?>{
          'from': lastKnown ?? '<null>',
          'to': current,
          'resynced_orders': affected,
        },
        level: AppLogLevel.info,
      );
      Telemetry.instance.event(
        'sync.cloud_target_changed',
        attrs: <String, Object?>{
          'from': lastKnown ?? '<null>',
          'to': current,
          'resynced_orders': affected,
        },
      );
    } catch (e, st) {
      AppLogger.e(
        'CloudTargetReset: failed to reset sync_status',
        error: e,
        stackTrace: st,
      );
    }
    await _prefs.setString(_kCurrentCloudUrl, current);
  }
}

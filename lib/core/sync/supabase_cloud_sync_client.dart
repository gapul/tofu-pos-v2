import '../../domain/entities/order.dart';
import 'cloud_sync_client.dart';

/// Supabase 経由の同期実装（仕様書 §8）。
///
/// **未実装**: Supabase プロジェクトを作成し URL/anon key を埋めた上で、
/// `supabase_flutter` を使ってテーブルへの insert を実装する。
///
/// 設計メモ:
///  - 'orders' テーブルへの upsert（注文ID + 取消フラグで identify）
///  - 'order_items' テーブルへの insert
///  - RLS により shop_id 単位で書き込み権限を制御する想定
class SupabaseCloudSyncClient implements CloudSyncClient {
  const SupabaseCloudSyncClient();

  @override
  Future<void> push(Order order, {required String shopId}) {
    throw UnimplementedError(
      'SupabaseCloudSyncClient is not implemented yet. '
      'Provide URL/anonKey and implement insert/upsert.',
    );
  }
}

import '../../domain/entities/order.dart';

/// クラウド側との注文同期インターフェース（仕様書 §8）。
///
/// 実装の選択肢:
///  - SupabaseCloudSyncClient（オンライン主経路、未実装）
///  - NoopCloudSyncClient（オフライン時／開発時のスタブ）
abstract interface class CloudSyncClient {
  /// 注文（新規および取消）を1件送信する。成功なら通常完了、失敗なら例外。
  Future<void> push(Order order, {required String shopId});
}

/// 何もしない実装（テスト・初期開発用）。
class NoopCloudSyncClient implements CloudSyncClient {
  @override
  Future<void> push(Order order, {required String shopId}) async {
    // No-op
  }
}

import '../entities/customer_attributes.dart';
import '../entities/order.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';

/// 注文リポジトリ抽象。
abstract interface class OrderRepository {
  Future<Order?> findById(int id);

  /// 注文を取得する。
  ///
  /// [limit] 取得件数の上限。null なら無制限。長期運用での履歴肥大対策に推奨。
  /// [offset] スキップする件数。ページネーション用。
  /// 並び順は createdAt の降順（新しい順）。
  Future<List<Order>> findAll({
    DateTime? from,
    DateTime? to,
    int? limit,
    int offset = 0,
  });

  Future<List<Order>> findUnsynced();
  Stream<List<Order>> watchAll({DateTime? from, DateTime? to});

  /// 新規注文を保存し、採番された注文IDを持つ Order を返す。
  Future<Order> create(Order order);

  /// 注文ステータスを更新する。
  ///
  /// 既定では `OrderStatus.canTransitionTo` に従って状態遷移を検証する。
  /// 不正遷移時は `InvalidStateTransitionException` を投げる
  /// （未知 ID は no-op、同一状態は no-op）。
  ///
  /// [allowTerminalOverride] = true のときは、終端状態（served / cancelled）
  /// からの遷移も許可する。業務上稀にある「提供済の事後取消」等、
  /// 監査ログ（operation_log）と併用して使うこと。
  Future<void> updateStatus(
    int id,
    OrderStatus status, {
    bool allowTerminalOverride = false,
  });

  Future<void> updateSyncStatus(int id, SyncStatus status);

  /// 顧客属性を後付けで更新する（会計後ヒアリング用）。
  Future<void> updateCustomerAttributes(int id, CustomerAttributes attributes);
}

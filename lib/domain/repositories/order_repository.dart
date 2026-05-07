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

  Future<void> updateStatus(int id, OrderStatus status);
  Future<void> updateSyncStatus(int id, SyncStatus status);
}

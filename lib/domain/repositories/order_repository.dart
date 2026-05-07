import '../entities/order.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';

/// 注文リポジトリ抽象。
abstract interface class OrderRepository {
  Future<Order?> findById(int id);
  Future<List<Order>> findAll({DateTime? from, DateTime? to});
  Future<List<Order>> findUnsynced();
  Stream<List<Order>> watchAll({DateTime? from, DateTime? to});

  /// 新規注文を保存し、採番された注文IDを持つ Order を返す。
  Future<Order> create(Order order);

  Future<void> updateStatus(int id, OrderStatus status);
  Future<void> updateSyncStatus(int id, SyncStatus status);
}

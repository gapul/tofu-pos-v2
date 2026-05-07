import '../entities/kitchen_order.dart';
import '../enums/kitchen_status.dart';

/// キッチン端末ローカルの注文ストア（仕様書 §5.5）。
abstract interface class KitchenOrderRepository {
  Future<KitchenOrder?> findByOrderId(int orderId);

  /// 全件取得。並び順は受信時刻の昇順（古い順）。
  Future<List<KitchenOrder>> findAll();

  /// 状態別ストリーム購読（UI が直接 watch する想定）。
  Stream<List<KitchenOrder>> watchAll();

  /// 新規注文を保存。同一 orderId が既に存在する場合は上書き（冪等）。
  Future<void> upsert(KitchenOrder order);

  /// ステータスのみ更新。
  Future<void> updateStatus(int orderId, KitchenStatus status);
}

import '../entities/calling_order.dart';
import '../enums/calling_status.dart';

/// 呼び出し端末ローカルの注文ストア（仕様書 §5.6）。
abstract interface class CallingOrderRepository {
  Future<CallingOrder?> findByOrderId(int orderId);
  Future<List<CallingOrder>> findAll();
  Stream<List<CallingOrder>> watchAll();
  Future<void> upsert(CallingOrder order);
  Future<void> updateStatus(int orderId, CallingStatus status);
}

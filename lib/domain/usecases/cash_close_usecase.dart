import '../entities/cash_drawer.dart';
import '../entities/order.dart';
import '../enums/order_status.dart';
import '../enums/sync_status.dart';
import '../repositories/cash_drawer_repository.dart';
import '../repositories/order_repository.dart';
import '../value_objects/cash_close_difference.dart';
import '../value_objects/daily_summary.dart';
import '../value_objects/feature_flags.dart';
import '../value_objects/money.dart';

/// レジ締め処理（仕様書 §6.4）。
///
/// ステートレスな計算 UseCase:
///   - getDailySummary: 当日の売上サマリを取得（金種管理オン時は理論値も）
///   - computeDifference: 理論値と実測値から差額を算出（金種管理オン時のみ）
class CashCloseUseCase {
  CashCloseUseCase({
    required OrderRepository orderRepository,
    required CashDrawerRepository cashDrawerRepository,
    DateTime Function() now = DateTime.now,
  }) : _orderRepo = orderRepository,
       _cashRepo = cashDrawerRepository,
       _now = now;

  final OrderRepository _orderRepo;
  final CashDrawerRepository _cashRepo;
  final DateTime Function() _now;

  /// 当日の営業サマリを返す。
  ///
  /// [forDate] が null なら端末ローカルの今日を使う。
  Future<DailySummary> getDailySummary({
    required FeatureFlags flags,
    DateTime? forDate,
  }) async {
    final DateTime base = forDate ?? _now();
    final DateTime dayStart = DateTime(base.year, base.month, base.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final List<Order> orders = await _orderRepo.findAll(
      from: dayStart,
      to: dayEnd,
    );

    Money totalSales = Money.zero;
    int orderCount = 0;
    int cancelledCount = 0;
    int unsyncedCount = 0;
    for (final Order o in orders) {
      if (o.orderStatus == OrderStatus.cancelled) {
        cancelledCount++;
      } else {
        totalSales = totalSales + o.finalPrice;
        orderCount++;
      }
      if (o.syncStatus == SyncStatus.notSynced) {
        unsyncedCount++;
      }
    }

    CashDrawer? theoretical;
    if (flags.cashManagement) {
      theoretical = await _cashRepo.get();
    }

    return DailySummary(
      date: dayStart,
      totalSales: totalSales,
      orderCount: orderCount,
      cancelledCount: cancelledCount,
      unsyncedCount: unsyncedCount,
      theoreticalDrawer: theoretical,
    );
  }

  /// 金種理論値と実測値の差額を計算（純関数）。
  CashCloseDifference computeDifference({
    required CashDrawer theoretical,
    required CashDrawer actual,
  }) {
    return CashCloseDifference(theoretical: theoretical, actual: actual);
  }
}

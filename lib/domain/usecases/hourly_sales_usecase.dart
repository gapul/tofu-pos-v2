import '../entities/order.dart';
import '../enums/order_status.dart';
import '../repositories/order_repository.dart';
import '../value_objects/hourly_sales_bucket.dart';
import '../value_objects/money.dart';

/// 時間帯別売上サマリ（仕様書 §6.4 レジ締めの補助情報）。
///
/// 営業日の 0〜23 時の各時間帯について売上合計と注文件数を集計する。
class HourlySalesUseCase {
  HourlySalesUseCase({
    required OrderRepository orderRepository,
    DateTime Function() now = DateTime.now,
  }) : _orderRepo = orderRepository,
       _now = now;

  final OrderRepository _orderRepo;
  final DateTime Function() _now;

  /// 指定日の時間帯別サマリを返す。
  ///
  /// 戻り値は **常に 24 件**（0〜23時の各バケット）。注文がない時間帯は
  /// `orderCount=0, totalSales=0` の bucket が入る。
  Future<List<HourlySalesBucket>> getHourly({DateTime? forDate}) async {
    final DateTime base = forDate ?? _now();
    final DateTime dayStart = DateTime(base.year, base.month, base.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final List<Order> orders = await _orderRepo.findAll(
      from: dayStart,
      to: dayEnd,
    );

    final List<int> orderCounts = List<int>.filled(24, 0);
    final List<int> salesYen = List<int>.filled(24, 0);

    for (final Order o in orders) {
      if (o.orderStatus == OrderStatus.cancelled) continue;
      final int h = o.createdAt.hour;
      if (h < 0 || h >= 24) continue;
      orderCounts[h] += 1;
      salesYen[h] += o.finalPrice.yen;
    }

    return List<HourlySalesBucket>.generate(
      24,
      (int h) => HourlySalesBucket(
        hour: h,
        totalSales: Money(salesYen[h]),
        orderCount: orderCounts[h],
      ),
    );
  }

  /// 注文があった時間帯だけ返す簡易版。
  Future<List<HourlySalesBucket>> getActiveHourly({DateTime? forDate}) async {
    final List<HourlySalesBucket> all = await getHourly(forDate: forDate);
    return all.where((HourlySalesBucket b) => !b.isEmpty).toList();
  }
}

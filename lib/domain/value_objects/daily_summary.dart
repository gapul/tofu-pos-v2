import 'package:meta/meta.dart';

import '../entities/cash_drawer.dart';
import 'money.dart';

/// 営業日のサマリ（仕様書 §6.4 レジ締め）。
@immutable
class DailySummary {
  const DailySummary({
    required this.date,
    required this.totalSales,
    required this.orderCount,
    required this.cancelledCount,
    required this.unsyncedCount,
    this.theoreticalDrawer,
  });

  /// 集計対象の営業日（時刻部分は捨てる想定）。
  final DateTime date;

  /// 売上合計（取消済みを除いた請求金額の合計）。
  final Money totalSales;

  /// 注文件数（取消除く）。
  final int orderCount;

  /// 取消済み件数。
  final int cancelledCount;

  /// 未同期件数。
  final int unsyncedCount;

  /// 金種管理オン時のレジ理論値。オフなら null。
  final CashDrawer? theoreticalDrawer;

  bool get hasUnsynced => unsyncedCount > 0;
}

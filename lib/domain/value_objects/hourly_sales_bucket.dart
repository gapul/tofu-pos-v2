import 'package:meta/meta.dart';

import 'money.dart';

/// 1時間幅の売上集計（営業日内の特定時間帯）。
@immutable
class HourlySalesBucket {
  const HourlySalesBucket({
    required this.hour,
    required this.totalSales,
    required this.orderCount,
  });

  /// 0〜23 のローカル時刻の時。
  final int hour;

  /// この時間帯の売上合計（取消除く）。
  final Money totalSales;

  /// この時間帯の注文件数（取消除く）。
  final int orderCount;

  bool get isEmpty => orderCount == 0;
}

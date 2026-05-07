import 'package:meta/meta.dart';

import '../entities/cash_drawer.dart';
import 'denomination.dart';
import 'money.dart';

/// 金種管理オン時のレジ締め差額（仕様書 §6.4）。
///
/// 理論値（システム計算）と実測値（人間が数えた枚数）の差を金種別に持つ。
@immutable
class CashCloseDifference {
  const CashCloseDifference({
    required this.theoretical,
    required this.actual,
  });

  final CashDrawer theoretical;
  final CashDrawer actual;

  /// 金種別の枚数差分。`actual.count - theoretical.count` で計算。
  /// 正: 余り、負: 不足。
  Map<Denomination, int> get countDiff {
    final Map<Denomination, int> diff = <Denomination, int>{};
    for (final Denomination d in Denomination.all) {
      diff[d] = actual.countOf(d) - theoretical.countOf(d);
    }
    return diff;
  }

  /// 金額換算した差分の合計。
  Money get amountDiff => actual.totalAmount - theoretical.totalAmount;

  bool get isZero => amountDiff.isZero;
  bool get isShort => amountDiff.isNegative;
  bool get isOver => amountDiff.isPositive;
}

import 'package:meta/meta.dart';

import '../value_objects/denomination.dart';
import '../value_objects/money.dart';

/// 金種在庫（仕様書 §5.4）。レジ端末のみ、金種管理オン時のみ使用。
///
/// 金種ごとの枚数（理論値）を保持する。
@immutable
class CashDrawer {
  CashDrawer(Map<Denomination, int> counts)
    : _counts = Map<Denomination, int>.unmodifiable(counts) {
    for (final int count in _counts.values) {
      if (count < 0) {
        throw ArgumentError('Counts must be non-negative');
      }
    }
  }

  /// 全金種を0枚で初期化。
  factory CashDrawer.empty() {
    return CashDrawer(<Denomination, int>{
      for (final Denomination d in Denomination.all) d: 0,
    });
  }

  final Map<Denomination, int> _counts;

  Map<Denomination, int> get counts => _counts;

  int countOf(Denomination d) => _counts[d] ?? 0;

  /// 全金種の合計金額。
  Money get totalAmount {
    int sum = 0;
    _counts.forEach((Denomination d, int count) {
      sum += d.yen * count;
    });
    return Money(sum);
  }

  /// 指定された金種別差分を適用した新しい CashDrawer を返す。
  /// 負の値で減算。結果が負になる金種があれば StateError。
  CashDrawer apply(Map<Denomination, int> delta) {
    final Map<Denomination, int> newCounts = <Denomination, int>{..._counts};
    delta.forEach((Denomination d, int diff) {
      final int next = (newCounts[d] ?? 0) + diff;
      if (next < 0) {
        throw StateError('CashDrawer: $d would go negative ($next)');
      }
      newCounts[d] = next;
    });
    return CashDrawer(newCounts);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CashDrawer) {
      return false;
    }
    if (_counts.length != other._counts.length) {
      return false;
    }
    for (final MapEntry<Denomination, int> e in _counts.entries) {
      if (other._counts[e.key] != e.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = 0;
    _counts.forEach((Denomination d, int count) {
      hash = Object.hash(hash, d, count);
    });
    return hash;
  }
}

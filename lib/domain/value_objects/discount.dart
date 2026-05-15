import 'package:meta/meta.dart';

import 'money.dart';

/// 割引・割増の表現（仕様書 §6.1.3 / §9.3）。
///
/// 円指定（amount）と率指定（percent）の2種類。
/// 負の値で割引、正の値で割増として扱う。
///
/// ## お金の四捨五入ポリシー
///
/// 全体割引額 D は [applyTo] / [asAmount] で **整数演算のみ** で確定する。
/// 行単位への按分は [allocate] で「最大剰余法（Largest Remainder Method）」を
/// 用いて行い、`Σ allocate(...) == asAmount(subtotal)` を厳守する。
/// 行ごとに独立 round すると 1〜N 円の差額が出るため、必ず [allocate] を使う。
@immutable
sealed class Discount {
  const Discount();

  static const Discount none = AmountDiscount(Money.zero);

  /// この割引/割増を金額に適用した結果を返す。
  Money applyTo(Money base);

  /// 適用された絶対金額（割引の按分計算等で使う）。負なら割引、正なら割増。
  Money asAmount(Money base);

  /// 各行の小計 [lineSubtotals] に対して全体割引額を **過不足なく** 按分する。
  ///
  /// 不変条件: `Σ result == asAmount(Σ lineSubtotals)`
  ///
  /// アルゴリズム: 最大剰余法（Largest Remainder Method）。
  ///   1. 全体割引額 D = `asAmount(subtotal)` を整数で確定
  ///   2. 各行の理想配分 share_i = subtotal_i * D / subtotal を計算
  ///   3. 各行 floor → 残差 D - Σfloor を、剰余（小数部）の大きい行から ±1 円ずつ配る
  ///
  /// 注: 小計の合計が 0 の場合は全行 0 を返す。
  ///     D が 0 の場合も全行 0 を返す（trivial）。
  List<Money> allocate(List<Money> lineSubtotals) {
    final int n = lineSubtotals.length;
    if (n == 0) {
      return const <Money>[];
    }
    int subtotalSum = 0;
    for (final Money m in lineSubtotals) {
      subtotalSum += m.yen;
    }
    final int total = asAmount(Money(subtotalSum)).yen;
    if (total == 0 || subtotalSum == 0) {
      return List<Money>.filled(n, Money.zero);
    }

    // 符号を吸収して非負の問題に正規化する（負の割引でも floor/ceil の挙動を統一）。
    final int sign = total < 0 ? -1 : 1;
    final int absTotal = total.abs();
    final int absSubtotal = subtotalSum.abs();

    // floor 配分。整数で `subtotal_i * absTotal ~/ absSubtotal`。
    // 小計が負の行が混ざる想定は無いが、念のため abs を取る。
    final List<int> floors = List<int>.filled(n, 0);
    final List<int> remainders = List<int>.filled(n, 0);
    int floorSum = 0;
    for (int i = 0; i < n; i++) {
      final int s = lineSubtotals[i].yen.abs();
      final int num = s * absTotal;
      final int f = num ~/ absSubtotal;
      final int r = num - f * absSubtotal; // 剰余（0..absSubtotal-1）
      floors[i] = f;
      remainders[i] = r;
      floorSum += f;
    }
    final int deficit = absTotal - floorSum;

    // 剰余が大きい行から +1 円ずつ配る。同点は元のインデックス昇順（決定論的）。
    final List<int> order = List<int>.generate(n, (i) => i);
    order.sort((a, b) {
      final int cmp = remainders[b].compareTo(remainders[a]);
      if (cmp != 0) return cmp;
      return a.compareTo(b);
    });
    for (int k = 0; k < deficit; k++) {
      floors[order[k]] += 1;
    }

    // Σ == total を invariant で検証。
    int check = 0;
    final List<Money> result = List<Money>.generate(n, (i) {
      final int v = sign * floors[i];
      check += v;
      return Money(v);
    });
    assert(
      check == total,
      'Discount.allocate invariant violated: sum=$check total=$total',
    );
    return result;
  }
}

/// 円単位の割引/割増。
@immutable
class AmountDiscount extends Discount {
  const AmountDiscount(this.amount);

  final Money amount;

  @override
  Money applyTo(Money base) => base + amount;

  @override
  Money asAmount(Money base) => amount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AmountDiscount && amount == other.amount);

  @override
  int get hashCode => Object.hash('AmountDiscount', amount);

  @override
  String toString() => 'AmountDiscount($amount)';
}

/// 率（%）の割引/割増。負の値で割引、正の値で割増。
///
/// 例: percent = -10 で 10% OFF。
@immutable
class PercentDiscount extends Discount {
  const PercentDiscount(this.percent);

  final int percent;

  @override
  Money applyTo(Money base) => base + asAmount(base);

  @override
  Money asAmount(Money base) {
    // 整数演算で全体割引額を確定する（double を避け Money 整数原則を維持）。
    // 端数処理は「半数切り上げ（half away from zero）」相当:
    //   絶対値で計算し最後に符号を戻す。
    //   ex) base=333, percent=-10: |333*-10|=3330, 3330/100=33.3 → 33（half↓ but
    //       half-away を満たすために (|num| + den/2) ~/ den を使う）
    final int num = base.yen * percent;
    final int absNum = num.abs();
    const int den = 100;
    final int absRounded = (absNum + den ~/ 2) ~/ den;
    final int signed = num < 0 ? -absRounded : absRounded;
    return Money(signed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PercentDiscount && percent == other.percent);

  @override
  int get hashCode => Object.hash('PercentDiscount', percent);

  @override
  String toString() => 'PercentDiscount($percent%)';
}

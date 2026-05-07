import 'package:meta/meta.dart';

import 'money.dart';

/// 割引・割増の表現（仕様書 §6.1.3 / §9.3）。
///
/// 円指定（amount）と率指定（percent）の2種類。
/// 負の値で割引、正の値で割増として扱う。
@immutable
sealed class Discount {
  const Discount();

  static const Discount none = AmountDiscount(Money.zero);

  /// この割引/割増を金額に適用した結果を返す。
  Money applyTo(Money base);

  /// 適用された絶対金額（割引の按分計算等で使う）。
  Money asAmount(Money base);
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
    // 端数は四捨五入（floor だと割引が1円多くなる方向）。
    final double raw = base.yen * percent / 100;
    return Money(raw.round());
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

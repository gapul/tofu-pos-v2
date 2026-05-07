import 'package:meta/meta.dart';

/// 金額（円単位）。
///
/// 学祭POSでは小数を扱わないため整数で管理する。
/// 負の値も表現可能（割引・返金等）。
@immutable
class Money implements Comparable<Money> {
  const Money(this.yen);

  static const Money zero = Money(0);

  final int yen;

  Money operator +(Money other) => Money(yen + other.yen);

  Money operator -(Money other) => Money(yen - other.yen);

  Money operator *(int multiplier) => Money(yen * multiplier);

  bool operator >(Money other) => yen > other.yen;

  bool operator <(Money other) => yen < other.yen;

  bool operator >=(Money other) => yen >= other.yen;

  bool operator <=(Money other) => yen <= other.yen;

  Money operator -() => Money(-yen);

  Money abs() => Money(yen.abs());

  bool get isZero => yen == 0;
  bool get isPositive => yen > 0;
  bool get isNegative => yen < 0;

  @override
  int compareTo(Money other) => yen.compareTo(other.yen);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Money && yen == other.yen);

  @override
  int get hashCode => yen.hashCode;

  @override
  String toString() => '¥$yen';
}

import 'package:meta/meta.dart';

/// 整理券番号（仕様書 §5.2 整理券番号の発番ルール）。
///
/// 1〜N の範囲を循環使用する顧客提示用の短い番号。
/// 注文IDとは別物（注文IDは永続連番、整理券番号は再利用される）。
@immutable
class TicketNumber implements Comparable<TicketNumber> {
  const TicketNumber(this.value)
      : assert(value > 0, 'TicketNumber must be positive');

  final int value;

  @override
  int compareTo(TicketNumber other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TicketNumber && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString().padLeft(2, '0');
}

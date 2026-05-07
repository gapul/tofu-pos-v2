import 'package:meta/meta.dart';

/// 金種（仕様書 §5.4）。日本の硬貨・紙幣の標準的な金種。
@immutable
class Denomination implements Comparable<Denomination> {
  const Denomination(this.yen)
      : assert(
          yen == 1 ||
              yen == 5 ||
              yen == 10 ||
              yen == 50 ||
              yen == 100 ||
              yen == 500 ||
              yen == 1000 ||
              yen == 5000 ||
              yen == 10000,
          'Invalid denomination',
        );

  final int yen;

  static const List<Denomination> all = <Denomination>[
    Denomination(1),
    Denomination(5),
    Denomination(10),
    Denomination(50),
    Denomination(100),
    Denomination(500),
    Denomination(1000),
    Denomination(5000),
    Denomination(10000),
  ];

  @override
  int compareTo(Denomination other) => yen.compareTo(other.yen);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Denomination && yen == other.yen);

  @override
  int get hashCode => yen.hashCode;

  @override
  String toString() => '¥$yen';
}

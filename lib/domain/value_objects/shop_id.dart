import 'package:meta/meta.dart';

/// 店舗ID（仕様書 §3.1）。
///
/// 同店舗の端末群を識別する任意の文字列。
/// 例: "yakisoba_A"
@immutable
class ShopId {
  ShopId(this.value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, 'value', 'ShopId must not be empty');
    }
    if (value.length > 64) {
      throw ArgumentError.value(value, 'value', 'ShopId too long');
    }
  }

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ShopId && value == other.value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

import 'package:meta/meta.dart';

import '../value_objects/money.dart';

/// 商品マスタ（仕様書 §5.1）。
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.displayColor,
    this.isDeleted = false,
  });

  /// 商品ID（UUID等の永続識別子）。
  final String id;

  /// 商品名。
  final String name;

  /// 価格。
  final Money price;

  /// 在庫数。在庫管理オフ時は無視される。
  final int stock;

  /// 商品ボタンの背景色（ARGB値）。null なら既定色。
  final int? displayColor;

  /// 削除フラグ（論理削除）。
  final bool isDeleted;

  Product copyWith({
    String? id,
    String? name,
    Money? price,
    int? stock,
    int? displayColor,
    bool clearDisplayColor = false,
    bool? isDeleted,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      displayColor: clearDisplayColor
          ? null
          : (displayColor ?? this.displayColor),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          id == other.id &&
          name == other.name &&
          price == other.price &&
          stock == other.stock &&
          displayColor == other.displayColor &&
          isDeleted == other.isDeleted);

  @override
  int get hashCode =>
      Object.hash(id, name, price, stock, displayColor, isDeleted);

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, stock: $stock)';
}

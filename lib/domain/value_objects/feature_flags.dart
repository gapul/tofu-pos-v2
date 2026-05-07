import 'package:meta/meta.dart';

/// 機能フラグ（仕様書 §4）。
///
/// 各フラグは互いに独立。すべてオフでもレジ単独業務は利用可能。
@immutable
class FeatureFlags {
  const FeatureFlags({
    this.stockManagement = false,
    this.cashManagement = false,
    this.customerAttributes = false,
    this.kitchenLink = false,
    this.callingLink = false,
  });

  /// 在庫管理
  final bool stockManagement;

  /// 金種管理
  final bool cashManagement;

  /// 顧客属性入力
  final bool customerAttributes;

  /// キッチン連携
  final bool kitchenLink;

  /// 呼び出し連携
  final bool callingLink;

  static const FeatureFlags allOff = FeatureFlags();

  FeatureFlags copyWith({
    bool? stockManagement,
    bool? cashManagement,
    bool? customerAttributes,
    bool? kitchenLink,
    bool? callingLink,
  }) {
    return FeatureFlags(
      stockManagement: stockManagement ?? this.stockManagement,
      cashManagement: cashManagement ?? this.cashManagement,
      customerAttributes: customerAttributes ?? this.customerAttributes,
      kitchenLink: kitchenLink ?? this.kitchenLink,
      callingLink: callingLink ?? this.callingLink,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeatureFlags &&
          stockManagement == other.stockManagement &&
          cashManagement == other.cashManagement &&
          customerAttributes == other.customerAttributes &&
          kitchenLink == other.kitchenLink &&
          callingLink == other.callingLink);

  @override
  int get hashCode => Object.hash(
        stockManagement,
        cashManagement,
        customerAttributes,
        kitchenLink,
        callingLink,
      );
}

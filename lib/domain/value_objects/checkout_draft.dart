import 'package:meta/meta.dart';

import '../entities/customer_attributes.dart';
import '../entities/order_item.dart';
import 'discount.dart';
import 'money.dart';

/// 会計確定前の入力スナップショット（カート + 預り金 + 顧客属性）。
///
/// UseCase の入力として渡される、決定権を持たないデータ。
@immutable
class CheckoutDraft {
  const CheckoutDraft({
    required this.items,
    this.discount = Discount.none,
    this.receivedCash = Money.zero,
    this.cashDelta = const <int, int>{},
    this.customerAttributes = CustomerAttributes.empty,
  });

  /// カート明細。
  final List<OrderItem> items;

  /// 割引・割増。
  final Discount discount;

  /// 預り金。
  final Money receivedCash;

  /// 金種別の入出金差分（金種額 → 枚数差分、入金は正、お釣り金種は負）。
  /// 金種管理オン時のみ意味を持つ。
  final Map<int, int> cashDelta;

  /// 顧客属性。
  final CustomerAttributes customerAttributes;

  /// 合計金額（割引前）。
  Money get totalPrice {
    Money sum = Money.zero;
    for (final OrderItem item in items) {
      sum = sum + item.subtotal;
    }
    return sum;
  }

  Money get finalPrice => discount.applyTo(totalPrice);
  Money get changeCash => receivedCash - finalPrice;
}

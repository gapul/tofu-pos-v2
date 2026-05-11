import 'package:flutter_riverpod/legacy.dart';

import '../../../../domain/entities/customer_attributes.dart';
import '../../../../domain/entities/order_item.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/value_objects/checkout_draft.dart';
import '../../../../domain/value_objects/discount.dart';
import '../../../../domain/value_objects/money.dart';

/// 会計セッション（仕様書 §6.1）。
///
/// 顧客属性入力 → 商品選択 → 会計 → 確定 までの間、レジ画面間で
/// 引き継がれるカート状態を保持する。確定後はリセットされる。
class CheckoutSession {
  const CheckoutSession({
    required this.items,
    required this.customerAttributes,
    required this.discount,
    required this.receivedCash,
    required this.cashDelta,
  });

  factory CheckoutSession.empty() => const CheckoutSession(
    items: <OrderItem>[],
    customerAttributes: CustomerAttributes.empty,
    discount: Discount.none,
    receivedCash: Money.zero,
    cashDelta: <int, int>{},
  );

  final List<OrderItem> items;
  final CustomerAttributes customerAttributes;
  final Discount discount;
  final Money receivedCash;
  final Map<int, int> cashDelta;

  bool get isEmpty => items.isEmpty;

  Money get totalPrice {
    Money sum = Money.zero;
    for (final OrderItem it in items) {
      sum = sum + it.subtotal;
    }
    return sum;
  }

  Money get finalPrice => discount.applyTo(totalPrice);
  Money get changeCash => receivedCash - finalPrice;

  int countOf(String productId) {
    for (final OrderItem it in items) {
      if (it.productId == productId) {
        return it.quantity;
      }
    }
    return 0;
  }

  CheckoutSession copyWith({
    List<OrderItem>? items,
    CustomerAttributes? customerAttributes,
    Discount? discount,
    Money? receivedCash,
    Map<int, int>? cashDelta,
  }) {
    return CheckoutSession(
      items: items ?? this.items,
      customerAttributes: customerAttributes ?? this.customerAttributes,
      discount: discount ?? this.discount,
      receivedCash: receivedCash ?? this.receivedCash,
      cashDelta: cashDelta ?? this.cashDelta,
    );
  }

  CheckoutDraft toDraft() => CheckoutDraft(
    items: items,
    discount: discount,
    receivedCash: receivedCash,
    cashDelta: cashDelta,
    customerAttributes: customerAttributes,
  );
}

class CheckoutSessionNotifier extends StateNotifier<CheckoutSession> {
  CheckoutSessionNotifier() : super(CheckoutSession.empty());

  /// 商品をカートに追加（既存なら quantity += delta）。
  /// [maxStock] が指定された場合、上限を超える追加は無視する（仕様書 §9.2）。
  void addProduct(Product product, {int delta = 1, int? maxStock}) {
    final List<OrderItem> next = List<OrderItem>.from(state.items);
    final int existing = next.indexWhere(
      (it) => it.productId == product.id,
    );
    if (existing >= 0) {
      final int newQty = next[existing].quantity + delta;
      if (newQty <= 0) {
        next.removeAt(existing);
      } else if (maxStock != null && newQty > maxStock) {
        next[existing] = next[existing].copyWith(quantity: maxStock);
      } else {
        next[existing] = next[existing].copyWith(quantity: newQty);
      }
    } else if (delta > 0) {
      final int qty = (maxStock != null && delta > maxStock) ? maxStock : delta;
      if (qty <= 0) {
        return;
      }
      next.add(
        OrderItem(
          productId: product.id,
          productName: product.name,
          priceAtTime: product.price,
          quantity: qty,
        ),
      );
    }
    state = state.copyWith(items: next);
  }

  void removeProduct(String productId) {
    state = state.copyWith(
      items: state.items
          .where((it) => it.productId != productId)
          .toList(),
    );
  }

  void setQuantity(String productId, int quantity, {int? maxStock}) {
    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }
    final int clamped = (maxStock != null && quantity > maxStock)
        ? maxStock
        : quantity;
    final List<OrderItem> next = state.items
        .map(
          (it) =>
              it.productId == productId ? it.copyWith(quantity: clamped) : it,
        )
        .toList();
    state = state.copyWith(items: next);
  }

  void setCustomerAttributes(CustomerAttributes attrs) {
    state = state.copyWith(customerAttributes: attrs);
  }

  void setDiscount(Discount discount) {
    state = state.copyWith(discount: discount);
  }

  void setReceivedCash(Money amount) {
    state = state.copyWith(receivedCash: amount);
  }

  void setCashDelta(Map<int, int> cashDelta) {
    state = state.copyWith(cashDelta: cashDelta);
  }

  void reset() {
    state = CheckoutSession.empty();
  }
}

final StateNotifierProvider<CheckoutSessionNotifier, CheckoutSession>
checkoutSessionProvider =
    StateNotifierProvider<CheckoutSessionNotifier, CheckoutSession>(
      (_) => CheckoutSessionNotifier(),
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

Order _makeOrder({
  Discount discount = Discount.none,
  Money receivedCash = Money.zero,
  List<OrderItem>? items,
}) {
  return Order(
    id: 1,
    ticketNumber: const TicketNumber(1),
    items:
        items ??
        const <OrderItem>[
          OrderItem(
            productId: 'p1',
            productName: 'Yakisoba',
            priceAtTime: Money(400),
            quantity: 2,
          ),
          OrderItem(
            productId: 'p2',
            productName: 'Juice',
            priceAtTime: Money(150),
            quantity: 1,
          ),
        ],
    discount: discount,
    receivedCash: receivedCash,
    createdAt: DateTime(2026, 5, 7, 12),
    orderStatus: OrderStatus.unsent,
    syncStatus: SyncStatus.notSynced,
  );
}

void main() {
  group('Order calculations', () {
    test('totalPrice sums item subtotals', () {
      final Order order = _makeOrder();
      // 400*2 + 150*1 = 950
      expect(order.totalPrice, const Money(950));
    });

    test('finalPrice with no discount equals totalPrice', () {
      final Order order = _makeOrder();
      expect(order.finalPrice, const Money(950));
      expect(order.discountAmount, Money.zero);
    });

    test('finalPrice with amount discount', () {
      final Order order = _makeOrder(
        discount: const AmountDiscount(Money(-100)),
      );
      expect(order.discountAmount, const Money(-100));
      expect(order.finalPrice, const Money(850));
    });

    test('finalPrice with percent discount', () {
      // 950 * -10% = -95
      final Order order = _makeOrder(discount: const PercentDiscount(-10));
      expect(order.discountAmount, const Money(-95));
      expect(order.finalPrice, const Money(855));
    });

    test('changeCash = receivedCash - finalPrice', () {
      final Order order = _makeOrder(receivedCash: const Money(1000));
      expect(order.changeCash, const Money(50));
    });

    test('changeCash can be negative when underpaid', () {
      final Order order = _makeOrder(receivedCash: const Money(500));
      expect(order.changeCash, const Money(-450));
    });
  });

  group('Order status', () {
    test('isCancelled flag', () {
      final Order base = _makeOrder();
      expect(base.isCancelled, isFalse);
      expect(
        base.copyWith(orderStatus: OrderStatus.cancelled).isCancelled,
        isTrue,
      );
    });

    test('terminal statuses', () {
      expect(OrderStatus.unsent.isTerminal, isFalse);
      expect(OrderStatus.sent.isTerminal, isFalse);
      expect(OrderStatus.served.isTerminal, isTrue);
      expect(OrderStatus.cancelled.isTerminal, isTrue);
    });
  });
}

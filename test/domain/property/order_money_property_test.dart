import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/order.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/enums/order_status.dart';
import 'package:tofu_pos/domain/enums/sync_status.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

import '../../_support/property.dart';

Order _randomOrder(Random rng, {required bool nonNegativeDiscount}) {
  final int lineCount = rng.nextInt(11); // 0..10
  final List<OrderItem> items = <OrderItem>[
    for (int i = 0; i < lineCount; i++)
      OrderItem(
        productId: 'p$i',
        productName: 'P$i',
        priceAtTime: Money(rng.nextInt(2001)), // 0..2000
        quantity: rng.nextInt(10) + 1, // 1..10
      ),
  ];

  // 注文小計を計算（割引上限の決定に使う）。
  int total = 0;
  for (final OrderItem it in items) {
    total += it.subtotal.yen;
  }

  // 50/50 amount vs percent discount
  final Discount discount;
  if (rng.nextBool()) {
    // amount: 非負割引（finalPrice が負にならない範囲）。
    // 非負割引のケースでは 0..total を差し引く（負の値で渡す）。
    final int magCap = total == 0 ? 0 : total;
    final int mag = magCap == 0 ? 0 : rng.nextInt(magCap + 1);
    // nonNegativeDiscount=false なら -1000..+1000 を許容
    if (nonNegativeDiscount) {
      discount = AmountDiscount(Money(-mag));
    } else {
      discount = AmountDiscount(Money(rng.nextInt(2001) - 1000));
    }
  } else {
    // percent: -100..+100（非負割引なら -100..0）
    final int p = nonNegativeDiscount
        ? -rng.nextInt(101)
        : rng.nextInt(201) - 100;
    discount = PercentDiscount(p);
  }

  // 預り金は 0..100_000
  final Money received = Money(rng.nextInt(100001));

  return Order(
    id: 1,
    ticketNumber: const TicketNumber(1),
    items: items,
    discount: discount,
    receivedCash: received,
    createdAt: DateTime(2025, 1, 2),
    orderStatus: OrderStatus.served,
    syncStatus: SyncStatus.notSynced,
  );
}

void main() {
  group('Order money invariants (property-based)', () {
    test('finalPrice >= 0 when discount is non-negative', () {
      forAll<Order>(
        name: 'finalPrice >= 0',
        gen: (rng) => _randomOrder(rng, nonNegativeDiscount: true),
        property: (o) => o.finalPrice.yen >= 0,
      );
    });

    test('totalPrice >= finalPrice when discount is non-negative', () {
      forAll<Order>(
        name: 'totalPrice >= finalPrice',
        gen: (rng) => _randomOrder(rng, nonNegativeDiscount: true),
        property: (o) => o.totalPrice.yen >= o.finalPrice.yen,
      );
    });

    test('totalPrice == sum(item.subtotal)', () {
      forAll<Order>(
        name: 'totalPrice == sum subtotals',
        gen: (rng) => _randomOrder(rng, nonNegativeDiscount: true),
        property: (o) {
          int sum = 0;
          for (final OrderItem it in o.items) {
            sum += it.subtotal.yen;
          }
          return o.totalPrice.yen == sum;
        },
      );
    });

    test('discount == 0 implies totalPrice == finalPrice', () {
      final Random rng = Random(42);
      for (int i = 0; i < 200; i++) {
        final Order base = _randomOrder(rng, nonNegativeDiscount: true);
        final Order zeroDiscount = base.copyWith(discount: Discount.none);
        expect(
          zeroDiscount.totalPrice,
          zeroDiscount.finalPrice,
          reason: 'iteration $i',
        );
      }
    });

    test('changeCash == receivedCash - finalPrice', () {
      forAll<Order>(
        name: 'changeCash identity',
        gen: (rng) => _randomOrder(rng, nonNegativeDiscount: true),
        property: (o) =>
            o.changeCash.yen == o.receivedCash.yen - o.finalPrice.yen,
      );
    });

    test('order with no items has zero totalPrice and zero finalPrice', () {
      forAll<Order>(
        name: 'empty items -> zero',
        gen: (rng) => _randomOrder(rng, nonNegativeDiscount: true).copyWith(
          items: const <OrderItem>[],
          discount: Discount.none,
        ),
        property: (o) =>
            o.totalPrice == Money.zero && o.finalPrice == Money.zero,
      );
    });
  });
}

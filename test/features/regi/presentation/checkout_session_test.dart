import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/customer_attributes.dart';
import 'package:tofu_pos/domain/entities/order_item.dart';
import 'package:tofu_pos/domain/entities/product.dart';
import 'package:tofu_pos/domain/enums/customer_attributes_enums.dart';
import 'package:tofu_pos/domain/value_objects/checkout_draft.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';
import 'package:tofu_pos/features/regi/presentation/notifiers/checkout_session.dart';

void main() {
  const Product yakisoba = Product(
    id: 'p1',
    name: '焼きそば',
    price: Money(400),
    stock: 5,
  );
  const Product juice = Product(
    id: 'p2',
    name: 'ジュース',
    price: Money(150),
    stock: 20,
  );

  late ProviderContainer container;
  late CheckoutSessionNotifier notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(checkoutSessionProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('addProduct', () {
    test('新規商品を1点でカートへ追加する', () {
      notifier.addProduct(yakisoba);

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.productId, 'p1');
      expect(notifier.state.items.first.quantity, 1);
      expect(notifier.state.items.first.priceAtTime, const Money(400));
    });

    test('既存商品の追加で quantity が増える', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(yakisoba);

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.quantity, 2);
    });

    test('複数商品が独立したエントリとして並ぶ', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(juice);

      expect(notifier.state.items.length, 2);
      expect(notifier.state.countOf('p1'), 1);
      expect(notifier.state.countOf('p2'), 1);
    });

    test('maxStock を超える追加は上限でクリップされる（仕様書 §9.2）', () {
      notifier.addProduct(yakisoba, delta: 4);
      notifier.addProduct(yakisoba, delta: 10, maxStock: 5);

      expect(notifier.state.items.first.quantity, 5);
    });

    test('在庫0の新規追加は no-op（カートに入らない）', () {
      notifier.addProduct(yakisoba, maxStock: 0);

      expect(notifier.state.items, isEmpty);
    });

    test('delta=-1 で既存商品が1件減る', () {
      notifier
        ..addProduct(yakisoba, delta: 2)
        ..addProduct(yakisoba, delta: -1);

      expect(notifier.state.items.first.quantity, 1);
    });

    test('delta で quantity が0以下になると行ごと削除', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(yakisoba, delta: -1);

      expect(notifier.state.items, isEmpty);
    });
  });

  group('setQuantity', () {
    test('既存行の quantity を直接書き換える', () {
      notifier
        ..addProduct(yakisoba)
        ..setQuantity('p1', 3);

      expect(notifier.state.items.first.quantity, 3);
    });

    test('maxStock を超えた値はクリップ', () {
      notifier
        ..addProduct(yakisoba)
        ..setQuantity('p1', 99, maxStock: 5);

      expect(notifier.state.items.first.quantity, 5);
    });

    test('quantity=0 で行が削除される', () {
      notifier
        ..addProduct(yakisoba)
        ..setQuantity('p1', 0);

      expect(notifier.state.items, isEmpty);
    });
  });

  group('undoLast', () {
    test('空カートでは no-op', () {
      notifier.undoLast();
      expect(notifier.state.items, isEmpty);
    });

    test('quantity > 1 の末尾行は quantity が 1 減る', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(juice, delta: 3)
        ..undoLast();

      expect(notifier.state.items.length, 2);
      expect(notifier.state.items.last.productId, 'p2');
      expect(notifier.state.items.last.quantity, 2);
    });

    test('quantity == 1 の末尾行は行ごと削除', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(juice)
        ..undoLast();

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.productId, 'p1');
    });

    test('連続呼び出しで全行を巻き戻して空に戻る', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(juice)
        ..undoLast()
        ..undoLast();

      expect(notifier.state.items, isEmpty);
    });
  });

  group('removeProduct', () {
    test('指定商品だけ取り除く', () {
      notifier
        ..addProduct(yakisoba)
        ..addProduct(juice)
        ..removeProduct('p1');

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.first.productId, 'p2');
    });

    test('存在しない商品IDは no-op', () {
      notifier
        ..addProduct(yakisoba)
        ..removeProduct('nope');

      expect(notifier.state.items.length, 1);
    });
  });

  group('集計プロパティ', () {
    test('totalPrice は明細小計の合計', () {
      notifier
        ..addProduct(yakisoba, delta: 2) // 800
        ..addProduct(juice, delta: 3); // 450

      expect(notifier.state.totalPrice, const Money(1250));
    });

    test('finalPrice は割引適用後（円割引）', () {
      notifier
        ..addProduct(yakisoba, delta: 2)
        ..setDiscount(const AmountDiscount(Money(-100)));

      expect(notifier.state.totalPrice, const Money(800));
      expect(notifier.state.finalPrice, const Money(700));
    });

    test('finalPrice は割引適用後（％割引）', () {
      notifier
        ..addProduct(yakisoba, delta: 2) // 800
        ..setDiscount(const PercentDiscount(-10));

      expect(notifier.state.finalPrice, const Money(720));
    });

    test('changeCash = receivedCash - finalPrice', () {
      notifier
        ..addProduct(yakisoba, delta: 2)
        ..setReceivedCash(const Money(1000));

      expect(notifier.state.changeCash, const Money(200));
    });

    test('預り金不足だと changeCash は負になる', () {
      notifier
        ..addProduct(yakisoba, delta: 2)
        ..setReceivedCash(const Money(500));

      expect(notifier.state.changeCash, const Money(-300));
      expect(notifier.state.changeCash.isNegative, isTrue);
    });

    test('isEmpty は items が空のときのみ true', () {
      expect(notifier.state.isEmpty, isTrue);
      notifier.addProduct(yakisoba);
      expect(notifier.state.isEmpty, isFalse);
    });
  });

  group('state setter', () {
    test('setCustomerAttributes が反映される', () {
      const CustomerAttributes attrs = CustomerAttributes(
        age: CustomerAge.twenties,
        gender: CustomerGender.female,
      );
      notifier.setCustomerAttributes(attrs);

      expect(notifier.state.customerAttributes, attrs);
    });

    test('setCashDelta が反映される', () {
      notifier.setCashDelta(const <int, int>{1000: 1, 100: 5});

      expect(notifier.state.cashDelta, const <int, int>{1000: 1, 100: 5});
    });
  });

  group('reset', () {
    test('全状態が初期化される', () {
      notifier
        ..addProduct(yakisoba, delta: 3)
        ..setReceivedCash(const Money(2000))
        ..setDiscount(const AmountDiscount(Money(-100)))
        ..setCashDelta(const <int, int>{500: 2})
        ..setCustomerAttributes(
          const CustomerAttributes(age: CustomerAge.thirties),
        )
        ..reset();

      expect(notifier.state.items, isEmpty);
      expect(notifier.state.receivedCash, Money.zero);
      expect(notifier.state.discount, Discount.none);
      expect(notifier.state.cashDelta, const <int, int>{});
      expect(notifier.state.customerAttributes, CustomerAttributes.empty);
    });
  });

  group('toDraft', () {
    test('現在のセッションを CheckoutDraft に変換する', () {
      const CustomerAttributes attrs = CustomerAttributes(
        age: CustomerAge.forties,
      );
      notifier
        ..addProduct(yakisoba, delta: 2)
        ..setReceivedCash(const Money(1000))
        ..setDiscount(const AmountDiscount(Money(-50)))
        ..setCashDelta(const <int, int>{1000: 1})
        ..setCustomerAttributes(attrs);

      final CheckoutDraft draft = notifier.state.toDraft();

      expect(draft.items.length, 1);
      expect(draft.items.first.quantity, 2);
      expect(draft.receivedCash, const Money(1000));
      expect(draft.discount, const AmountDiscount(Money(-50)));
      expect(draft.cashDelta, const <int, int>{1000: 1});
      expect(draft.customerAttributes, attrs);
      expect(draft.totalPrice, const Money(800));
      expect(draft.finalPrice, const Money(750));
    });
  });

  group('countOf', () {
    test('該当 productId の数量を返す', () {
      notifier.addProduct(yakisoba, delta: 3);

      expect(notifier.state.countOf('p1'), 3);
    });

    test('カートにない productId は 0', () {
      expect(notifier.state.countOf('p1'), 0);
    });
  });

  test('addProduct は priceAtTime に商品マスタの価格をスナップショットする', () {
    notifier.addProduct(yakisoba);

    final OrderItem item = notifier.state.items.first;
    expect(item.priceAtTime, const Money(400));
    expect(item.productName, '焼きそば');
  });
}

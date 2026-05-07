import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/discount.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

void main() {
  group('AmountDiscount', () {
    test('discounts a fixed amount', () {
      const Discount d = AmountDiscount(Money(-100));
      expect(d.applyTo(const Money(1000)), const Money(900));
      expect(d.asAmount(const Money(1000)), const Money(-100));
    });

    test('zero discount is no-op', () {
      expect(Discount.none.applyTo(const Money(1000)), const Money(1000));
    });

    test('positive amount means surcharge', () {
      const Discount d = AmountDiscount(Money(50));
      expect(d.applyTo(const Money(1000)), const Money(1050));
    });

    test('equality', () {
      expect(const AmountDiscount(Money(-100)),
          const AmountDiscount(Money(-100)));
    });
  });

  group('PercentDiscount', () {
    test('10% off', () {
      const Discount d = PercentDiscount(-10);
      expect(d.applyTo(const Money(1000)), const Money(900));
      expect(d.asAmount(const Money(1000)), const Money(-100));
    });

    test('rounds half-even', () {
      // 333 * -0.10 = -33.3 → round to -33
      const Discount d = PercentDiscount(-10);
      expect(d.asAmount(const Money(333)), const Money(-33));
    });

    test('positive percent means surcharge', () {
      const Discount d = PercentDiscount(20);
      expect(d.applyTo(const Money(500)), const Money(600));
    });
  });
}

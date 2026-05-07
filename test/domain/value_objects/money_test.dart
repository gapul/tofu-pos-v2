import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

void main() {
  group('Money', () {
    test('zero', () {
      expect(Money.zero.yen, 0);
      expect(Money.zero.isZero, isTrue);
    });

    test('addition / subtraction', () {
      expect(const Money(100) + const Money(50), const Money(150));
      expect(const Money(100) - const Money(150), const Money(-50));
    });

    test('multiplication by int', () {
      expect(const Money(100) * 3, const Money(300));
      expect(Money.zero * 5, Money.zero);
    });

    test('comparison', () {
      expect(const Money(100) > const Money(99), isTrue);
      expect(const Money(100) < const Money(101), isTrue);
      expect(const Money(100) >= const Money(100), isTrue);
      expect(const Money(100) <= const Money(100), isTrue);
    });

    test('negation and abs', () {
      expect(-const Money(100), const Money(-100));
      expect(const Money(-200).abs(), const Money(200));
    });

    test('equality and hashCode', () {
      expect(const Money(100), const Money(100));
      expect(const Money(100).hashCode, const Money(100).hashCode);
      expect(const Money(100), isNot(const Money(101)));
    });

    test('toString', () {
      expect(const Money(1234).toString(), '¥1234');
    });
  });
}

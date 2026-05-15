import 'dart:math';

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
      expect(
        const AmountDiscount(Money(-100)),
        const AmountDiscount(Money(-100)),
      );
    });
  });

  group('PercentDiscount', () {
    test('10% off', () {
      const Discount d = PercentDiscount(-10);
      expect(d.applyTo(const Money(1000)), const Money(900));
      expect(d.asAmount(const Money(1000)), const Money(-100));
    });

    test('rounds half-away-from-zero', () {
      // 333 * -0.10 = -33.3 → round to -33
      const Discount d = PercentDiscount(-10);
      expect(d.asAmount(const Money(333)), const Money(-33));
    });

    test('positive percent means surcharge', () {
      const Discount d = PercentDiscount(20);
      expect(d.applyTo(const Money(500)), const Money(600));
    });

    test('uses integer arithmetic only (no double drift)', () {
      // 0.1 + 0.2 != 0.3 系の double 誤差が混入しないことを保証する。
      // base=2999, percent=-30 → -899.7 → 整数演算で -900。
      const Discount d = PercentDiscount(-30);
      expect(d.asAmount(const Money(2999)), const Money(-900));
    });
  });

  group('Discount.allocate (Largest Remainder Method)', () {
    test('3 lines / 10% off / Σ == applyTo', () {
      // 3 行: 333 / 333 / 334 = 1000. 10% 割引 = -100。
      // 各行を独立に round すると -33 -33 -33 = -99 で 1円ズレる典型ケース。
      const Discount d = PercentDiscount(-10);
      final List<Money> alloc = d.allocate(const <Money>[
        Money(333),
        Money(333),
        Money(334),
      ]);
      final int sum = alloc.fold<int>(0, (acc, m) => acc + m.yen);
      expect(sum, -100);
      expect(d.asAmount(const Money(1000)).yen, sum);
    });

    test('all-equal lines distribute evenly with remainder', () {
      // 3 行 100 円 / -10% = -30 → 各行 -10 で割り切れる。
      const Discount d = PercentDiscount(-10);
      final List<Money> alloc = d.allocate(const <Money>[
        Money(100),
        Money(100),
        Money(100),
      ]);
      expect(alloc, const <Money>[Money(-10), Money(-10), Money(-10)]);
    });

    test('1-yen discount across 3 equal lines', () {
      // -1 円を 3 行に按分。1 行が -1、残り 2 行が 0。
      const Discount d = AmountDiscount(Money(-1));
      final List<Money> alloc = d.allocate(const <Money>[
        Money(100),
        Money(100),
        Money(100),
      ]);
      final int sum = alloc.fold<int>(0, (acc, m) => acc + m.yen);
      expect(sum, -1);
      // ちょうど 1 行だけが -1、他は 0。
      expect(alloc.where((m) => m.yen == -1).length, 1);
      expect(alloc.where((m) => m.yen == 0).length, 2);
    });

    test('AmountDiscount allocates exactly', () {
      const Discount d = AmountDiscount(Money(-100));
      final List<Money> alloc = d.allocate(const <Money>[
        Money(150),
        Money(250),
        Money(600),
      ]);
      final int sum = alloc.fold<int>(0, (acc, m) => acc + m.yen);
      expect(sum, -100);
    });

    test('zero discount returns all zeros', () {
      final List<Money> alloc = Discount.none.allocate(const <Money>[
        Money(100),
        Money(200),
      ]);
      expect(alloc, const <Money>[Money.zero, Money.zero]);
    });

    test('zero subtotals → all zeros (no division by zero)', () {
      const Discount d = PercentDiscount(-10);
      final List<Money> alloc = d.allocate(const <Money>[
        Money.zero,
        Money.zero,
      ]);
      expect(alloc, const <Money>[Money.zero, Money.zero]);
    });

    test('empty subtotals → empty', () {
      const Discount d = PercentDiscount(-10);
      expect(d.allocate(const <Money>[]), isEmpty);
    });

    test('surcharge (positive) also allocates exactly', () {
      // 7% の割増を 3 行（333/333/334）に。
      const Discount d = PercentDiscount(7);
      final List<Money> alloc = d.allocate(const <Money>[
        Money(333),
        Money(333),
        Money(334),
      ]);
      final int sum = alloc.fold<int>(0, (acc, m) => acc + m.yen);
      expect(sum, d.asAmount(const Money(1000)).yen);
    });

    test('property: 100 random cases — Σ allocate == asAmount(subtotal)', () {
      final Random rng = Random(20260515);
      for (int trial = 0; trial < 100; trial++) {
        final int n = 1 + rng.nextInt(15); // 1〜15 行
        final List<Money> lines = List<Money>.generate(
          n,
          (_) => Money(1 + rng.nextInt(5000)), // 1〜5000 円
        );
        // PercentDiscount または AmountDiscount をランダムに選ぶ。
        final Discount d = rng.nextBool()
            ? PercentDiscount(-(1 + rng.nextInt(50))) // -1% 〜 -50%
            : AmountDiscount(Money(-(1 + rng.nextInt(500))));
        final List<Money> alloc = d.allocate(lines);
        expect(alloc.length, n);
        final int subtotal =
            lines.fold<int>(0, (acc, m) => acc + m.yen);
        final int total = d.asAmount(Money(subtotal)).yen;
        final int sum =
            alloc.fold<int>(0, (acc, m) => acc + m.yen);
        expect(
          sum,
          total,
          reason:
              'trial=$trial discount=$d lines=$lines subtotal=$subtotal '
              'total=$total alloc=$alloc',
        );
      }
    });
  });
}

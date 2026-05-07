import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';
import 'package:tofu_pos/domain/value_objects/money.dart';

void main() {
  group('CashDrawer', () {
    test('empty has all denominations at 0', () {
      final CashDrawer drawer = CashDrawer.empty();
      for (final Denomination d in Denomination.all) {
        expect(drawer.countOf(d), 0);
      }
      expect(drawer.totalAmount, Money.zero);
    });

    test('totalAmount sums all denominations', () {
      final CashDrawer drawer = CashDrawer(<Denomination, int>{
        const Denomination(100): 5, // 500
        const Denomination(1000): 2, // 2000
      });
      expect(drawer.totalAmount, const Money(2500));
    });

    test('apply adds delta', () {
      CashDrawer drawer = CashDrawer.empty();
      drawer = drawer.apply(<Denomination, int>{
        const Denomination(100): 3,
        const Denomination(1000): 1,
      });
      expect(drawer.countOf(const Denomination(100)), 3);
      expect(drawer.countOf(const Denomination(1000)), 1);
      expect(drawer.totalAmount, const Money(1300));
    });

    test('apply can subtract', () {
      CashDrawer drawer = CashDrawer(<Denomination, int>{
        const Denomination(100): 5,
      });
      drawer = drawer.apply(<Denomination, int>{const Denomination(100): -3});
      expect(drawer.countOf(const Denomination(100)), 2);
    });

    test('apply throws when count would go negative', () {
      final CashDrawer drawer = CashDrawer(<Denomination, int>{
        const Denomination(100): 1,
      });
      expect(
        () => drawer.apply(<Denomination, int>{const Denomination(100): -2}),
        throwsStateError,
      );
    });

    test('reject negative initial counts', () {
      expect(
        () => CashDrawer(<Denomination, int>{const Denomination(100): -1}),
        throwsArgumentError,
      );
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/domain/entities/cash_drawer.dart';
import 'package:tofu_pos/domain/value_objects/denomination.dart';

import '../../_support/property.dart';

/// 1シーケンスのドロワー操作（apply の連鎖）を表す型。
class _DrawerScenario {
  _DrawerScenario(this.initial, this.deltas);

  final Map<Denomination, int> initial;
  final List<Map<Denomination, int>> deltas;

  @override
  String toString() => 'initial=$initial deltas=$deltas';
}

_DrawerScenario _randomScenario(Random rng) {
  // 初期: 各金種 0..50 枚
  final Map<Denomination, int> initial = <Denomination, int>{
    for (final Denomination d in Denomination.all) d: rng.nextInt(51),
  };

  final int stepCount = rng.nextInt(8); // 0..7 step
  final List<Map<Denomination, int>> deltas = <Map<Denomination, int>>[];
  for (int i = 0; i < stepCount; i++) {
    final Map<Denomination, int> delta = <Denomination, int>{};
    // 一部の金種のみ動かす
    for (final Denomination d in Denomination.all) {
      if (rng.nextDouble() < 0.4) {
        // -5..+5
        delta[d] = rng.nextInt(11) - 5;
      }
    }
    deltas.add(delta);
  }
  return _DrawerScenario(initial, deltas);
}

/// シナリオを「失敗しない apply」だけ適用した最終ドロワーを返す。
/// （途中で負になるステップは無視して継続）。
({CashDrawer drawer, Map<Denomination, int> applied}) _applyScenario(
  _DrawerScenario sc,
) {
  CashDrawer drawer = CashDrawer(sc.initial);
  final Map<Denomination, int> applied = <Denomination, int>{
    for (final Denomination d in Denomination.all) d: sc.initial[d] ?? 0,
  };
  for (final Map<Denomination, int> delta in sc.deltas) {
    try {
      drawer = drawer.apply(delta);
      delta.forEach((d, diff) {
        applied[d] = (applied[d] ?? 0) + diff;
      });
      // ドキュメント化された CashDrawer の契約（負になる apply は StateError）を
      // 検証するために StateError を捕捉する。
      // ignore: avoid_catching_errors
    } on StateError {
      // 負になるステップはドロワー側でブロック → スキップして次へ
      continue;
    }
  }
  return (drawer: drawer, applied: applied);
}

void main() {
  group('CashDrawer invariants (property-based)', () {
    test('balance never goes negative after apply chain', () {
      forAll<_DrawerScenario>(
        name: 'no negative balance',
        gen: _randomScenario,
        property: (sc) {
          final CashDrawer d = _applyScenario(sc).drawer;
          return d.counts.values.every((c) => c >= 0);
        },
      );
    });

    test('totalAmount equals sum(denom.yen * count)', () {
      forAll<_DrawerScenario>(
        name: 'total = sum',
        gen: _randomScenario,
        property: (sc) {
          final CashDrawer d = _applyScenario(sc).drawer;
          int expected = 0;
          d.counts.forEach((denom, count) {
            expected += denom.yen * count;
          });
          return d.totalAmount.yen == expected;
        },
      );
    });

    test('apply with empty delta is identity', () {
      forAll<_DrawerScenario>(
        name: 'identity',
        gen: _randomScenario,
        property: (sc) {
          final CashDrawer d = CashDrawer(sc.initial);
          final CashDrawer same = d.apply(const <Denomination, int>{});
          return d.totalAmount == same.totalAmount;
        },
      );
    });

    test('apply that would go negative throws and leaves drawer unchanged', () {
      forAll<int>(
        name: 'negative apply throws',
        gen: (rng) => rng.nextInt(50),
        property: (count) {
          final CashDrawer d = CashDrawer(<Denomination, int>{
            const Denomination(100): count,
          });
          try {
            d.apply(<Denomination, int>{const Denomination(100): -(count + 1)});
            return false;
            // ドキュメント化された CashDrawer の契約（負になる apply は StateError）を
      // 検証するために StateError を捕捉する。
      // ignore: avoid_catching_errors
          } on StateError {
            return d.countOf(const Denomination(100)) == count;
          }
        },
      );
    });
  });
}

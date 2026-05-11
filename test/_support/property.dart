import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// 軽量なプロパティベーステスト用ヘルパー。
///
/// 外部依存を増やさずに、固定シードで再現可能な N ケースを生成し
/// 不変条件を検証する。失敗時はシードと反例を表示する。
///
/// 使い方:
/// ```dart
/// forAll<int>(
///   name: 'abs is non-negative',
///   gen: (rng) => rng.nextInt(1000) - 500,
///   property: (x) => x.abs() >= 0,
/// );
/// ```
void forAll<T>({
  required String name,
  required T Function(Random rng) gen,
  required bool Function(T) property,
  int n = 200,
  int seed = 0xC0FFEE,
}) {
  final Random rng = Random(seed);
  for (int i = 0; i < n; i++) {
    final T value = gen(rng);
    final bool ok = property(value);
    if (!ok) {
      fail(
        'Property [$name] failed.\n'
        '  seed: $seed\n'
        '  iteration: $i\n'
        '  counterexample: $value',
      );
    }
  }
}

/// 同じ入力で複数の不変条件をまとめて検証する版。
void forAllInvariants<T>({
  required String name,
  required T Function(Random rng) gen,
  required Map<String, bool Function(T)> invariants,
  int n = 200,
  int seed = 0xC0FFEE,
}) {
  final Random rng = Random(seed);
  for (int i = 0; i < n; i++) {
    final T value = gen(rng);
    for (final MapEntry<String, bool Function(T)> inv in invariants.entries) {
      final bool ok = inv.value(value);
      if (!ok) {
        fail(
          'Invariant [${inv.key}] of [$name] failed.\n'
          '  seed: $seed\n'
          '  iteration: $i\n'
          '  counterexample: $value',
        );
      }
    }
  }
}

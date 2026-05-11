import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tofu_pos/core/time/clock.dart';

void main() {
  group('SystemClock', () {
    const SystemClock clock = SystemClock();

    test('now() returns JST wall clock (UTC+9 offset)', () {
      final DateTime utc = clock.nowUtc();
      final DateTime jst = clock.now();
      // 「now() は UTC+9 の壁時計コンポーネント」であることを確認する。
      // `jst` は local-flag な DateTime だが、構築値は UTC+9 の年/月/日/時。
      // UTC+9 の壁時計を別経路で計算した値とコンポーネントを突き合わせる。
      final DateTime expectedComponents = utc.add(const Duration(hours: 9));
      // 200ms までは2回読み出しのドリフトとして許容。
      final DateTime jstAsUtc = DateTime.utc(
        jst.year,
        jst.month,
        jst.day,
        jst.hour,
        jst.minute,
        jst.second,
        jst.millisecond,
        jst.microsecond,
      );
      final Duration diff = jstAsUtc.difference(expectedComponents);
      expect(diff.inMilliseconds.abs() < 500, isTrue,
          reason: 'now() should match UTC+9 components (got diff=$diff)');
    });

    test('todayJst() returns midnight JST', () {
      final DateTime today = clock.todayJst();
      expect(today.hour, 0);
      expect(today.minute, 0);
      expect(today.second, 0);
      expect(today.millisecond, 0);
      expect(today.microsecond, 0);
    });

    test('now() is monotonic between successive calls', () {
      final DateTime a = clock.now();
      final DateTime b = clock.now();
      expect(b.isAtSameMomentAs(a) || b.isAfter(a), isTrue);
    });
  });

  group('FakeClock', () {
    test('returns the configured fixed time', () {
      final FakeClock fake = FakeClock(DateTime(2026, 5, 8, 14, 30));
      expect(fake.now(), DateTime(2026, 5, 8, 14, 30));
      expect(fake.todayJst(), DateTime(2026, 5, 8));
    });

    test('advance() shifts now()', () {
      final FakeClock fake = FakeClock(DateTime(2026, 5, 8, 14));
      fake.advance(const Duration(hours: 2));
      expect(fake.now(), DateTime(2026, 5, 8, 16));
    });

    test('setNow() replaces both wall and UTC time', () {
      final FakeClock fake = FakeClock(DateTime(2026, 5, 8));
      fake.setNow(DateTime(2026, 11, 1, 12), utc: DateTime.utc(2026, 11, 1, 3));
      expect(fake.now(), DateTime(2026, 11, 1, 12));
      expect(fake.nowUtc(), DateTime.utc(2026, 11, 1, 3));
    });
  });

  group('clockProvider', () {
    test('default override resolves to SystemClock', () {
      final ProviderContainer c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(clockProvider), isA<SystemClock>());
    });

    test('can be overridden with FakeClock in tests', () {
      final FakeClock fake = FakeClock(DateTime(2026, 1, 1, 9));
      final ProviderContainer c = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      expect(c.read(clockProvider).now(), DateTime(2026, 1, 1, 9));
    });
  });
}

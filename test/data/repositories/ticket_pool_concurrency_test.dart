import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tofu_pos/data/repositories/shared_prefs_ticket_pool_repository.dart';
import 'package:tofu_pos/domain/value_objects/ticket_number.dart';

/// 並行に N 件発番した際、整理券番号が一意であることを検証する。
///
/// SharedPrefs を使った Repository は単一プロセス内で並行 `load -> issue -> save`
/// が走ると、最後の save が他の save を上書きして同じ番号が複数 issue される可能性がある。
/// `SharedPrefsTicketPoolRepository.allocate` は内部ロックで `load -> issue -> save`
/// をシリアライズすることでこの不変条件を保証する。
void main() {
  group('TicketPool concurrent allocation', () {
    late SharedPreferences prefs;
    late SharedPrefsTicketPoolRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      // 並行性テストで枯渇しないよう十分に大きい maxNumber を使う。
      repo = SharedPrefsTicketPoolRepository(prefs, defaultMaxNumber: 1000);
    });

    test('100 concurrent allocate calls return unique ticket numbers', () async {
      final List<Future<TicketNumber>> futures = <Future<TicketNumber>>[
        for (int i = 0; i < 100; i++) repo.allocate(),
      ];
      final List<TicketNumber> numbers = await Future.wait(futures);

      expect(numbers.length, 100);
      expect(numbers.where((n) => n.value <= 0), isEmpty);
      final Set<int> uniqueValues = numbers.map((n) => n.value).toSet();
      expect(
        uniqueValues.length,
        100,
        reason: '並行発番でユニーク性が破れている: $numbers',
      );
    });

    test(
      'mixed allocate/release under concurrency keeps pool consistent',
      () async {
        // 50 件 allocate → そのうち偶数番目を release → さらに 50 件 allocate。
        final List<TicketNumber> first = await Future.wait(<Future<TicketNumber>>[
          for (int i = 0; i < 50; i++) repo.allocate(),
        ]);
        await Future.wait(<Future<void>>[
          for (int i = 0; i < first.length; i += 2) repo.release(first[i]),
        ]);
        final List<TicketNumber> second = await Future.wait(
          <Future<TicketNumber>>[
            for (int i = 0; i < 50; i++) repo.allocate(),
          ],
        );

        // 偶数番目のインデックスを release したので、残っている使用中（active）は奇数番目。
        final Set<int> firstActive = <int>{
          for (int i = 1; i < first.length; i += 2) first[i].value,
        };
        final Set<int> secondSet = second.map((t) => t.value).toSet();
        expect(secondSet.length, 50);
        // 2回目の発番で、まだ使用中の番号が再発行されていない。
        expect(
          firstActive.intersection(secondSet),
          isEmpty,
          reason: '使用中の番号が再発行されている: active=$firstActive 2nd=$secondSet',
        );
      },
    );
  });
}
